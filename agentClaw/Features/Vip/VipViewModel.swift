import Foundation
import Combine

final class VipViewModel: ObservableObject {
    @Published var products: [VipProduct] = []
    @Published var selectedIndex: Int? = nil
    @Published var memberActive = false
    @Published var memberStatusLoaded = false
    @Published var vipExpiresAt: String? = nil
    @Published var statusMessage = "正在加载会员套餐…"
    @Published var isPayEnabled = false
    @Published var isLoading = false
    @Published var selectedChannel = "apple"
    @Published var isAgreementChecked = false
    @Published var showLogin = false
    @Published var toastMessage: String? = nil
    @Published var paySuccess = false
    @Published var storePricesReady = false
    /// 价格是否可展示：套餐接口 + App Store 本地化价格都尝试加载完成后才置 true，
    /// 加载期间套餐卡片只显示名称与介绍，避免价格闪动或空白。
    @Published var pricesReady = false

    var onPaymentSuccess: (() -> Void)?
    private var orderPollingTask: Task<Void, Never>?
    /// App Store 本地化价格：appleProductId -> displayPrice(如 "¥12.00")
    private var storeDisplayPrices: [String: String] = [:]

    var selectedProduct: VipProduct? {
        guard let i = selectedIndex, products.indices.contains(i) else { return nil }
        return products[i]
    }

    var isLoggedIn: Bool { AppPreferences().isLoggedIn }
    var maskedPhone: String {
        let phone = AppPreferences().userPhone ?? ""
        guard phone.count >= 7 else { return phone }
        return phone.prefix(3) + "****" + phone.suffix(4)
    }
    var displayPrice: String {
        guard let product = selectedProduct else { return "¥--" }
        return priceText(for: product)
    }

    /// 优先展示 App Store 本地化价格(合规要求)，拿不到再回退后端价格。
    func priceText(for product: VipProduct) -> String {
        if let store = storeDisplayPrices[product.appleProductId], !store.isEmpty {
            return store
        }
        return "¥\(product.price)"
    }

    func loadData() {
        let token = AppPreferences().userAccessToken
        memberStatusLoaded = false
        isPayEnabled = false
        pricesReady = false
        statusMessage = "正在加载会员套餐…"

        Task {
            async let products = loadProducts()
            async let membership: Void = token != nil ? loadMembership(token: token!) : noMembership()
            let (p, _) = await (products, membership)
            await MainActor.run {
                self.products = p
                if !p.isEmpty {
                    self.selectedIndex = 0
                }
                self.updatePayButtonState()
            }
            await self.loadStorePrices()
        }
    }

    /// 拉取 App Store 本地化价格，用于价格展示与内购下单。
    private func loadStorePrices() async {
        let storeProducts = await StoreKitService.shared.loadProducts()
        var built: [String: String] = [:]
        for sp in storeProducts { built[sp.id] = sp.displayPrice }
        let map = built
        await MainActor.run {
            self.storeDisplayPrices = map
            self.storePricesReady = !map.isEmpty
            // 无论 App Store 价格是否取到（取不到会回退后端价格），都算加载结束，可展示价格。
            self.pricesReady = true
        }
    }

    private func loadProducts() async -> [VipProduct] {
        do {
            return try await PaymentService.shared.loadProducts()
        } catch {
            await MainActor.run { self.statusMessage = "\(error.localizedDescription) · 点击重试" }
            return []
        }
    }

    private func loadMembership(token: String) async {
        do {
            let status = try await PaymentService.shared.loadMembership(token: token)
            QuotaManager.shared.applyServerQuota(status)
            let p = AppPreferences()
            p.isVipActive = status.active
            p.vipExpiresAt = status.expiresAt
            await MainActor.run {
                self.memberActive = status.active
                self.memberStatusLoaded = true
                self.vipExpiresAt = status.expiresAt
                if status.active, let exp = status.expiresAt {
                    self.statusMessage = "会员已开通，有效期至 \(exp)"
                } else {
                    self.statusMessage = "请选择套餐并支付"
                }
                self.updatePayButtonState()
            }
        } catch {
            await MainActor.run {
                self.memberStatusLoaded = true
                self.statusMessage = "请选择套餐并支付"
                self.updatePayButtonState()
            }
        }
    }

    private func noMembership() async {
        await MainActor.run {
            self.memberActive = false
            self.memberStatusLoaded = true
            self.updatePayButtonState()
        }
    }

    private func updatePayButtonState() {
        if !memberStatusLoaded {
            isPayEnabled = false
            return
        }
        isPayEnabled = selectedProduct != nil
        if selectedProduct == nil {
            statusMessage = "请先选择会员套餐"
        } else if !isLoggedIn {
            statusMessage = "支付前需要先登录"
        } else if memberActive {
            statusMessage = "会员已开通，可继续续费"
        } else {
            statusMessage = "请选择套餐并支付"
        }
    }

    func selectProduct(_ index: Int) {
        selectedIndex = index
        updatePayButtonState()
    }

    func startPayment() {
        guard isAgreementChecked else {
            showToast("请先阅读并同意《会员服务协议》")
            return
        }
        let prefs = AppPreferences()
        guard prefs.isLoggedIn, let token = prefs.userAccessToken, !token.isEmpty else {
            showLogin = true
            return
        }
        guard let product = selectedProduct else {
            showToast("请先选择会员套餐")
            return
        }
        guard !product.appleProductId.isEmpty else {
            showToast("该套餐暂不可购买，请稍后重试")
            return
        }
        isPayEnabled = false
        isLoading = true
        statusMessage = "正在打开 App Store 支付…"
        Task {
            do {
                // 1) 唤起苹果收银台完成付款，拿到已签名交易凭证
                let signed = try await StoreKitService.shared.purchase(productId: product.appleProductId)
                await MainActor.run { self.statusMessage = "支付结果确认中…" }
                // 2) 交给后端校验并发放会员
                try await self.grantWithApple(signed: signed, backendProductId: product.id, token: token)
                // 3) 发放成功后结束交易
                await StoreKitService.shared.finish(transactionId: signed.transactionId)
            } catch is CancellationError {
                await MainActor.run {
                    self.isLoading = false
                    self.isPayEnabled = true
                    self.statusMessage = "已取消支付"
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.isPayEnabled = true
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    /// 把苹果交易凭证发给后端校验，成功即刷新会员状态。
    private func grantWithApple(signed: StoreKitService.SignedTransaction, backendProductId: String, token: String) async throws {
        let status = try await PaymentService.shared.verifyApplePurchase(
            token: token,
            productId: backendProductId,
            appleProductId: signed.productId,
            transactionId: signed.transactionId,
            jws: signed.jws
        )
        QuotaManager.shared.applyServerQuota(status)
        let prefs = AppPreferences()
        prefs.isVipActive = status.active
        prefs.vipExpiresAt = status.expiresAt
        await MainActor.run {
            self.isLoading = false
            self.memberActive = status.active
            self.vipExpiresAt = status.expiresAt
            self.paySuccess = status.active
            self.statusMessage = status.active
                ? "支付成功，会员已开通" + (status.expiresAt.map { "，有效期至 \($0)" } ?? "")
                : "支付已完成，正在同步会员状态…"
            self.isPayEnabled = !status.active
            if status.active { self.onPaymentSuccess?() }
        }
    }

    /// 恢复购买：与 App Store 同步后把历史交易补交给后端校验。
    func restorePurchases() {
        let prefs = AppPreferences()
        guard prefs.isLoggedIn, let token = prefs.userAccessToken, !token.isEmpty else {
            showLogin = true
            return
        }
        isLoading = true
        statusMessage = "正在恢复购买…"
        Task {
            var restoredAny = false
            let transactions = (try? await StoreKitService.shared.restore()) ?? []
            for signed in transactions {
                do {
                    try await self.grantWithApple(signed: signed, backendProductId: "", token: token)
                    await StoreKitService.shared.finish(transactionId: signed.transactionId)
                    restoredAny = true
                } catch {
                    // 单笔失败忽略，继续处理其余交易
                }
            }
            let didRestore = restoredAny
            await MainActor.run {
                self.isLoading = false
                if !didRestore && !self.memberActive {
                    self.statusMessage = "未找到可恢复的购买记录"
                    self.isPayEnabled = self.selectedProduct != nil
                }
            }
        }
    }

    private func pollOrder(orderId: String, token: String) {
        orderPollingTask?.cancel()
        orderPollingTask = Task {
            for attempt in 0..<6 {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if Task.isCancelled { return }
                do {
                    let status = try await PaymentService.shared.queryOrder(token: token, orderId: orderId)
                    if status.lowercased() == "paid" || status.lowercased() == "success" {
                        let prefs = AppPreferences()
                        prefs.isVipActive = true
                        await MainActor.run {
                            self.memberActive = true
                            self.paySuccess = true
                            self.statusMessage = "支付成功，会员已开通"
                            self.onPaymentSuccess?()
                        }
                        Task { await self.loadMembership(token: token) }
                        return
                    }
                } catch {}
                if attempt == 5 {
                    await MainActor.run {
                        self.isPayEnabled = true
                        self.statusMessage = "订单处理中，请稍后重新进入页面查看"
                    }
                }
            }
        }
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.toastMessage == msg { self.toastMessage = nil }
        }
    }
}

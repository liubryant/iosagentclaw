import Foundation
import Combine

final class VipViewModel: ObservableObject {
    @Published var products: [VipProduct] = []
    @Published var selectedIndex: Int? = nil
    @Published var memberActive = false
    @Published var memberStatusLoaded = false
    @Published var vipExpiresAt: String? = nil
    @Published var appleExpiresAt: String? = nil
    @Published var appleActive = false
    @Published var currentAppleProductId: String? = nil
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
    var selectedProductIsCurrent: Bool {
        appleActive && selectedProduct?.appleProductId == currentAppleProductId
    }
    var payActionTitle: String {
        if selectedProductIsCurrent { return "当前套餐" }
        return memberActive ? "更换套餐" : "立即开通"
    }

    /// 优先展示 App Store 本地化价格(合规要求)，拿不到再回退后端价格。
    func priceText(for product: VipProduct) -> String {
        if let store = storeDisplayPrices[product.appleProductId], !store.isEmpty {
            return store
        }
        return "¥\(product.price)"
    }

    func loadData() {
        let preferences = AppPreferences()
        let token = preferences.effectiveAccessToken
        memberStatusLoaded = false
        isPayEnabled = false
        pricesReady = false
        statusMessage = "正在加载会员套餐…"

        Task {
            if preferences.isLoggedIn,
               let userToken = preferences.userAccessToken, !userToken.isEmpty,
               let guestToken = preferences.appleGuestAccessToken, !guestToken.isEmpty {
                if let bound = try? await PaymentService.shared.bindAppleGuestMembership(
                    userToken: userToken, guestToken: guestToken
                ) {
                    preferences.isVipActive = bound.active
                    preferences.vipExpiresAt = bound.expiresAt
                }
            }
            // 后台套餐与 StoreKit 并行请求。后台价格先到即可立即展示，
            // 不再因为 App Store 商品请求较慢而把已有价格一起隐藏。
            async let membership: Void = token != nil ? loadMembership(token: token!) : noMembership()
            async let productsRequest = loadProducts()
            async let storePricesRequest = fetchStoreDisplayPrices()
            let p = await productsRequest
            await MainActor.run {
                self.products = p
                if !p.isEmpty {
                    self.selectedIndex = 0
                }
                // 后台已经返回套餐价格，先展示后端价格作为可靠回退。
                self.pricesReady = !p.isEmpty
                self.updatePayButtonState()
            }
            let storePrices = await storePricesRequest
            await MainActor.run {
                self.storeDisplayPrices = storePrices
                self.storePricesReady = !storePrices.isEmpty
                // StoreKit 为空时继续显示后台价格。
                self.pricesReady = !self.products.isEmpty
            }
            await membership
            if let currentToken = preferences.effectiveAccessToken,
               let apple = try? await PaymentService.shared.loadAppleMembership(token: currentToken) {
                preferences.appleVipActive = apple.active
                preferences.appleVipExpiresAt = apple.expiresAt
                await MainActor.run {
                    self.appleActive = apple.active
                    self.appleExpiresAt = apple.expiresAt
                    self.currentAppleProductId = apple.productId
                    if apple.active,
                       let productId = apple.productId,
                       let index = self.products.firstIndex(where: { $0.appleProductId == productId }) {
                        self.selectedIndex = index
                    }
                    self.updatePayButtonState()
                }
            }
        }
    }

    /// 拉取 App Store 本地化价格。与后台套餐并行，不阻塞后台价格展示。
    private func fetchStoreDisplayPrices() async -> [String: String] {
        let storeProducts = await StoreKitService.shared.loadProducts()
        var built: [String: String] = [:]
        for sp in storeProducts { built[sp.id] = sp.displayPrice }
        return built
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
            self.vipExpiresAt = nil
            self.memberStatusLoaded = true
            self.updatePayButtonState()
        }
    }

    private func updatePayButtonState() {
        if !memberStatusLoaded {
            isPayEnabled = false
            return
        }
        if selectedProduct == nil {
            isPayEnabled = false
            statusMessage = "请先选择会员套餐"
        } else if selectedProductIsCurrent {
            isPayEnabled = false
            statusMessage = "当前套餐已生效，将由 App Store 自动续订"
        } else if memberActive {
            isPayEnabled = true
            statusMessage = "可通过 App Store 更换订阅套餐"
        } else {
            isPayEnabled = true
            statusMessage = "请选择套餐并支付"
        }
    }

    func selectProduct(_ index: Int) {
        selectedIndex = index
        updatePayButtonState()
    }

    func startPayment() {
        guard isAgreementChecked else {
            showToast("请先阅读并同意会员、自动续费、隐私政策和使用条款")
            return
        }
        let prefs = AppPreferences()
        // 游客凭证只用于读取当前游客权益，不能作为“账号身份”参与 Apple 交易校验。
        // 未登录时交由服务端根据 Apple originalTransactionId 找回或创建匿名权益主体。
        let token = prefs.isLoggedIn ? prefs.userAccessToken : nil
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
                let verified = try await self.grantWithApple(
                    signed: signed, backendProductId: product.id, token: token
                )
                // 3) 发放成功后结束交易
                await StoreKitService.shared.finish(transactionId: signed.transactionId)
                // 后端可能刚签发游客权益凭证。使用最新凭证再拉一次会员状态，
                // 确保顶部有效期、本地缓存和服务端最终状态保持一致。
                let refreshedToken = AppPreferences().effectiveAccessToken
                if !verified.transactionAlreadyProcessed,
                   let refreshedToken, !refreshedToken.isEmpty {
                    await self.loadMembership(token: refreshedToken)
                }
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
    @discardableResult
    private func grantWithApple(
        signed: StoreKitService.SignedTransaction,
        backendProductId: String,
        token: String?
    ) async throws -> ApplePurchaseVerification {
        let verified = try await PaymentService.shared.verifyApplePurchase(
            token: token,
            productId: backendProductId,
            appleProductId: signed.productId,
            transactionId: signed.transactionId,
            jws: signed.jws
        )
        let status = verified.membership
        QuotaManager.shared.applyServerQuota(status)
        let prefs = AppPreferences()
        prefs.isVipActive = status.active
        prefs.vipExpiresAt = status.expiresAt
        if let guestToken = verified.guestAccessToken { prefs.appleGuestAccessToken = guestToken }
        prefs.appleVipActive = verified.appleActive
        prefs.appleVipExpiresAt = verified.appleExpiresAt
        await MainActor.run {
            self.isLoading = false
            self.memberActive = status.active
            self.vipExpiresAt = status.expiresAt
            self.appleActive = verified.appleActive
            self.appleExpiresAt = verified.appleExpiresAt
            self.currentAppleProductId = verified.appleProductId
            self.paySuccess = verified.appleActive && !verified.transactionAlreadyProcessed
            if verified.transactionAlreadyProcessed {
                self.statusMessage = "当前订阅已生效，本次未生成新的续订周期"
            } else {
                self.statusMessage = verified.appleActive
                    ? "支付成功，会员已开通" + (verified.appleExpiresAt.map { "，App Store 订阅有效期至 \($0)" } ?? "")
                    : "支付已完成，正在同步会员状态…"
            }
            self.isPayEnabled = !status.active
            if verified.appleActive && !verified.transactionAlreadyProcessed {
                self.onPaymentSuccess?()
            }
        }
        return verified
    }

    /// 恢复购买：与 App Store 同步后把历史交易补交给后端校验。
    func restorePurchases() {
        let prefs = AppPreferences()
        let token = prefs.isLoggedIn ? prefs.userAccessToken : nil
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
                if didRestore {
                    self.statusMessage = self.vipExpiresAt.map { "会员权益已恢复，有效期至 \($0)" }
                        ?? "会员权益已恢复"
                    self.isPayEnabled = false
                } else if !self.memberActive {
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

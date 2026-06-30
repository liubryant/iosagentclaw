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
    @Published var selectedChannel = "alipay"
    @Published var isAgreementChecked = false
    @Published var showLogin = false
    @Published var toastMessage: String? = nil
    @Published var paySuccess = false

    var onPaymentSuccess: (() -> Void)?
    private var orderPollingTask: Task<Void, Never>?

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
        selectedProduct.map { "¥\($0.price)" } ?? "¥--"
    }

    func loadData() {
        let token = AppPreferences().userAccessToken
        memberStatusLoaded = false
        isPayEnabled = false
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
        isPayEnabled = false
        isLoading = true
        statusMessage = "正在创建安全支付订单…"
        Task {
            do {
                let order = try await PaymentService.shared.createOrder(
                    token: token, productId: product.id, payChannel: selectedChannel
                )
                await MainActor.run {
                    self.isLoading = false
                    if order.isMock {
                        self.statusMessage = "模拟支付完成，正在确认…"
                        self.pollOrder(orderId: order.orderId, token: token)
                    } else if self.selectedChannel == "alipay" {
                        AlipayBridge.shared.pay(orderString: order.aliPayOrderString ?? "") { [weak self] result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    self?.statusMessage = "支付结果确认中…"
                                    self?.pollOrder(orderId: order.orderId, token: token)
                                case .cancelled:
                                    self?.isPayEnabled = true
                                    self?.statusMessage = "已取消支付"
                                case .failed(let msg):
                                    self?.isPayEnabled = true
                                    self?.statusMessage = msg
                                }
                            }
                        }
                    }
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

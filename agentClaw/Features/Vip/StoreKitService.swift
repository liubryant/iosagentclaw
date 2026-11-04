import Foundation
import StoreKit

// Apple In-App Purchase (StoreKit 2) service.
//
// 会员为数字权益，按 App Store 审核条款 3.1.1 必须走内购。
// 这里只负责“唤起苹果收银台 + 拿到已签名凭证(JWS)”，
// 真正的“发放会员”由后端校验 JWS 后完成（见 PaymentService.verifyApplePurchase）。
// 工程部署目标已提升到 iOS 15，可直接使用 StoreKit 2。
final class StoreKitService {
    static let shared = StoreKitService()

    // 与 App Store Connect 自动续订订阅组（22311417）中的产品 ID 完全一致。
    static let productIDs: [String] = [
        "cn.agent.vip.week",
        "cn.agent.vip.month",
        "cn.agent.vip.year"
    ]

    enum StoreError: LocalizedError {
        case productNotFound
        case notEntitled
        case failedVerification
        case pending
        case unknown

        var errorDescription: String? {
            switch self {
            case .productNotFound:  return "未找到对应的内购商品，请稍后重试"
            case .notEntitled:      return "支付未完成"
            case .failedVerification: return "凭证校验失败，请重试"
            case .pending:          return "支付正在等待确认（如需家长同意），完成后会员将自动开通"
            case .unknown:          return "支付失败，请稍后重试"
            }
        }
    }

    // 购买/更新成功后拿到的已签名交易凭证
    struct SignedTransaction {
        let transactionId: String       // Transaction.id，用于后端幂等去重
        let originalId: String          // Transaction.originalID
        let productId: String           // Apple 商品 ID
        let jws: String                 // JWS 签名串，交给后端 + Apple 校验
    }

    private var productsCache: [String: Product] = [:]
    private var updatesListener: Task<Void, Never>?

    private init() {}

    // MARK: - Products

    /// 拉取商品并缓存（用于展示 App Store 本地化价格）
    @discardableResult
    func loadProducts() async -> [Product] {
        do {
            let products = try await Product.products(for: Self.productIDs)
            for p in products { productsCache[p.id] = p }
            let foundIDs = Set(products.map { $0.id })
            let missing = Self.productIDs.filter { !foundIDs.contains($0) }
            print("[IAP] loadProducts requested=\(Self.productIDs) found=\(Array(foundIDs)) missing=\(missing)")
            // 按周/月/年顺序返回
            return Self.productIDs.compactMap { productsCache[$0] }
        } catch {
            print("[IAP] loadProducts ERROR: \(error)")
            return []
        }
    }

    func cachedProduct(id: String) -> Product? { productsCache[id] }

    // MARK: - Purchase

    /// 发起购买。成功后返回已签名交易，交由后端发放会员成功后再调用 finish()。
    func purchase(productId: String) async throws -> SignedTransaction {
        // 服务端不会给已过期交易发放权益，但这类交易若一直不 finish，StoreKit 会在
        // 后续启动/购买时反复投递。付款前先清理队列，确保本次拿到的是新交易。
        await finishExpiredUnfinishedTransactions()

        let product: Product
        if let cached = productsCache[productId] {
            product = cached
        } else if let fetched = try? await Product.products(for: [productId]).first {
            productsCache[productId] = fetched
            product = fetched
        } else {
            print("[IAP] purchase FAILED: product not found for id=\(productId)")
            throw StoreError.productNotFound
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            guard isCurrentlyActive(transaction) else {
                await transaction.finish()
                throw StoreError.notEntitled
            }
            return SignedTransaction(
                transactionId: String(transaction.id),
                originalId: String(transaction.originalID),
                productId: transaction.productID,
                jws: verification.jwsRepresentation
            )
        case .userCancelled:
            throw CancellationError()
        case .pending:
            throw StoreError.pending
        @unknown default:
            throw StoreError.unknown
        }
    }

    /// 后端确认发放会员成功后，务必调用它把交易置为已完成，否则会反复回调。
    func finish(transactionId: String) async {
        for await result in Transaction.all {
            if case .verified(let tx) = result, String(tx.id) == transactionId {
                await tx.finish()
                return
            }
        }
    }

    // MARK: - Restore

    /// 恢复购买：与 App Store 同步后，只收集当前有效权益。
    /// Transaction.all 会包含已过期的历史订阅，提交它们会造成“订阅已过期”的误提示，
    /// 也会产生大量无意义的后端校验请求。
    func restore() async throws -> [SignedTransaction] {
        await finishExpiredUnfinishedTransactions()
        try await AppStore.sync()
        var collected: [SignedTransaction] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            guard isCurrentlyActive(tx) else {
                await tx.finish()
                continue
            }
            collected.append(SignedTransaction(
                transactionId: String(tx.id),
                originalId: String(tx.originalID),
                productId: tx.productID,
                jws: result.jwsRepresentation
            ))
        }
        return collected
    }

    // MARK: - Transaction updates listener

    /// App 启动时调用：监听后台/中断的交易（例如支付后 App 被杀、家长同意后到账），
    /// 把它们补交给后端校验。onSigned 里发放成功后需调用 finish()。
    func startObservingUpdates(onSigned: @escaping (SignedTransaction) async -> Void) {
        updatesListener?.cancel()
        updatesListener = Task.detached {
            for await result in Transaction.updates {
                if Task.isCancelled { return }
                guard case .verified(let tx) = result else { continue }
                // 已过期、退款或已升级的历史交易无需再请求业务服务端，直接结束，
                // 防止每次启动都重复提示“订阅已过期”。
                guard self.isCurrentlyActive(tx) else {
                    await tx.finish()
                    continue
                }
                await onSigned(SignedTransaction(
                    transactionId: String(tx.id),
                    originalId: String(tx.originalID),
                    productId: tx.productID,
                    jws: result.jwsRepresentation
                ))
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func isCurrentlyActive(_ transaction: Transaction) -> Bool {
        guard transaction.revocationDate == nil, !transaction.isUpgraded else { return false }
        if let expirationDate = transaction.expirationDate {
            return expirationDate > Date()
        }
        return true
    }

    /// 清理此前因服务端拒绝而遗留的过期交易。只处理无有效权益的交易，
    /// 当前仍有效的订阅仍会正常提交服务端同步会员。
    private func finishExpiredUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result else { continue }
            if !isCurrentlyActive(transaction) {
                await transaction.finish()
            }
        }
    }
}

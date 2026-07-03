// 支付宝支付已下线。
//
// 会员为虚拟数字权益，按 App Store 审核指南 3.1.1 必须且只能通过苹果内购(IAP)购买，
// 因此本文件不再包含任何第三方支付(唤起 alipays:// / alipay:// scheme、SDK 回调等)逻辑，
// 相关 Info.plist 的 URL scheme 与 LSApplicationQueriesSchemes 也已一并移除。
//
// 内购实现见 StoreKitService，服务端校验见 PaymentService.verifyApplePurchase。

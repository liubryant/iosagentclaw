# 苹果内购(IAP)接入说明

VIP 会员为数字权益，按 App Store 审核条款 3.1.1 **必须走苹果内购**，iOS 端不再展示支付宝。
支付宝相关代码(`AlipayBridge`、后端 alipay 通道)保留，供 Android / H5 使用。

## 一、商品(App Store Connect)

已创建 3 个「非续费套餐」，商品 ID 必须与代码一致：

| 商品 | Product ID | 会员天数(后端权威) |
| --- | --- | --- |
| Agent周会员 | `ai.cjym.agentclaw.vip.week` | 7 |
| 月会员 | `agent123` | 30 |
| 年会员 | `agent124` | 365 |

> 天数在服务端 `NaviVipService.appleDurationDays()` 权威判定，**不信任客户端传参**。

## 二、客户端改动

- `Features/Vip/StoreKitService.swift`：StoreKit 2 内购(拉商品/购买/验签/恢复/交易监听)。
- `Core/Networking/PaymentService.swift`：新增 `verifyApplePurchase(...)`，`VipProduct` 增加 `appleProductId`。
- `Features/Vip/VipViewModel.swift`：`startPayment()` 改走内购；新增 `restorePurchases()`；价格优先用 App Store 本地化价格。
- `Features/Vip/VipView.swift`：支付方式改为「通过 App Store 支付」，新增「恢复购买」按钮。
- `agentClawApp.swift`：`IAPBootstrap` 启动时监听中断交易，登录后补发会员。
- 部署目标 iOS 13 → **15**(pbxproj + Podfile)。

### 购买流程
1. StoreKit 唤起收银台，成功后拿到已签名交易(JWS)。
2. `POST /im/bot/navi/vip/apple/verify` 交后端验签发放会员。
3. 后端确认发放成功后 `transaction.finish()`。
4. 支付后 App 中断的交易，由 `Transaction.updates` 监听在下次启动补处理。

## 三、后端契约(已实现并部署)

`POST {baseURL}/im/bot/navi/vip/apple/verify`，Header `Authorization: Bearer <token>`

请求体：
```json
{
  "productId": "后端套餐id(可空，仅记录订单)",
  "appleProductId": "agent123",
  "transactionId": "客户端上报(仅日志)",
  "jws": "StoreKit2 交易凭证(必需)",
  "platform": "ios",
  "bundleId": "ai.cjym.agentclaw"
}
```

响应(与 `/membership` 同结构)：
```json
{ "code": 0, "msg": "", "data": { "active": true, "expiresAt": "2026-08-01", "quota": { ... } } }
```

服务端逻辑(`NaviVipService.verifyApplePurchase`)：
1. 本地校验 JWS：ES256 签名 + Apple Root CA G3 证书链(`AppleIapVerifier`，离线，无需请求苹果；沙盒/正式通用)。
2. 校验 `bundleId == ai.cjym.agentclaw`、未退款(`revocationDate` 为空)。
3. 以**已验签的 productId** 判定会员天数。
4. `orderId = "AP" + transactionId` 作主键天然防重放，重复交易只发放一次。
5. 复用 `grantMembership()` 累加会员时长，返回最新会员状态。

> 未新增数据表：复用 `navi_vip_order`(pay_channel=`apple`，`wx_transaction_id` 存 Apple 交易号)。
> 未新增 Maven 依赖：仅用 JDK 内置能力 + fastjson。Apple 根证书打包在 `resources/apple/AppleRootCA-G3.cer`。

## 四、还需手动完成的事项

1. **`pod install`**：Podfile 平台已升到 15，需执行一次 `pod install` 同步 Pods 工程。
2. **App Store Connect**：3 个内购商品状态需「准备提交」，并随版本提交审核；填写审核用沙盒账号。
3. **协议/税务**：确保「付费应用协议(Paid Apps Agreement)」已签署，否则商品拉不到。
4. **沙盒测试**：用 Sandbox 测试账号在真机验证购买 → 会员到账 → 杀进程重进补单 → 恢复购买。
5. (可选) Info.plist 中的 alipay URL scheme/query 仅 iOS 端已不使用，可保留或移除。

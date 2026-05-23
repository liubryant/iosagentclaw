# 应用合规问题检查报告

## ✅ 已修复的严重问题

1. ✅ 移除 exit(0) 直接调用 - 改为温和退出
2. ✅ 移除 NSAllowsArbitraryLoads - 已删除
3. ✅ 添加 NSUserTrackingUsageDescription - 已添加
4. ✅ 禁用 Release 版本调试日志 - 已修复

---

## 🔴 发现的新严重合规问题

### 1. 【严重】缺少加密出口合规声明 ⚠️

**问题**:
- Info.plist 缺少 `ITSAppUsesNonExemptEncryption` 声明
- App Store Connect 提交时**必须**回答加密相关问题
- 应用使用了 HTTPS 通信

**影响**:
- 提交到 App Store Connect 时会被要求说明加密使用情况
- 可能需要向美国政府提供加密出口合规文档

**修复方案**:

#### 方案A: 声明仅使用标准加密（推荐）
添加到 Info.plist：
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

**说明**: 如果应用仅使用：
- HTTPS (TLS/SSL)
- iOS 系统提供的标准加密
- 不使用自定义加密算法

则可以设置为 `false`，无需额外文档。

#### 方案B: 声明使用自定义加密
如果使用了自定义加密，需要设置为 `true` 并准备合规文档。

**推荐**: 使用方案A（设置为 false）

---

### 2. 【中等】聊天历史存储在 UserDefaults 中 ⚠️

**位置**: `AppPreferences.swift:47-65`

**问题**:
```swift
var chatHistorySnapshot: ChatHistorySnapshot? {
    get {
        guard let data = defaults.data(forKey: Key.chatHistorySnapshot) else {
            return nil
        }
        return try? decoder.decode(ChatHistorySnapshot.self, from: data)
    }
    set {
        if let data = try? encoder.encode(snapshot) {
            defaults.set(data, forKey: Key.chatHistorySnapshot)
            defaults.synchronize()
        }
    }
}
```

**风险**:
- UserDefaults **未加密**
- 聊天历史可能包含**用户隐私对话**
- 如果设备被越狱，数据容易被读取
- 违反 GDPR/CCPA 数据保护要求

**影响等级**: 中等（但如果有敏感对话内容，升级为严重）

**修复方案**:

#### 方案1: 迁移到 Keychain（推荐）
```swift
// 使用已有的 KeychainStore 存储聊天历史
var chatHistorySnapshot: ChatHistorySnapshot? {
    get {
        guard let jsonString = keychain.string(for: "chat_history") else {
            return nil
        }
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(ChatHistorySnapshot.self, from: data)
    }
    set {
        guard let snapshot = newValue else {
            keychain.delete(account: "chat_history")
            return
        }
        if let data = try? encoder.encode(snapshot),
           let jsonString = String(data: data, encoding: .utf8) {
            try? keychain.setString(jsonString, for: "chat_history")
        }
    }
}
```

#### 方案2: 不保存聊天历史
完全移除本地存储，每次启动都是新会话。

#### 方案3: 使用 Data Protection
在 Info.plist 中启用文件加密，但仍不如 Keychain 安全。

**推荐**: 方案1（迁移到 Keychain）

---

### 3. 【低】测试环境 URL 硬编码 ⚠️

**位置**: `AppConfig.swift:29`

**问题**:
```swift
case .testing:
    return "http://192.168.1.17:8066/v1"  // 暴露内部网络地址
```

**风险**:
- 泄露内部测试服务器地址
- 可能被逆向工程发现

**影响**: 低（但不专业）

**修复方案**:
```swift
case .testing:
    #if DEBUG
    return "http://192.168.1.17:8066/v1"
    #else
    return "https://test.cjym123.cn/v1"  // 使用公网测试域名
    #endif
```

或者在 Release 版本中完全移除测试环境选项。

---

### 4. 【低】缺少数据删除功能 ⚠️

**问题**:
- 应用存储了聊天历史
- 未提供明显的**删除所有数据**功能
- GDPR/CCPA 要求提供数据删除能力

**影响**: 低（但审核可能质疑）

**修复方案**:

在设置页面添加"清除所有数据"按钮：
```swift
Button(action: {
    // 清除聊天历史
    preferences.chatHistorySnapshot = nil
    // 清除网关token
    try? keychain.setString(nil, for: GatewayTokenKey.gatewayToken)
    // 清除其他用户数据
}) {
    Text("清除所有数据")
        .foregroundColor(.red)
}
```

---

## ⚠️ 需要注意的问题

### 5. 【中等】生产环境域名使用 HTTP

**位置**: `AppConfig.swift:27`

**代码**:
```swift
case .production:
    return "https://www.cjym123.cn/v1"  // ✅ 使用HTTPS，没问题
```

**状态**: ✅ 正常，使用了 HTTPS

---

### 6. 【低】未声明第三方 SDK 数据收集

**问题**:
- 集成了友盟统计 SDK
- 集成了穿山甲广告 SDK（Mock版本）
- 未在隐私政策中详细说明第三方数据收集

**修复方案**:

在隐私政策中添加：
```
第三方服务提供商：
1. 友盟统计 - 收集应用使用数据
2. 穿山甲广告 - 展示个性化广告

这些服务可能收集设备信息、使用数据等。
详细信息请查看各服务提供商的隐私政策。
```

---

### 7. 【低】缺少 SKAdNetwork 配置

**问题**:
- 使用穿山甲广告 SDK
- 未配置 SKAdNetwork 标识符
- iOS 14+ 广告归因需要

**影响**: 广告效果可能受影响

**修复方案**:

联系穿山甲获取 SKAdNetwork ID，添加到 Info.plist：
```xml
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>穿山甲提供的ID.skadnetwork</string>
    </dict>
</array>
```

---

## 📋 合规优先级清单

### 🔴 立即修复（否则可能被拒）

1. [ ] **添加加密出口合规声明** (`ITSAppUsesNonExemptEncryption = false`)
2. [ ] **聊天历史迁移到 Keychain** 或不保存

### 🟡 强烈建议修复（提高通过率）

3. [ ] 移除或保护测试环境 URL
4. [ ] 添加"清除所有数据"功能
5. [ ] 更新隐私政策，说明第三方 SDK 数据收集

### 🟢 可选修复（改善用户体验）

6. [ ] 添加 SKAdNetwork 配置
7. [ ] 优化数据存储安全性

---

## 🔧 快速修复脚本

### 1. 添加加密合规声明

添加到 `Info.plist`：
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### 2. 聊天历史安全存储

修改 `AppPreferences.swift`，将聊天历史从 UserDefaults 迁移到 Keychain。

---

## 📝 App Store Connect 提交检查

### 加密出口合规问卷

提交时会被问到：

**Q: Does your app use encryption?**
**A**: Yes

**Q: Does your app qualify for any exemptions?**
**A**: Yes - (a) Uses standard encryption (HTTPS)

**说明**:
- 如果添加了 `ITSAppUsesNonExemptEncryption = false`
- 这个问卷会自动跳过

---

## 总结

### 当前状态
- ✅ 已修复4个高风险问题
- 🔴 发现2个新的严重问题
- 🟡 发现5个中低风险问题

### 必须修复（上架前）
1. 添加 `ITSAppUsesNonExemptEncryption` 声明
2. 聊天历史安全存储（推荐修复，可选）

### 其他建议
- 添加数据删除功能
- 更新隐私政策
- 移除测试环境硬编码

---

**最后更新**: 2026-05-23
**审核者**: Claude
**风险评估**: 中等（修复2个严重问题后风险降低为低）

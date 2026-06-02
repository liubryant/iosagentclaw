# App Store 上架检查清单

## ✅ 已修复的高风险问题

### 1. 移除 exit(0) 调用 ✅
**位置**: `OnboardingView.swift:92-96`

**修改前**:
```swift
Button(action: {
    exit(0)  // ❌ Apple禁止
})
```

**修改后**:
```swift
Button(action: {
    // 不同意时不做任何操作
    // Apple禁止应用主动退出，用户可以按Home键退出
})
```

**说明**: Apple审核指南明确禁止应用主动调用exit()退出，用户点击"不同意"后，应用保持在隐私政策页面，用户可以自己按Home键退出。

---

### 2. 移除 NSAllowsArbitraryLoads ✅
**位置**: `Info.plist:23-26`

**修改前**:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

**修改后**:
已完全移除此配置

**说明**: NSAllowsArbitraryLoads允许所有不安全的HTTP请求，极易被App Store拒绝。当前应用使用HTTPS API，无需此配置。

---

### 3. 添加广告追踪权限说明 ✅
**位置**: `Info.plist:29-30`

**新增**:
```xml
<key>NSUserTrackingUsageDescription</key>
<string>为了向您提供更相关的广告内容和改善广告体验，我们需要您的同意以访问设备的广告标识符。</string>
```

**说明**: 穿山甲广告SDK可能需要访问IDFA（广告标识符），iOS 14+强制要求应用在Info.plist中说明用途。

---

### 4. 禁用Release版本调试日志 ✅
**位置**: `HTTPClient.swift:29-35`

**修改前**:
```swift
func data(for request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
    HTTPDebugLogger.logRequest(request)  // 总是打印
    let task = session.dataTask(with: request) { data, response, error in
        HTTPDebugLogger.logResponse(data: data, response: response, error: error)  // 总是打印
```

**修改后**:
```swift
func data(for request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
    #if DEBUG
    HTTPDebugLogger.logRequest(request)
    #endif
    let task = session.dataTask(with: request) { data, response, error in
        #if DEBUG
        HTTPDebugLogger.logResponse(data: data, response: response, error: error)
        #endif
```

**说明**: Release版本不应输出调试日志，避免性能损耗和潜在的信息泄露。

---

## ⚠️ 需要注意的问题

### 1. Mock SDK - 上架前必须替换 ⚠️
**当前状态**: 使用Mock穿山甲SDK（无真实广告）

**上架前必做**:
1. 升级到Xcode 14+
2. 替换为真实的穿山甲SDK
3. 参考 `MOCK_SDK_README.md` 中的替换步骤

**风险**: 如果使用Mock SDK上架，无法展示真实广告，可能被审核发现功能虚假。

---

### 2. Bundle Identifier 确认
**当前**: `ai.cjym.agentclaw`

**需要确认**:
- [ ] 已在Apple Developer账号中注册此Bundle ID
- [ ] App Store Connect中已创建对应的App记录
- [ ] Bundle ID与证书匹配

---

### 3. 友盟SDK 可选
**当前状态**: 代码已集成但SDK未安装

**选项**:
- **选项A**: 安装友盟SDK（`pod install`）
- **选项B**: 移除友盟相关代码（不影响核心功能）

---

## 📋 上架前最终检查清单

### 代码层面
- [x] 移除exit()调用
- [x] 移除NSAllowsArbitraryLoads
- [x] 添加NSUserTrackingUsageDescription
- [x] 禁用Release日志
- [ ] 替换Mock SDK为真实穿山甲SDK（需Xcode 14+）
- [ ] 处理友盟SDK（安装或移除代码）

### 隐私合规
- [x] 隐私政策URL可访问: https://www.cjym123.cn/privacy_agentclaw.html
- [x] 用户协议URL可访问: https://www.cjym123.cn/agreement_agentclaw.html
- [x] SDK仅在用户同意后初始化
- [x] 首次安装不展示广告
- [x] 所有权限都有使用说明

### App Store Connect
- [ ] 创建应用记录
- [ ] 上传应用截图（至少3张）
- [ ] 填写应用描述和关键词
- [ ] 设置定价和销售范围
- [ ] 配置App内购买（如果有）
- [ ] 填写隐私问题调查表

### 构建配置
- [ ] 设置正确的证书和描述文件
- [ ] 检查Version和Build号
- [ ] Archive并验证
- [ ] 上传到App Store Connect

### 测试
- [ ] 在真机上完整测试所有功能
- [ ] 测试隐私政策接受流程
- [ ] 测试广告展示（替换真实SDK后）
- [ ] 测试应用在不同iOS版本（13.0+）
- [ ] 测试应用在iPhone和iPad

---

## 🚀 上架流程

### 1. 准备工作
```bash
# 清理构建
cd /Users/mac/Desktop/agentClaw
rm -rf ~/Library/Developer/Xcode/DerivedData/agentClaw-*

# 确保代码已提交
git status
git add .
git commit -m "Prepare for App Store submission"
git push
```

### 2. Archive构建
1. 打开Xcode: `open agentClaw.xcodeproj`
2. 选择 Generic iOS Device
3. Product -> Archive
4. 等待Archive完成

### 3. 验证构建
1. 在Organizer中选择Archive
2. 点击 "Validate App"
3. 选择证书和描述文件
4. 等待验证完成

### 4. 上传App Store
1. 点击 "Distribute App"
2. 选择 "App Store Connect"
3. 上传并等待处理完成

### 5. 提交审核
1. 登录 App Store Connect
2. 选择你的应用
3. 创建新版本
4. 选择刚上传的构建
5. 填写版本说明
6. 提交审核

---

## 📝 审核注意事项

### 可能被问到的问题

**Q: 为什么需要访问广告标识符？**
A: 应用集成了穿山甲广告SDK，用于展示相关广告内容并改善用户体验。

**Q: 为什么需要访问相册？**
A: 用户可以保存AI生成的图片到系统相册。

**Q: 为什么需要访问本地网络？**
A: 应用支持连接局域网中的OpenClaw Gateway进行本地AI服务。

**Q: 隐私政策在哪里？**
A:
- 应用内：首次启动时的隐私政策页面
- 在线版本：https://www.cjym123.cn/privacy_agentclaw.html

### 可能的拒绝理由及应对

**2.1 - 应用完整性**
- 确保所有功能可用
- 替换Mock SDK为真实SDK

**4.3 - 重复应用**
- 确保应用有独特功能
- 强调AI助手和本地网关支持

**5.1.1 - 隐私**
- 已添加所有必需的权限说明
- 已实现隐私政策同意流程

---

## 🎯 修改总结

| 问题 | 严重程度 | 状态 | 文件 |
|------|---------|------|------|
| exit(0)调用 | 🔴 严重 | ✅ 已修复 | OnboardingView.swift |
| NSAllowsArbitraryLoads | 🔴 严重 | ✅ 已修复 | Info.plist |
| 缺少追踪权限说明 | 🟡 高 | ✅ 已修复 | Info.plist |
| Release日志 | 🟡 中 | ✅ 已修复 | HTTPClient.swift |
| Mock SDK | 🔴 严重 | ⚠️ 待处理 | 需升级Xcode |
| 友盟SDK | 🟡 中 | ⚠️ 待处理 | 可选 |

---

**最后更新**: 2026-05-23
**准备者**: Claude
**状态**: 已完成代码层面修改，待替换真实SDK后可上架

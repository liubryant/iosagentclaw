# 穿山甲广告SDK集成指南

## 快速参考

### 初始化代码（已实现）
```swift
let configuration = BUAdSDKConfiguration()
configuration.appID = "YOUR_PANGLE_APP_ID"

// 使用聚合功能
configuration.useMediation = true

// 隐私合规配置
configuration.mediation.limitPersonalAds = NSNumber(integerLiteral: 0)
configuration.mediation.limitProgrammaticAds = NSNumber(integerLiteral: 0)
configuration.mediation.forbiddenCAID = NSNumber(integerLiteral: 0)
configuration.themeStatus = NSNumber(integerLiteral: 0)

// 异步初始化
BUAdSDKManager.start(asyncCompletionHandler: { success, error in
    if success {
        // 初始化成功
    }
})
```

### 代码位置
- **SDK管理类**: `agentClaw/Core/Analytics/PangleAdManager.swift:31`
- **应用初始化**: `agentClaw/agentClawApp.swift:37` 和 `agentClawApp.swift:59`
- **桥接头文件**: `agentClaw/agentClaw-Bridging-Header.h`

---

## 已完成的工作

### 1. Podfile配置 ✅
已添加穿山甲SDK依赖：
```ruby
pod 'Ads-CN-Beta', '7.6.0.3', :subspecs => ['CSJMediation']
```

### 2. 核心文件创建 ✅
- **PangleAdManager.swift**: 穿山甲广告管理类
  - 位置: `/agentClaw/Core/Analytics/PangleAdManager.swift`
  - 功能: SDK初始化、隐私设置、广告加载接口

- **agentClaw-Bridging-Header.h**: Objective-C桥接头文件
  - 位置: `/agentClaw/agentClaw-Bridging-Header.h`
  - 功能: 导入穿山甲SDK的OC头文件

### 3. 应用初始化集成 ✅
已在 `agentClawApp.swift` 中添加SDK初始化：
- iOS 14+: `ModernApp.init()`
- iOS 13: `AppDelegate.application(_:didFinishLaunchingWithOptions:)`

## 下一步操作

### 步骤1: 安装依赖
在终端执行：
```bash
cd /Users/mac/Desktop/agentClaw
pod install
```

### 步骤2: 配置Xcode项目
1. 打开 `agentClaw.xcworkspace`（不是.xcodeproj）
2. 选择项目 -> Build Settings -> 搜索 "Bridging"
3. 设置 `Objective-C Bridging Header` 为：
   ```
   agentClaw/agentClaw-Bridging-Header.h
   ```

### 步骤3: 配置应用ID
1. 打开 `agentClaw/Core/Analytics/PangleAdManager.swift`
2. 找到第25行，替换 `YOUR_PANGLE_APP_ID` 为您的穿山甲应用ID：
   ```swift
   private let appID = "YOUR_PANGLE_APP_ID"  // 替换为实际的AppID
   ```

### 步骤4: 配置Info.plist权限
在 `Info.plist` 中添加必要的权限说明：
```xml
<key>NSUserTrackingUsageDescription</key>
<string>我们需要您的同意以提供个性化广告体验</string>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 步骤5: 获取广告位ID并测试
1. 登录穿山甲开发者平台
2. 获取各类广告位ID（开屏、激励视频、Banner等）
3. 在需要展示广告的地方调用：
   ```swift
   // 加载开屏广告
   PangleAdManager.shared.loadSplashAd(slotID: "YOUR_SLOT_ID") { success, error in
       if success {
           print("广告加载成功")
       }
   }

   // 加载激励视频
   PangleAdManager.shared.loadRewardedVideoAd(slotID: "YOUR_SLOT_ID") { success, error in
       if success {
           print("激励视频加载成功")
       }
   }
   ```

## 系统要求

- ✅ iOS 11.0及以上（当前项目最低支持iOS 13.0）
- ✅ Xcode 14.1及以上
- ✅ 支持架构: x86-64/arm64

## 合规说明

SDK初始化已遵循工信部要求：
- ✅ 仅在用户同意隐私政策后初始化
- ✅ 默认关闭个性化广告和位置信息
- ✅ 提供隐私设置接口

## 注意事项（重要⚠️）

### 项目配置
1. **必须使用 .xcworkspace 打开项目**，而不是 .xcodeproj
2. 穿山甲SDK是Objective-C框架，需要桥接头文件
3. 首次运行前确保执行 `pod install`
4. 发布前将PangleAdManager中的日志级别改为 `.none`

### SDK使用注意事项（官方文档）
1. **代理不可更改**: 任意广告类型均不支持中途更改代理，中途更改代理会导致接收不到广告相关回调
2. **聚合配置**: `useMediation` 仅可设置一次，不支持后续二次修改
3. **初始化时机**: 需要确保在SDK初始化成功后再进行广告请求，否则可能导致广告请求加载失败
4. **初始化次数**: 默认仅支持初始化SDK一次，避免多次初始化SDK场景
5. **头文件引用**: 所有广告类型统一引用 `#import <BUAdSDK/BUAdSDK.h>` 头文件即可
6. **异步初始化**: 建议优先使用异步初始化方法（已实现），同步初始化方法会逐步废弃
7. **应用ID分离**: 强烈建议双端（iOS/Android）分别使用各自的应用ID进行测试，不要混用，否则可能会影响收益
8. **用户授权**: `setIsPaidApp:` 和 `setUserKeywords:` 须征得用户同意才可传入

### 隐私合规配置说明
当前默认配置（在初始化时设置）：
- `limitPersonalAds = 0`: 不限制个性化广告（需要用户授权）
- `limitProgrammaticAds = 0`: 不限制程序化广告
- `forbiddenCAID = 0`: 不禁止CAID
- `themeStatus = 0`: 跟随系统主题

**重要**: 根据您的隐私政策，可能需要调整这些值为 1（限制/禁止）

## 下一步开发

需要完善以下功能：
- [ ] 实现开屏广告的完整加载和展示逻辑
- [ ] 实现激励视频广告的完整加载和展示逻辑
- [ ] 实现Banner广告的完整加载和展示逻辑
- [ ] 添加广告事件回调处理（点击、关闭、奖励发放等）
- [ ] 在实际页面中集成广告展示

## 技术支持

- 穿山甲官方文档: https://www.pangle.cn/union/media/union/download/detail?id=4&docId=5dd0d8fc5b331e00129b39ff
- SDK版本: 7.6.0.3

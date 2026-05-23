# 穿山甲开屏广告使用指南

## 配置信息

### 已配置的广告信息
- **应用ID**: `5830164`
- **开屏广告位ID**: `104085288`

这些ID已经配置在代码中，无需手动修改。

## 开屏广告使用方法

### 基本使用

在应用启动时展示开屏广告：

```swift
// 在AppDelegate或SceneDelegate中调用
PangleSplashAdManager.shared.loadAndShowSplashAd(
    slotID: "104085288",
    tolerateTimeout: 3.0
) { success, error in
    if success {
        print("开屏广告展示成功")
    } else {
        print("开屏广告展示失败: \(error?.localizedDescription ?? "")")
    }
}
```

### 推荐的集成位置

#### 方式1: 在SceneDelegate中（iOS 13+）

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }

    // 设置主窗口
    window = UIWindow(windowScene: windowScene)
    window?.rootViewController = UIHostingController(rootView: ContentView())
    window?.makeKeyAndVisible()

    // 仅在用户已同意隐私政策后展示开屏广告
    if UserDefaults.standard.bool(forKey: "onboardingCompleted") {
        // 延迟0.1秒，确保window已完全显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PangleSplashAdManager.shared.loadAndShowSplashAd(slotID: "104085288")
        }
    }
}
```

#### 方式2: 在AppDelegate中（iOS 13以下）

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // 设置主窗口
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = UIHostingController(rootView: ContentView())
    window?.makeKeyAndVisible()

    // 仅在用户已同意隐私政策后展示开屏广告
    if UserDefaults.standard.bool(forKey: "onboardingCompleted") {
        // 延迟0.1秒，确保window已完全显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PangleSplashAdManager.shared.loadAndShowSplashAd(slotID: "104085288")
        }
    }

    return true
}
```

### 自定义超时时间

```swift
// 设置5秒超时
PangleSplashAdManager.shared.loadAndShowSplashAd(
    slotID: "104085288",
    tolerateTimeout: 5.0
) { success, error in
    // 处理回调
}
```

## 重要注意事项（⚠️必读）

### 1. SDK初始化时机
**必须在SDK初始化成功后才能请求广告**，否则会导致加载失败。

当前代码已自动检查：
```swift
guard PangleAdManager.shared.isSDKInitialized() else {
    // 自动返回错误
    return
}
```

### 2. 广告位ID不要混淆
⚠️ **切记不要使用代码混淆工具混淆广告位ID**

广告位ID必须保持原样：`"104085288"`

### 3. 融合场景限制
融合场景下**仅支持自渲染开屏**，已在代码中实现。

### 4. 展示时机
开屏广告必须在 `loadSuccess` 回调中调用 `show` 方法展示。

已在 `PangleSplashAdManager.swift:89` 实现：
```swift
func splashAdLoadSuccess(_ splashAd: BUSplashAd) {
    // 获取rootViewController后立即展示
    splashAd.show(from: rootVC)
}
```

### 5. rootViewController选择
建议使用 `keyWindow.rootViewController`，已在代码中实现：
```swift
private func getRootViewController() -> UIViewController? {
    if #available(iOS 13.0, *) {
        let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        return windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    } else {
        return UIApplication.shared.keyWindow?.rootViewController
    }
}
```

### 6. 生命周期管理
- 开屏内部视图生命周期由SDK管理
- 开发者只需关注 `BUSplashAd` 对象
- 当 `BUSplashAd` 被释放时，内部视图会同时移除

### 7. 缓存功能（不建议）
⚠️ **不建议开屏广告使用 preload 首次预缓存功能**
- 开屏广告加载时机过早
- 可能存在缓存逻辑冲突

### 8. 包名校验
确保在穿山甲媒体平台填写的包名符合各ADN平台规范。

当前项目Bundle ID需要在穿山甲平台正确配置。

### 9. 广告无填充问题排查

如果遇到广告无填充，按以下步骤排查：

#### 步骤1: 查看日志
代码已自动输出详细日志：
```swift
// 加载失败时会输出
❌ 开屏广告加载失败
   错误码: xxx
   错误信息: xxx
📊 ADN加载详情:
   ADN 1:
     - 错误码: xxx
     - 错误信息: xxx
```

#### 步骤2: 使用穿山甲平台诊断
1. 登录穿山甲媒体平台
2. 找到 GroMore -> 应用管理
3. 搜索广告位ID: `104085288`
4. 点击三个点 -> 诊断分析
5. 根据诊断结果解决问题

#### 步骤3: 检查ADN错误码
在日志中搜索关键字 `ABUSDK_` 明确具体错误码。

#### 步骤4: 使用LoadInfoList
代码已实现获取加载失败的ADN错误信息：
```swift
if let loadInfoList = splashAd.getAdLoadInfoList() {
    for loadInfo in loadInfoList {
        print("错误码: \(loadInfo.errCode)")
        print("错误信息: \(loadInfo.errMsg ?? "")")
    }
}
```

## 代理回调说明

### 已实现的所有回调

```swift
// 1. 广告加载成功（会自动展示）
func splashAdLoadSuccess(_ splashAd: BUSplashAd)

// 2. 广告加载失败
func splashAdLoadFail(_ splashAd: BUSplashAd, error: BUAdError?)

// 3. 广告即将展示
func splashAdWillShow(_ splashAd: BUSplashAd)

// 4. 广告已经展示
func splashAdDidShow(_ splashAd: BUSplashAd)

// 5. 广告被点击
func splashAdDidClick(_ splashAd: BUSplashAd)

// 6. 广告关闭
func splashAdDidClose(_ splashAd: BUSplashAd, closeType: BUSplashAdCloseType)

// 7. 广告渲染失败
func splashAdRenderFail(_ splashAd: BUSplashAd, error: BUAdError?)
```

### 关闭类型说明

```swift
switch closeType {
case .clickAd:        // 点击广告关闭
case .clickSkip:      // 点击跳过按钮
case .countdownEnd:   // 倒计时结束
default:              // 其他原因
}
```

## 测试流程

### 1. 确认SDK已初始化
应用启动时会看到：
```
✅ 穿山甲广告SDK初始化成功 - AppID: 5830164
✅ 聚合功能已启用
```

### 2. 触发开屏广告
应用完全启动后会看到：
```
📱 开始加载开屏广告 - SlotID: 104085288, 超时时间: 3.0秒
✅ 开屏广告加载成功
📱 开屏广告开始展示
📱 开屏广告即将展示
✅ 开屏广告展示成功
```

### 3. 观察用户行为
用户可以：
- 点击广告（会跳转到广告页面）
- 点击跳过按钮
- 等待倒计时结束

### 4. 广告关闭
关闭时会看到：
```
🔚 开屏广告已关闭
   关闭原因: xxx
```

## 常见问题

### Q1: 广告不展示怎么办？
**检查清单**:
- [ ] SDK是否已初始化？
- [ ] 是否在用户同意隐私政策后调用？
- [ ] Bundle ID是否在穿山甲平台正确配置？
- [ ] 网络是否正常？
- [ ] 查看日志错误信息

### Q2: 如何在首次启动时不展示开屏广告？
```swift
// 仅在非首次启动时展示
if UserDefaults.standard.bool(forKey: "onboardingCompleted") {
    PangleSplashAdManager.shared.loadAndShowSplashAd(slotID: "104085288")
}
```

### Q3: 如何自定义开屏广告展示逻辑？
目前 `PangleSplashAdManager` 封装了自动展示逻辑。如需自定义，可以：
1. 修改 `PangleSplashAdManager.swift`
2. 在 `splashAdLoadSuccess` 回调中添加自定义逻辑

### Q4: 广告加载超时时间如何设置？
```swift
// 默认3秒
PangleSplashAdManager.shared.loadAndShowSplashAd(
    slotID: "104085288",
    tolerateTimeout: 5.0  // 修改为5秒
)
```

### Q5: 如何处理广告关闭后的跳转？
```swift
// 可以在completion回调中处理
PangleSplashAdManager.shared.loadAndShowSplashAd(slotID: "104085288") { success, error in
    // 广告关闭后的逻辑
    self.navigateToMainScreen()
}
```

## 文件位置

- **SDK管理**: `agentClaw/Core/Analytics/PangleAdManager.swift`
- **开屏广告管理**: `agentClaw/Core/Analytics/PangleSplashAdManager.swift`
- **应用初始化**: `agentClaw/agentClawApp.swift`

## 相关文档

- [穿山甲SDK集成指南](./PANGLE_INTEGRATION_GUIDE.md)
- [穿山甲SDK更新总结](./PANGLE_UPDATE_SUMMARY.md)
- [穿山甲官方文档](https://www.csjplatform.com/supportcenter/5841)

---

**最后更新**: 2026-05-23
**广告位ID**: 104085288
**应用ID**: 5830164

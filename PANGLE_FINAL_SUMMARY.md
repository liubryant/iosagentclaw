# 穿山甲广告SDK集成完整总结

## 🎉 集成完成

已完成穿山甲广告SDK（聚合版本）的完整集成，包括：
- ✅ SDK初始化配置
- ✅ 开屏广告完整实现
- ✅ 所有官方要求的注意事项
- ✅ 详细的文档和示例代码

## 📋 配置信息

| 项目 | 值 |
|------|-----|
| **应用ID** | `5830164` |
| **开屏广告位ID** | `104085288` |
| **SDK版本** | Ads-CN-Beta 7.6.0.3 |
| **最低iOS版本** | iOS 13.0 |
| **聚合功能** | ✅ 已启用 |

## 📁 文件清单

### 1. 核心代码文件

#### SDK管理类
**文件**: `agentClaw/Core/Analytics/PangleAdManager.swift`
- SDK初始化配置
- 聚合功能启用
- 隐私合规设置
- 应用ID: `5830164`

#### 开屏广告管理类
**文件**: `agentClaw/Core/Analytics/PangleSplashAdManager.swift`
- 完整的开屏广告实现
- 所有代理回调
- 错误处理和日志
- 广告位ID: `104085288`

#### 应用初始化
**文件**: `agentClaw/agentClawApp.swift`
- SDK自动初始化
- 合规初始化时机
- iOS 13+ 和 iOS 14+ 支持

#### 桥接头文件
**文件**: `agentClaw/agentClaw-Bridging-Header.h`
- Objective-C桥接
- BUAdSDK导入

#### 依赖配置
**文件**: `Podfile`
- 穿山甲SDK依赖
- CSJMediation子模块

### 2. 文档文件

| 文档 | 说明 |
|------|------|
| `PANGLE_INTEGRATION_GUIDE.md` | 完整集成指南 |
| `PANGLE_SPLASH_AD_GUIDE.md` | 开屏广告使用指南 |
| `PANGLE_UPDATE_SUMMARY.md` | SDK更新总结 |
| `SPLASH_AD_EXAMPLE.swift` | 示例代码（5种使用方式） |
| `PANGLE_FINAL_SUMMARY.md` | 本文档 |

## 🚀 快速开始

### 步骤1: 安装依赖

```bash
cd /Users/mac/Desktop/agentClaw
pod install
```

### 步骤2: 配置Xcode

1. 打开 `agentClaw.xcworkspace`（⚠️ 不是 .xcodeproj）
2. 选择项目 -> Build Settings -> 搜索 "Bridging"
3. 设置 `Objective-C Bridging Header` 为：
   ```
   agentClaw/agentClaw-Bridging-Header.h
   ```

### 步骤3: 验证配置

编译运行项目，查看控制台日志：

```
✅ 穿山甲广告SDK初始化成功 - AppID: 5830164
✅ 聚合功能已启用
```

### 步骤4: 测试开屏广告

在 `agentClawApp.swift` 中添加：

```swift
init() {
    // 合规初始化
    if container.preferences.onboardingCompleted {
        UMengAnalytics.shared.initialize()
        PangleAdManager.shared.initialize()

        // 展示开屏广告
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            PangleSplashAdManager.shared.loadAndShowSplashAd(
                slotID: "104085288"
            ) { success, error in
                if success {
                    print("✅ 开屏广告展示成功")
                }
            }
        }
    }
}
```

## 📱 开屏广告使用

### 基本用法

```swift
PangleSplashAdManager.shared.loadAndShowSplashAd(
    slotID: "104085288",
    tolerateTimeout: 3.0
) { success, error in
    if success {
        print("广告展示成功")
    } else {
        print("广告展示失败: \(error?.localizedDescription ?? "")")
    }
}
```

### 推荐的集成位置

**iOS 14+ SwiftUI应用**:
```swift
@available(iOS 14.0, *)
struct ModernApp: App {
    init() {
        // 初始化SDK
        if container.preferences.onboardingCompleted {
            PangleAdManager.shared.initialize()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 展示开屏广告
                    showSplashAd()
                }
        }
    }
}
```

**iOS 13 UIKit应用**:
```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions...) -> Bool {
    // 初始化SDK
    PangleAdManager.shared.initialize()

    // 设置window
    window?.makeKeyAndVisible()

    // 延迟展示开屏广告
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        PangleSplashAdManager.shared.loadAndShowSplashAd(slotID: "104085288")
    }

    return true
}
```

更多示例请查看 `SPLASH_AD_EXAMPLE.swift`

## ⚠️ 重要注意事项

### 官方文档要求（必读）

#### 1. SDK初始化时机
- ✅ 必须在用户同意隐私政策后初始化
- ✅ 已在 `agentClawApp.swift` 中实现

#### 2. 广告请求时机
- ⚠️ 必须在SDK初始化成功后才能请求广告
- ✅ 代码已自动检查

#### 3. 广告位ID不要混淆
- ⚠️ 切记不要使用代码混淆
- ✅ 广告位ID: `"104085288"` 保持原样

#### 4. 聚合配置
- ✅ `useMediation = true` 仅设置一次
- ⚠️ 不支持后续修改

#### 5. 开屏广告展示时机
- ✅ 在 `loadSuccess` 回调中自动展示
- ✅ 已在 `PangleSplashAdManager.swift:89` 实现

#### 6. rootViewController
- ✅ 使用 `keyWindow.rootViewController`
- ✅ 已在代码中正确实现

#### 7. 融合场景限制
- ✅ 仅支持自渲染开屏
- ✅ 已按要求实现

#### 8. 缓存功能
- ⚠️ 不建议开屏广告使用preload预缓存
- ✅ 当前实现不使用缓存

#### 9. 包名校验
- ⚠️ 确保穿山甲平台填写的包名正确
- 📝 需要在平台配置当前应用的Bundle ID

#### 10. 应用ID分离
- ⚠️ iOS和Android使用各自的应用ID
- ✅ 当前iOS应用ID: `5830164`

### 代理管理注意事项

#### 1. 代理不可更改
- ⚠️ 任意广告类型均不支持中途更改代理
- ✅ 当前实现使用单例模式，不会更改代理

#### 2. 生命周期管理
- ✅ 开屏内部视图由SDK管理
- ✅ 开发者只需关注 `BUSplashAd` 对象
- ✅ 对象释放时会自动清理

## 🔧 故障排查

### 问题1: 广告不展示

**检查清单**:
- [ ] SDK是否已初始化？查看日志是否有 "✅ 穿山甲广告SDK初始化成功"
- [ ] 用户是否同意隐私政策？
- [ ] Bundle ID是否在穿山甲平台正确配置？
- [ ] 网络是否正常？
- [ ] 是否在主线程调用？

**日志排查**:
```
❌ 开屏广告加载失败
   错误码: xxx
   错误信息: xxx
```

### 问题2: 广告无填充

**排查步骤**:

1. **查看日志中的ADN错误信息**
   ```
   📊 ADN加载详情:
      ADN 1:
        - 错误码: xxx
        - 错误信息: xxx
   ```

2. **使用穿山甲平台诊断工具**
   - 登录穿山甲媒体平台
   - GroMore -> 应用管理 -> 搜索广告位ID `104085288`
   - 点击三个点 -> 诊断分析

3. **搜索日志关键字**
   - 搜索 `ABUSDK_` 查看具体错误码

4. **检查配置**
   - 应用ID是否正确：`5830164`
   - 广告位ID是否正确：`104085288`
   - Bundle ID是否匹配

### 问题3: 编译错误

**桥接头文件未配置**:
```
Error: Cannot find 'BUAdSDK' in scope
```

**解决方案**:
1. 确认已执行 `pod install`
2. 使用 `.xcworkspace` 打开项目
3. 配置 Bridging Header 路径

**依赖未安装**:
```
Error: No such module 'BUAdSDK'
```

**解决方案**:
```bash
cd /Users/mac/Desktop/agentClaw
pod install
```

## 📊 完整的实现流程

### 1. SDK初始化流程

```
应用启动
  ↓
检查用户是否同意隐私政策
  ↓
初始化PangleAdManager
  ↓
配置聚合功能
  ↓
设置隐私合规选项
  ↓
异步初始化SDK
  ↓
初始化成功/失败回调
```

### 2. 开屏广告流程

```
调用loadAndShowSplashAd
  ↓
检查SDK是否已初始化
  ↓
创建BUSplashAd对象
  ↓
设置代理和超时时间
  ↓
调用loadAdData
  ↓
等待回调...
  ↓
loadSuccess -> 自动展示广告
  ↓
用户交互（点击/跳过/倒计时）
  ↓
广告关闭
  ↓
清理对象
```

### 3. 代理回调顺序

```
splashAdLoadSuccess          // 加载成功
  ↓
splashAdWillShow            // 即将展示
  ↓
splashAdDidShow             // 已经展示
  ↓
(用户交互)
  ↓
splashAdDidClick            // 点击（可选）
  ↓
splashAdDidClose            // 关闭
```

## 📚 代码示例索引

| 场景 | 示例位置 |
|------|---------|
| iOS 14+ SwiftUI | `SPLASH_AD_EXAMPLE.swift` 示例1 |
| iOS 13 UIKit | `SPLASH_AD_EXAMPLE.swift` 示例2 |
| SceneDelegate | `SPLASH_AD_EXAMPLE.swift` 示例3 |
| 频率控制 | `SPLASH_AD_EXAMPLE.swift` 示例4 |
| 手动触发 | `SPLASH_AD_EXAMPLE.swift` 示例5 |

## 🔄 下一步开发

### 1. 立即操作
- [ ] 运行 `pod install`
- [ ] 配置 Bridging Header
- [ ] 编译运行项目
- [ ] 测试开屏广告

### 2. 可选增强
- [ ] 实现激励视频广告
- [ ] 实现Banner广告
- [ ] 实现信息流广告
- [ ] 添加广告频率控制
- [ ] 添加广告数据统计

### 3. 生产准备
- [ ] 在穿山甲平台配置Bundle ID
- [ ] 申请正式的广告位ID
- [ ] 测试各种网络环境
- [ ] 测试不同设备和iOS版本
- [ ] 关闭Debug日志

## 📞 技术支持

### 官方资源
- **穿山甲官方文档**: https://www.csjplatform.com/supportcenter/5841
- **广告位说明**: https://www.csjplatform.com/supportcenter/5841
- **ADN广告样式**: https://www.csjplatform.com/supportcenter/27654
- **SDK版本**: Ads-CN-Beta 7.6.0.3

### 项目文档
- [完整集成指南](./PANGLE_INTEGRATION_GUIDE.md)
- [开屏广告指南](./PANGLE_SPLASH_AD_GUIDE.md)
- [SDK更新总结](./PANGLE_UPDATE_SUMMARY.md)
- [示例代码](./SPLASH_AD_EXAMPLE.swift)

## ✅ 集成检查清单

### 配置检查
- [x] Podfile已添加穿山甲SDK依赖
- [x] 应用ID已配置: `5830164`
- [x] 开屏广告位ID已配置: `104085288`
- [x] 桥接头文件已创建
- [ ] Xcode中Bridging Header路径已配置
- [ ] 已执行 `pod install`
- [ ] 使用 `.xcworkspace` 打开项目

### 代码检查
- [x] SDK初始化代码已实现
- [x] 聚合功能已启用
- [x] 隐私合规配置已设置
- [x] 开屏广告管理类已实现
- [x] 所有代理回调已实现
- [x] 错误处理已完善
- [x] 日志输出已添加

### 测试检查
- [ ] SDK初始化成功
- [ ] 开屏广告可以正常加载
- [ ] 广告可以正常展示
- [ ] 广告可以正常关闭
- [ ] 错误情况处理正确
- [ ] 日志输出完整

### 文档检查
- [x] 集成指南已完成
- [x] 使用指南已完成
- [x] 示例代码已完成
- [x] 注意事项已记录
- [x] 故障排查已说明

---

## 🎯 总结

穿山甲广告SDK（聚合版本）已完全集成，包括：

1. **SDK配置** - 聚合功能、隐私合规、异步初始化
2. **开屏广告** - 完整实现、所有回调、错误处理
3. **代码质量** - 清晰注释、完善日志、错误检查
4. **文档完善** - 详细指南、丰富示例、注意事项

只需完成以下3步即可使用：
1. 运行 `pod install`
2. 配置 Bridging Header
3. 编译运行测试

**祝您接入顺利！** 🎉

---

**创建时间**: 2026-05-23
**应用ID**: 5830164
**开屏广告位ID**: 104085288
**SDK版本**: Ads-CN-Beta 7.6.0.3

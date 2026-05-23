# 穿山甲广告SDK集成文档导航

## 📱 应用信息

- **应用ID**: `5830164`
- **开屏广告位ID**: `104085288`
- **SDK版本**: Ads-CN-Beta 7.6.0.3
- **集成时间**: 2026-05-23

## 📖 文档导航

### 🚀 快速开始
推荐阅读顺序：

1. **[完整总结](./PANGLE_FINAL_SUMMARY.md)** ⭐️ 从这里开始
   - 集成完成情况
   - 快速开始指南
   - 配置检查清单
   - 故障排查

2. **[开屏广告使用指南](./PANGLE_SPLASH_AD_GUIDE.md)**
   - 基本使用方法
   - 重要注意事项（11条）
   - 代理回调说明
   - 常见问题

3. **[示例代码](./SPLASH_AD_EXAMPLE.swift)**
   - 5种不同的使用方式
   - SwiftUI和UIKit示例
   - 频率控制示例
   - 最佳实践

### 📚 详细文档

4. **[完整集成指南](./PANGLE_INTEGRATION_GUIDE.md)**
   - 已完成的工作
   - 下一步操作
   - 系统要求
   - 合规说明

5. **[SDK更新总结](./PANGLE_UPDATE_SUMMARY.md)**
   - 更新内容详情
   - 文件修改清单
   - 官方要求对照表
   - 配置步骤

## 🎯 3步开始使用

### 步骤1: 安装依赖
```bash
cd /Users/mac/Desktop/agentClaw
pod install
```

### 步骤2: 配置Xcode
1. 打开 `agentClaw.xcworkspace`
2. Build Settings -> 搜索 "Bridging"
3. 设置路径: `agentClaw/agentClaw-Bridging-Header.h`

### 步骤3: 测试运行
```swift
// 在应用启动后调用
PangleSplashAdManager.shared.loadAndShowSplashAd(slotID: "104085288")
```

## 📁 代码文件位置

| 文件 | 位置 | 说明 |
|------|------|------|
| SDK管理类 | `agentClaw/Core/Analytics/PangleAdManager.swift` | SDK初始化 |
| 开屏广告管理 | `agentClaw/Core/Analytics/PangleSplashAdManager.swift` | 开屏广告 |
| 应用初始化 | `agentClaw/agentClawApp.swift` | App入口 |
| 桥接头文件 | `agentClaw/agentClaw-Bridging-Header.h` | OC桥接 |
| 依赖配置 | `Podfile` | CocoaPods |

## ⚠️ 核心注意事项

1. **SDK初始化**: 必须在用户同意隐私政策后
2. **广告请求**: 必须在SDK初始化成功后
3. **广告位ID**: 不要使用代码混淆
4. **聚合配置**: `useMediation` 只能设置一次
5. **rootViewController**: 使用keyWindow.rootViewController

详细说明请查看 [开屏广告使用指南](./PANGLE_SPLASH_AD_GUIDE.md)

## 🔧 故障排查

### 广告不展示？
1. 查看日志是否有 "✅ 穿山甲广告SDK初始化成功"
2. 检查用户是否同意隐私政策
3. 确认Bundle ID在穿山甲平台正确配置
4. 查看详细错误日志

### 编译错误？
1. 确认执行了 `pod install`
2. 使用 `.xcworkspace` 打开项目
3. 配置 Bridging Header 路径

详细排查步骤请查看 [完整总结](./PANGLE_FINAL_SUMMARY.md#-故障排查)

## 📞 获取帮助

- **项目文档**: 查看本目录下的所有 `.md` 文件
- **示例代码**: 查看 `SPLASH_AD_EXAMPLE.swift`
- **穿山甲官方文档**: https://www.csjplatform.com/supportcenter/5841
- **诊断工具**: 穿山甲平台 -> GroMore -> 应用管理 -> 诊断分析

## ✅ 已完成的工作

- ✅ Podfile配置
- ✅ SDK初始化（聚合版本）
- ✅ 隐私合规配置
- ✅ 开屏广告完整实现
- ✅ 所有代理回调
- ✅ 错误处理和日志
- ✅ 桥接头文件
- ✅ 详细文档
- ✅ 示例代码（5种）

## 📝 待办事项

- [ ] 运行 `pod install`
- [ ] 配置 Xcode Bridging Header
- [ ] 编译运行项目
- [ ] 测试开屏广告
- [ ] 在穿山甲平台配置Bundle ID

## 📄 文档清单

| 文档 | 内容 | 推荐度 |
|------|------|--------|
| PANGLE_FINAL_SUMMARY.md | 完整总结 | ⭐️⭐️⭐️⭐️⭐️ |
| PANGLE_SPLASH_AD_GUIDE.md | 开屏广告指南 | ⭐️⭐️⭐️⭐️⭐️ |
| SPLASH_AD_EXAMPLE.swift | 代码示例 | ⭐️⭐️⭐️⭐️⭐️ |
| PANGLE_INTEGRATION_GUIDE.md | 集成指南 | ⭐️⭐️⭐️⭐️ |
| PANGLE_UPDATE_SUMMARY.md | 更新总结 | ⭐️⭐️⭐️ |
| PANGLE_README.md | 本文档 | ⭐️⭐️⭐️⭐️⭐️ |

---

**开始使用**: 从 [完整总结](./PANGLE_FINAL_SUMMARY.md) 开始阅读！

**最后更新**: 2026-05-23

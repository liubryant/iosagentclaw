# 穿山甲SDK编译指南

## ✅ 已完成配置

1. **已添加的系统库** (在 Other Linker Flags 中):
   - `-ObjC` (必需，加载所有ObjC类)
   - `-lc++` (C++标准库)
   - `-lresolv` (DNS解析)
   - `-lz` (压缩库)
   - `-lsqlite3` (数据库)
   - `-lbz2` (压缩库)
   - `-lxml2` (XML解析)
   - `-liconv` (字符编码转换)
   - `-lc++abi` (C++ ABI库)
   - `-Wl,-no_objc_stubs` **重要！禁用objc_msgSend stubs优化，解决链接错误**

2. **已清理**: Xcode DerivedData 缓存已清除

3. **关键修复**:
   - 添加了`-Wl,-no_objc_stubs`标志解决`_objc_msgSend$xxx`未定义符号错误
   - 这是因为SDK使用了较新的Objective-C优化，需要禁用才能正确链接

## 🔧 需要在Xcode中手动添加的系统框架

打开 `agentClaw.xcworkspace`，按照以下步骤操作：

### 步骤1: 打开项目设置
1. 点击项目导航器中的 `agentClaw` 项目
2. 选择 `TARGETS` -> `agentClaw`
3. 切换到 `General` 标签
4. 滚动到 `Frameworks, Libraries, and Embedded Content` 部分

### 步骤2: 添加必需的框架
点击 `+` 按钮，逐个搜索并添加以下框架（**不要选择 Embed**，保持默认）：

**必需框架** (Required):
- UIKit.framework
- WebKit.framework
- MediaPlayer.framework
- CoreLocation.framework
- AdSupport.framework
- CoreMedia.framework
- AVFoundation.framework
- CoreTelephony.framework
- StoreKit.framework
- SystemConfiguration.framework
- MobileCoreServices.framework
- CoreMotion.framework
- Accelerate.framework
- AudioToolbox.framework
- JavaScriptCore.framework
- Security.framework
- CoreImage.framework
- ImageIO.framework
- QuartzCore.framework
- CoreGraphics.framework
- CoreText.framework

**弱引用框架** (选择 "Optional" status):
- AppTrackingTransparency.framework (status: Optional)
- DeviceCheck.framework (status: Optional)
- CoreML.framework (status: Optional)
- CoreHaptics.framework (status: Optional)

### 步骤3: 重新编译

完成后：
1. 清理项目: `Product` -> `Clean Build Folder` (Shift+Cmd+K)
2. 编译项目: `Product` -> `Build` (Cmd+B)

## ⚠️ 重要提示

### 关于编译时间
- **BUAdSDK.xcframework 大小**: 411MB (静态库)
- **首次链接时间**: 可能需要 **5-10分钟** 甚至更长
- **CPU使用率**: 链接时 CPU 会达到 90-100%，这是正常的
- **请耐心等待**: 不要在看到 100% CPU 时就停止构建

### 如何判断是否在正常工作
在终端运行以下命令查看链接进程：
```bash
ps aux | grep "ld " | grep -v grep
```

如果看到 `ld` 进程存在且 CPU 使用率很高，说明正在正常链接，请耐心等待。

## 🚀 快捷命令行方法（可选）

如果你不想手动添加框架，可以尝试使用CocoaPods：

```bash
cd /Users/mac/Desktop/agentClaw

# 安装依赖
pod install

# 然后用 workspace 打开
open agentClaw.xcworkspace
```

注意：这需要更新的Ruby版本，之前尝试时失败了。

## 📝 问题排查

### 编译卡住超过15分钟
1. 打开活动监视器，查看内存是否充足
2. 检查磁盘空间是否足够 (至少需要5GB空闲)
3. 如果内存不足，关闭其他应用

### 链接错误
如果仍然有"undefined symbols"错误：
1. 确认所有系统框架都已添加
2. 检查 Other Linker Flags 是否包含所有必需的库
3. 清理构建文件夹重试

---

**最后更新**: 2026-05-23

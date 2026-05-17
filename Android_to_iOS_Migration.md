# AgentClaw Android 到 iOS 迁移方案

本文档基于 Android 仓库 `/Users/mac/agentclaw` 与当前 iOS 工程 `/Users/mac/Desktop/agentClaw` 的代码结构整理。当前 iOS 工程还是 SwiftUI 初始工程，尚未实现业务模块，因此本迁移方案按“从 Android 现状拆解、确定 iOS 可行边界、再设计 iOS 目标架构”的方式编写。

## 1. 结论摘要

Android 版本的 AgentClaw 不是普通聊天客户端，而是一个组合系统：

```text
Android 原生 UI
  -> 本地 Ubuntu rootfs
  -> proot 模拟 Linux 用户态
  -> Node.js / OpenClaw Gateway
  -> 本地 HTTP / WebSocket
  -> Android 设备能力 Node Bridge
```

iOS 版本不能原样移植这套本地 Linux/proot/Gateway 架构。主要原因是 iOS 不支持在 App Store 应用内像 Android 一样启动任意 Linux ELF、运行 proot、长期常驻本地服务、动态安装并执行 npm/apt/GitHub 导入代码。

推荐 iOS 迁移目标：

```text
iOS 原生客户端
  -> SwiftUI / UIKit Shell
  -> 本地 SQLite 缓存
  -> HTTP / WebSocket 连接远端或局域网 OpenClaw Gateway
  -> iOS 有限设备能力 Node Bridge
```

也就是说，iOS 端建议做成“OpenClaw 客户端 + 轻量设备节点”，不要做“内置 Linux 容器 + 本地 Gateway”。

## 2. Android 当前架构拆解

### 2.1 工程模块

Android 工程位于：

```text
/Users/mac/agentclaw
```

主要模块：

```text
app/
core/core_common/
```

`app` 是主应用模块，包含 UI、数据层、服务、rootfs/proot、设备能力、聊天、网关管理等。

`core/core_common` 是公共 Android 基础库，包含 BaseActivity、BaseViewModel、Dialog、Adapter、协程工具、Logger、设备信息等。

### 2.2 Android 核心目录

```text
app/src/main/java/ai/inmo/openclaw/ui
app/src/main/java/ai/inmo/openclaw/domain/model
app/src/main/java/ai/inmo/openclaw/data
app/src/main/java/ai/inmo/openclaw/service
app/src/main/java/ai/inmo/openclaw/proot
app/src/main/java/ai/inmo/openclaw/capability
app/src/main/java/ai/inmo/openclaw/di
```

职责划分：

| Android 目录 | 作用 | iOS 迁移策略 |
| --- | --- | --- |
| `ui/` | Activity、Fragment、ViewModel、Adapter | 重写为 SwiftUI / UIKit |
| `domain/model/` | 会话、消息、状态、NodeFrame 等模型 | 可按协议迁移为 Swift struct / enum |
| `data/local/db/` | Room 数据库、DAO、FTS | 重写为 SQLite / GRDB |
| `data/local/prefs/` | MMKV 偏好存储 | 重写为 UserDefaults / Keychain |
| `data/remote/api/` | Retrofit / OkHttp API | 重写为 URLSession |
| `data/remote/websocket/` | OkHttp WebSocket | 重写为 URLSessionWebSocketTask |
| `data/repository/` | 业务协调层 | 保留业务概念，Swift 重写 |
| `service/` | Android Foreground Service | iOS 无等价能力，需要改架构 |
| `proot/` | rootfs、proot、进程启动 | App Store 路线不可迁移 |
| `capability/` | Android 设备能力 | 部分用 iOS API 重写 |
| `di/AppGraph.kt` | 手写依赖容器 | Swift DependencyContainer / Environment |

### 2.3 Android 关键运行链路

启动链路：

```text
SplashActivity
  -> SplashViewModel.resolveDestination()
  -> SetupCoordinator.refreshStatus()
  -> StartupActivity 或 ShellActivity
```

本地环境初始化：

```text
SetupCoordinator.runSetup()
  -> SetupService.start()
  -> BootstrapManager.setupDirectories()
  -> BootstrapManager.writeResolvConf()
  -> 解包 rootfs-arm64.tar.gz.bin
  -> 安装 bionic-bypass / hook.js
  -> 创建 openclaw wrapper
```

Gateway 启动：

```text
GatewayManager.start()
  -> GatewayConfigService.prepareForLaunch()
  -> GatewayService.start()
  -> ProcessManager.startProotProcess("openclaw gateway")
  -> 本地监听 127.0.0.1:18789
```

聊天链路：

```text
ShellActivity / ChatFragment
  -> ShellChatViewModel
  -> SyncedChatWsManager
  -> ws://127.0.0.1:18789
  -> Room 缓存 SyncedSession / SyncedMessage / ToolCall
```

Node 能力链路：

```text
NodeManager.enable()
  -> NodeForegroundService.start()
  -> NodeWsManager.connect()
  -> connect.challenge
  -> NodeIdentityService 签名
  -> node.invoke.request
  -> capability handler
  -> node.invoke.result
```

## 3. iOS 平台可行性边界

### 3.1 不能原样迁移的能力

#### 3.1.1 Ubuntu rootfs + proot

Android 当前依赖：

```text
libproot.so
libprootloader.so
rootfs/ubuntu
ProcessBuilder
openclaw gateway
```

iOS 问题：

- Ubuntu rootfs 中的 `/bin/bash`、`node`、`openclaw` 是 Linux ABI，iOS 不能直接执行。
- iOS App 不能像 Android 一样启动任意 Linux ELF。
- proot 本身依赖 Linux/Android 系统调用语义，不能直接换成 iOS dylib。
- 即便技术上做用户态模拟，性能、兼容性、审核风险都很高。

结论：App Store 路线下不可迁移。

#### 3.1.2 本地长期 Gateway

Android 使用 `GatewayService` 前台服务常驻运行。

iOS 问题：

- iOS 没有 Android Foreground Service 等价物。
- App 进入后台后通常会被挂起。
- 后台模式只适合音频、定位、VoIP、蓝牙、后台传输等限定场景。
- 本地 HTTP/WebSocket Gateway 无法可靠长期运行。

结论：不能作为 iOS 主架构依赖。

#### 3.1.3 动态安装和执行代码

Android 当前包含：

- rootfs apt/deb 处理
- Node.js/OpenClaw 安装
- optional package 安装
- GitHub skill 导入
- 技能脚本执行

iOS 问题：

- App Store 对下载、安装、执行会改变 App 功能的代码限制严格。
- 从 GitHub 导入并执行技能脚本属于高风险行为。

结论：iOS 上只能保留“导入配置/文档/提示词”类能力，不能按 Android 方式执行外部代码。

#### 3.1.4 终端和 SSH 服务

Android 当前能力：

- Termux terminal-emulator / terminal-view
- proot shell
- rootfs 内 sshd

iOS 问题：

- 没有 proot shell。
- 无法常驻本地 sshd 服务作为产品核心能力。
- 终端 UI 可以做，但只能连接远端 shell 或显示受控命令输出。

结论：终端模块应改为远端 Terminal Client。

#### 3.1.5 系统级控制能力

Android `capability/` 中包含很多 iOS 不开放的系统能力：

- Wi-Fi 开关
- 蓝牙开关
- 全局返回/Home/导航
- 电源控制
- 启动任意 App
- 全局截图/录屏
- USB Serial
- 蓝牙 SPP
- AIDL 系统服务
- 全盘文件访问

结论：多数系统控制能力不能迁移，只能保留 iOS 公开 API 允许的子集。

### 3.2 可以完整复用的内容

这里的“复用”主要指协议、数据结构、产品逻辑复用，不是 Kotlin 源码直接复用。

#### 3.2.1 协议模型

可迁移为 Swift 模型：

- `NodeFrame`
- `SyncedSession`
- `SyncedMessage`
- `ContentSegment`
- `ToolCallUiModel`
- `GatewayState`
- `NodeState`
- `ChatSession`
- `ChatMessage`

迁移方式：

```text
Kotlin data class / sealed class
  -> Swift struct / enum
  -> Codable
```

#### 3.2.2 WebSocket 通信协议

Android `NodeWsManager` 和 `SyncedChatWsManager` 的协议思路可复用：

- request / response frame
- event frame
- pending request map
- timeout
- reconnect with exponential backoff
- challenge/connect/pairing
- node.invoke.request / node.invoke.result

iOS 可用：

```swift
URLSessionWebSocketTask
Task
AsyncStream
actor
```

#### 3.2.3 HTTP API

Android `NetworkModule`、`GatewayApi`、`ChatService` 使用的 API 概念可复用：

- gateway health check
- `/v1/chat/completions`
- token bearer auth
- dashboard URL/token 解析

iOS 使用：

```swift
URLSession
URLRequest
Codable
```

#### 3.2.4 本地聊天缓存结构

Room 的实体结构可迁移到 SQLite：

```text
sessions
messages
segments
tool_calls
fts_messages
fts_tool_calls
```

推荐使用 GRDB：

```text
GRDB
  -> migrations
  -> FTS5
  -> async database access
```

#### 3.2.5 产品信息架构

Android Shell 的产品结构可以在 iOS 保留：

- Chat
- Session List
- Ideas
- Search
- Provider Settings
- Node Status
- Logs
- Gateway Connect
- Skill Library

但 iOS 首屏不应照搬 Android 的密集布局，需要适配 iPhone/iPad。

### 3.3 可部分迁移的设备能力

| 能力 | Android 当前 | iOS 可行替代 |
| --- | --- | --- |
| Camera | Camera2 枚举/拍摄 | AVFoundation / PhotosPicker，需用户交互 |
| Location | LocationManager | CoreLocation，需授权 |
| Sensor | SensorManager | CoreMotion，部分传感器可用 |
| Haptic | Vibrator | UIImpactFeedbackGenerator / CoreHaptics |
| Screen | MediaProjection | ReplayKit，仅有限录屏/广播能力 |
| File | app/shared/rootfs | App sandbox + Files picker + security scoped resource |
| Bluetooth | Classic/BLE | CoreBluetooth 仅 BLE，不能经典 SPP |
| Serial | USB Serial / Bluetooth SPP | App Store 普通应用基本不可做，MFi/特定硬件另议 |
| System | AIDL/系统控制 | 大多数不可做，仅 openURL/有限设置跳转 |

## 4. iOS 目标架构设计

### 4.1 推荐工程结构

当前 iOS 工程位于：

```text
/Users/mac/Desktop/agentClaw
```

建议逐步整理为：

```text
agentClaw/
  App/
    agentClawApp.swift
    AppEnvironment.swift
    DependencyContainer.swift

  Core/
    Models/
    Networking/
    Storage/
    Utilities/

  Features/
    Shell/
    Chat/
    Sessions/
    Search/
    Gateway/
    Node/
    Providers/
    Skills/
    Settings/
    Logs/

  Services/
    GatewayClient.swift
    SyncedChatWebSocketClient.swift
    NodeWebSocketClient.swift
    NodeIdentityService.swift
    CapabilityRegistry.swift

  Persistence/
    Database/
    Preferences/
    Keychain/

  Resources/
    Assets.xcassets
```

### 4.2 iOS 模块映射

| Android 模块 | iOS 模块 | 说明 |
| --- | --- | --- |
| `AppGraph.kt` | `DependencyContainer.swift` | 手写依赖容器 |
| `PreferencesManager.kt` | `AppPreferences.swift` + `KeychainStore.swift` | token/identity 放 Keychain |
| `NetworkModule.kt` | `HTTPClient.swift` | URLSession |
| `NodeWsManager.kt` | `NodeWebSocketClient.swift` | URLSessionWebSocketTask |
| `SyncedChatWsManager.kt` | `SyncedChatService.swift` | actor 管理状态 |
| `AppDatabase.kt` | `AppDatabase.swift` | GRDB / SQLite |
| `GatewayManager.kt` | `GatewayConnectionManager.swift` | 连接远端 Gateway，不启动本地 Gateway |
| `NodeManager.kt` | `NodeManager.swift` | 保留连接/签名/能力注册 |
| `capability/*` | `Capabilities/*` | iOS API 子集 |
| `ShellActivity.kt` | `ShellView.swift` | SwiftUI |
| `ChatFragment.kt` | `ChatView.swift` | SwiftUI |
| `ChatSearchActivity.kt` | `SearchView.swift` | SwiftUI |
| `SettingsActivity.kt` | `SettingsView.swift` | SwiftUI |
| `GatewayService.kt` | 不迁移 | 改为远端连接 |
| `SetupCoordinator.kt` | 不迁移 | rootfs 初始化取消 |
| `BootstrapManager.kt` | 不迁移 | rootfs/proot 取消 |
| `ProcessManager.kt` | 不迁移 | iOS 不启动 Linux 进程 |
| `TerminalActivity.kt` | `RemoteTerminalView.swift` | 仅远端终端客户端 |

### 4.3 推荐运行形态

iOS 端提供三种连接模式：

#### 模式 A：远端 Gateway

```text
iPhone/iPad
  -> HTTPS/WSS
  -> 云端 OpenClaw Gateway
```

优点：

- 最符合 iOS 平台限制
- App Store 风险低
- 后台问题少

缺点：

- 依赖服务器
- 本地设备自动化能力有限

#### 模式 B：局域网 Gateway

```text
iPhone/iPad
  -> ws/http
  -> Mac / Android / NAS 上的 OpenClaw Gateway
```

优点：

- 可复用 Android 设备或桌面作为执行节点
- iOS 做轻客户端

缺点：

- 配网、发现、鉴权要设计好
- 离线能力弱

#### 模式 C：本机有限运行时

```text
iOS App
  -> 内置轻量规则/提示词/模型配置
  -> 不执行外部代码
```

优点：

- 可离线做部分 UI 和缓存

缺点：

- 无法提供完整 OpenClaw 本地执行环境

推荐优先级：

```text
模式 A + 模式 B > 模式 C
```

## 5. iOS 数据模型设计

### 5.1 NodeFrame

Android `NodeFrame` 是 Node 协议核心，iOS 建议做成：

```swift
struct NodeFrame: Codable, Identifiable {
    var id: String?
    var method: String?
    var event: String?
    var payload: [String: JSONValue]?
    var error: [String: JSONValue]?
}
```

需要补一个通用 `JSONValue` enum：

```swift
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
}
```

### 5.2 Chat Models

建议模型：

```swift
struct ChatSession: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
}

struct SyncedSession: Identifiable, Codable, Equatable {
    let sessionKey: String
    var title: String
    var updatedAt: Date
    var kind: String?
}

struct SyncedMessage: Identifiable, Codable, Equatable {
    let id: String
    var role: String
    var content: String
    var createdAt: Date
    var isStreaming: Bool
    var segments: [ContentSegment]
    var sendStatus: MessageSendStatus
}

enum ContentSegment: Codable, Equatable {
    case text(String)
    case tools([ToolCall])
}
```

### 5.3 状态管理

iOS 推荐使用：

```text
ObservableObject / @Observable
async/await
actor
AsyncStream
```

状态层建议：

```text
ShellViewModel
ChatViewModel
GatewayViewModel
NodeViewModel
SettingsViewModel
SearchViewModel
```

其中 WebSocket 和数据库写入建议放到 actor/service 中，不直接在 ViewModel 里做复杂同步。

## 6. 存储迁移方案

### 6.1 Room 到 SQLite/GRDB

Android Room 数据库当前包含：

```text
ChatSessionEntity
ChatMessageEntity
SyncedSessionEntity
SyncedMessageEntity
SyncedSegmentEntity
SyncedToolCallEntity
```

iOS 建议使用 GRDB，原因：

- 原生 SQLite 封装成熟
- 支持 migration
- 支持 FTS5
- 与 Swift Codable/Record 结合较好

建议表：

```sql
CREATE TABLE synced_sessions (
    session_key TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    kind TEXT
);

CREATE TABLE synced_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_key TEXT NOT NULL,
    message_index INTEGER NOT NULL,
    client_message_id TEXT,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    is_streaming INTEGER NOT NULL,
    send_status TEXT NOT NULL
);

CREATE TABLE synced_segments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id INTEGER NOT NULL,
    segment_index INTEGER NOT NULL,
    type TEXT NOT NULL,
    text_content TEXT
);

CREATE TABLE synced_tool_calls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    segment_id INTEGER NOT NULL,
    tool_index INTEGER NOT NULL,
    tool_call_id TEXT,
    name TEXT NOT NULL,
    description TEXT,
    result_preview TEXT
);
```

FTS：

```sql
CREATE VIRTUAL TABLE fts_synced_messages
USING fts5(content);

CREATE VIRTUAL TABLE fts_synced_tool_calls
USING fts5(name, description, result_preview);
```

### 6.2 MMKV 到 UserDefaults/Keychain

Android `PreferencesManager` 迁移：

| Android key | iOS 存储 | 说明 |
| --- | --- | --- |
| `auto_start_gateway` | 删除或 UserDefaults | iOS 不自启本地 Gateway |
| `setup_complete` | 删除 | iOS 无 rootfs setup |
| `dashboard_url` | UserDefaults | Gateway 地址 |
| `node_enabled` | UserDefaults | 是否启用 Node |
| `node_device_token` | Keychain | 敏感 |
| `node_gateway_token` | Keychain | 敏感 |
| `node_gateway_host` | UserDefaults | Gateway host |
| `node_gateway_port` | UserDefaults | Gateway port |
| `last_selected_chat_session_key` | UserDefaults | UI 状态 |
| `terms_accepted` | UserDefaults | 用户协议 |

### 6.3 文件存储

Android 的 rootfs 文件作用在 iOS 取消。

iOS 文件目录建议：

```text
Application Support/
  agentClaw.sqlite
  logs/
  exports/
  skills/

Documents/
  user-visible exports

tmp/
  temporary attachments
```

注意：iOS 文件访问应通过 Document Picker / Files App 授权，不要设计“全盘文件系统”能力。

## 7. 网络与同步迁移

### 7.1 Gateway Client

Android 当前默认本地：

```text
http://127.0.0.1:18789
```

iOS 应改为可配置：

```text
https://gateway.example.com
http://192.168.x.x:18789
```

建议配置项：

```swift
struct GatewayConfig: Codable, Equatable {
    var baseURL: URL
    var token: String?
    var allowInsecureLocalNetwork: Bool
}
```

iOS 需要处理：

- ATS 配置
- Local Network 权限说明
- HTTPS 优先
- token 存 Keychain
- 连接测试

### 7.2 WebSocket

建议设计：

```swift
actor WebSocketClient {
    func connect(url: URL, token: String?) async throws
    func disconnect()
    func send(_ frame: NodeFrame) async throws
    func request(_ frame: NodeFrame, timeout: Duration) async throws -> NodeFrame
    var frames: AsyncStream<NodeFrame> { get }
}
```

需要实现：

- pending request 字典
- request timeout
- 自动重连
- 网络状态变化监听
- app foreground/background 处理

### 7.3 后台策略

iOS 进入后台时建议：

- 断开非必要 WebSocket
- 保存当前生成状态
- 回前台后 reconnect
- 对正在生成的回复从 Gateway 拉取最新会话状态

不要承诺后台持续生成或长期保持 Node 在线，除非业务走符合 Apple 后台模式的专用场景。

## 8. Node 能力迁移

### 8.1 iOS Capability Registry

Android：

```text
NodeManager.registerCapabilities()
  -> CameraCapabilityHandler
  -> FsCapabilityHandler
  -> LocationCapabilityHandler
  -> SystemCapabilityHandler
  -> ScreenCapabilityHandler
  -> SensorCapabilityHandler
  -> FlashCapabilityHandler
  -> VibrationCapabilityHandler
  -> SerialCapabilityHandler
```

iOS 建议：

```swift
protocol NodeCapabilityHandler {
    var name: String { get }
    var commands: [String] { get }
    func handle(command: String, params: [String: JSONValue]) async -> NodeFrame
}

final class CapabilityRegistry {
    private var handlers: [String: NodeCapabilityHandler]
}
```

### 8.2 首批可实现能力

建议第一阶段只实现：

```text
fs.read / fs.write / fs.list，限 App sandbox
location.current
camera.pick_image，用户交互
photo.pick，用户交互
sensor.read，有限 CoreMotion
haptic.play
system.device_info
system.open_url
```

暂缓：

```text
screen.record
serial.*
bluetooth.*
system.wifi.*
system.power.*
system.navigation.*
terminal.*
```

### 8.3 能力差异提示

iOS 端必须向 Gateway 报告真实 capabilities，不要伪装 Android 能力。否则模型会下发 iOS 无法执行的工具调用。

示例：

```json
{
  "caps": ["fs", "location", "camera", "sensor", "haptic", "system"],
  "commands": [
    "fs.read",
    "fs.write",
    "fs.list",
    "location.current",
    "camera.pick_image",
    "sensor.read",
    "haptic.play",
    "system.device_info",
    "system.open_url"
  ]
}
```

## 9. UI 迁移方案

### 9.1 当前 iOS 工程状态

当前文件：

```text
agentClaw/agentClawApp.swift
agentClaw/ContentView.swift
```

目前只是 SwiftUI 默认页面。

### 9.2 推荐首屏

iOS 首屏建议不是 Android 的完整 Shell 复刻，而是：

```text
Gateway 连接状态
当前会话
输入框
会话列表入口
设置入口
```

iPad 可以做双栏：

```text
Sidebar sessions/settings
Main chat
Inspector/tool timeline
```

iPhone 采用导航栈：

```text
Chat
  -> Sessions
  -> Search
  -> Settings
  -> Node
```

### 9.3 UI 模块优先级

第一阶段：

- Gateway 设置页
- Chat 页面
- 会话列表
- 消息列表
- 输入框
- Markdown 渲染
- 基础错误/重连状态

第二阶段：

- 搜索
- Tool call timeline
- Provider 管理
- Node 状态页
- 日志页

第三阶段：

- Ideas
- Skill Library
- 文件导入/导出
- iPad 多栏布局

## 10. 功能迁移清单

### 10.1 完全取消或改为远端

| Android 功能 | iOS 处理 |
| --- | --- |
| rootfs 初始化 | 取消 |
| proot 启动 | 取消 |
| 本地 `openclaw gateway` | 改为远端/局域网 Gateway |
| apt/deb 安装 | 取消 |
| Node.js 安装 | 取消 |
| Homebrew 安装 | 取消 |
| 本地 SSH 服务 | 改为远端 SSH 客户端或取消 |
| 本地 Terminal shell | 改为远端 Terminal |
| 自动后台常驻 Gateway | 取消 |

### 10.2 重写但保留功能

| 功能 | iOS 实现 |
| --- | --- |
| Chat | SwiftUI + WebSocket/HTTP |
| Session cache | SQLite/GRDB |
| Search | SQLite FTS5 |
| Gateway status | 远端 health check |
| Node pairing | Swift WebSocket + Keychain identity |
| Device capabilities | iOS 能力子集 |
| Provider config | Swift 配置模型 + Gateway API |
| Logs | 本地日志 + Gateway 日志拉取 |
| Skills | 只作为配置/说明/远端技能管理 |

### 10.3 可直接借鉴的算法/策略

- WebSocket pending request
- reconnect exponential backoff
- dashboard token parsing
- session title from first user message
- local pending message
- streaming assistant message merge
- tool call display model
- FTS rebuild/append 策略
- Node challenge/connect/pairing 状态机

## 11. 实施阶段计划

### Phase 0：项目基础整理

目标：把当前空 SwiftUI 工程整理成可持续开发结构。

任务：

- 建立目录结构
- 添加 `DependencyContainer`
- 添加 `AppConfig`
- 添加基础 Logger
- 添加 SwiftLint/格式化策略，可选
- 确定最低 iOS 版本
- 决定 SwiftUI-only 还是 SwiftUI + UIKit 混合

产出：

```text
可编译的空壳架构
```

### Phase 1：Gateway 连接

目标：iOS 能配置并连接远端 Gateway。

任务：

- `GatewayConfig`
- `GatewayClient`
- health check
- token 存储
- Gateway 设置页
- 连接状态 UI

产出：

```text
iOS App 可以连接 OpenClaw Gateway 并显示状态
```

### Phase 2：聊天基础

目标：完成最小可用聊天。

任务：

- Chat models
- Message list UI
- Composer UI
- `/v1/chat/completions` HTTP 调用
- Markdown 文本显示
- 错误状态

产出：

```text
可向 Gateway 发送消息并展示回复
```

### Phase 3：同步聊天 WebSocket

目标：迁移 Android Shell Chat 的核心体验。

任务：

- `SyncedChatWebSocketClient`
- request/response/event frame
- session list
- history load
- streaming update
- stop generation
- reconnect

产出：

```text
支持同步会话、流式回复和会话切换
```

### Phase 4：本地缓存与搜索

目标：补齐离线缓存和搜索。

任务：

- 引入 SQLite/GRDB
- 建表与 migration
- session/message/segment/tool call 缓存
- FTS5 搜索
- Search UI

产出：

```text
支持会话缓存、历史加载、全文搜索
```

### Phase 5：Node 轻量能力

目标：iOS 作为受限 Node 接入 Gateway。

任务：

- `NodeIdentityService`
- Keychain 保存密钥/token
- `NodeWebSocketClient`
- challenge/connect
- capability registry
- 首批 iOS capability

产出：

```text
iOS 可以作为轻量 Node 上报能力并响应工具调用
```

### Phase 6：高级功能

目标：增强产品体验。

任务：

- Provider 管理
- Tool call timeline
- Logs
- Skill library 只读/远端管理
- 文件导入导出
- iPad 适配

产出：

```text
接近 Android Shell 的 iOS 体验，但不包含本地 Linux 容器
```

## 12. 风险与决策点

### 12.1 关键产品决策

必须先定：

```text
iOS 是否必须离线独立运行完整 OpenClaw？
```

如果答案是“必须”，App Store 路线基本不可行，需要改成：

- macOS App
- 企业签名/内部分发
- 越狱设备
- 或重新实现一个 App Store 可接受的受限运行时

如果答案是“不必须”，推荐走远端 Gateway 方案。

### 12.2 App Store 风险

高风险点：

- 动态执行外部下载代码
- 内置解释器执行用户下载脚本
- 长期后台服务
- 本地开放网络服务
- 系统自动化控制
- 未经用户明确操作访问文件/相机/位置

### 12.3 技术风险

- WebSocket 协议需和 Gateway 保持兼容
- Android 里部分协议可能隐含本地 Gateway 假设
- iOS 后台恢复后会话状态需要重新同步
- iOS 文件权限模型和 Android 差异较大
- Node capability 子集变小后，模型提示词和工具选择策略也要调整

## 13. 建议的第一批代码文件

建议下一步在 iOS 工程创建：

```text
agentClaw/Core/Models/JSONValue.swift
agentClaw/Core/Models/NodeFrame.swift
agentClaw/Core/Models/ChatModels.swift
agentClaw/Core/Networking/HTTPClient.swift
agentClaw/Core/Networking/WebSocketClient.swift
agentClaw/Core/Storage/AppPreferences.swift
agentClaw/Core/Storage/KeychainStore.swift
agentClaw/App/DependencyContainer.swift
agentClaw/Features/Gateway/GatewayConfig.swift
agentClaw/Features/Gateway/GatewayClient.swift
agentClaw/Features/Gateway/GatewaySettingsView.swift
agentClaw/Features/Chat/ChatView.swift
agentClaw/Features/Chat/ChatViewModel.swift
```

第一批不要碰 rootfs/proot/terminal。先完成远端 Gateway 连接和最小聊天闭环。

## 14. Android 到 iOS 对照总表

| Android 文件/模块 | 是否迁移 | iOS 目标 |
| --- | --- | --- |
| `App.kt` | 部分 | `agentClawApp.swift` 初始化容器 |
| `AppGraph.kt` | 重写 | `DependencyContainer.swift` |
| `AppConstants.kt` | 部分 | `AppConfig.swift` |
| `PreferencesManager.kt` | 重写 | `AppPreferences` + `KeychainStore` |
| `AppDatabase.kt` | 重写 | `GRDB AppDatabase` |
| `ChatRepository.kt` | 重写 | `ChatStore` |
| `ChatService.kt` | 重写 | `GatewayChatClient` |
| `SyncedChatWsManager.kt` | 重写 | `SyncedChatService` |
| `SyncedChatCacheRepository.kt` | 重写 | `SyncedChatCacheStore` |
| `GatewayManager.kt` | 改造 | `GatewayConnectionManager` |
| `GatewayService.kt` | 不迁移 | 远端 Gateway 替代 |
| `SetupCoordinator.kt` | 不迁移 | 无 |
| `BootstrapManager.kt` | 不迁移 | 无 |
| `ProcessManager.kt` | 不迁移 | 无 |
| `NodeManager.kt` | 部分重写 | `NodeManager` |
| `NodeWsManager.kt` | 重写 | `NodeWebSocketClient` |
| `NodeIdentityService.kt` | 重写 | `NodeIdentityService` + Keychain |
| `capability/*` | 部分重写 | iOS capability 子集 |
| `ShellActivity.kt` | 重写 | `ShellView` |
| `ChatFragment.kt` | 重写 | `ChatView` |
| `ChatSearchActivity.kt` | 重写 | `SearchView` |
| `ProvidersActivity.kt` | 重写 | `ProvidersView` |
| `SettingsActivity.kt` | 重写 | `SettingsView` |
| `TerminalActivity.kt` | 改造 | `RemoteTerminalView` |
| `SshForegroundService.kt` | 不迁移 | 远端 SSH 客户端或取消 |
| `assets/skills` | 部分 | 只读 skill metadata / 远端技能管理 |
| `jniLibs/libproot*` | 不迁移 | 无 |

## 15. 最终建议

短期目标应定义为：

```text
在 iOS 上实现可连接 OpenClaw Gateway 的原生客户端，
支持聊天、会话同步、搜索、Provider 配置和有限设备能力。
```

不要把第一阶段目标定义为：

```text
在 iOS 内置完整 Linux 虚拟机并运行 OpenClaw Gateway。
```

这不是简单工程量问题，而是 iOS 平台能力、审核规则和运行模型共同限制导致的架构不可行。

推荐下一步直接进入 Phase 0 + Phase 1：

1. 整理 iOS 目录结构。
2. 建立基础模型 `JSONValue`、`NodeFrame`、`ChatModels`。
3. 实现 `GatewayConfig`、`GatewayClient`。
4. 做一个 Gateway 设置页和连接测试。
5. 再开始迁移聊天 UI。


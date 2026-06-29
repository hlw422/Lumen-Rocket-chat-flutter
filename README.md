# LumenIM Flutter — Rocket.Chat 移动端客户端

基于 [LumenIM Web](https://github.com/gzydong/LumenIM) 改造的 **Rocket.Chat Flutter 移动端聊天客户端**，后端对接 Rocket.Chat REST API + DDP WebSocket 实时推送，支持 Android / iOS / Windows / macOS / Linux / Web 全平台。

---

## 技术栈

| 类别 | 技术 | 版本 |
|------|------|------|
| 框架 | Flutter (Dart) | SDK ^3.10.7 |
| 状态管理 | Provider | 6.1 |
| HTTP 客户端 | Dio | 5.7 |
| WebSocket | web_socket_channel | 3.0 |
| 本地存储 | shared_preferences | 2.3 |
| 图片缓存 | cached_network_image | 3.4 |
| 文件选择 | file_picker | 8.1 |
| 图片选择 | image_picker | 1.1 |
| 文件路径 | path_provider | 2.1 |
| MIME 检测 | mime | 2.0 |

---

## 功能概览

- 🔐 **用户认证** — 用户名/密码登录 + 注册，`X-Auth-Token` + `X-User-Id` 认证头，支持自动登录
- 💬 **实时聊天** — DDP WebSocket 订阅 `stream-room-messages`，消息即时送达，`_id` 去重
- 📋 **三种会话类型** — 公开频道（`#`）、私有群组（`🔒`）、私聊（`👤`），统一列表展示
- 👥 **用户搜索** — 在线用户列表 + 本地过滤搜索，支持一键发起私聊
- 📎 **文件消息** — 图片消息发送/预览、文件上传/下载，带认证头直接加载
- 😄 **表情面板** — 6 大分类 300+ emoji，BottomSheet 弹出选择
- 📱 **响应式布局** — 桌面端三栏布局，移动端底部导航栏切换
- 🔄 **断线重连** — DDP WebSocket 指数退避自动重连（最多 10 次，间隔 1s → 30s）
- 🌗 **Material 3** — 基于 Material Design 3 的动态主题色彩

---

## 项目结构

```
flutter_code/
├── lib/
│   ├── main.dart                     # 应用入口，MultiProvider 注入全局状态
│   ├── app.dart                      # MaterialApp，路由 + 主题配置
│   ├── models/
│   │   ├── user.dart                 # RCUser, RCLoginRequest, RCRegister 等用户模型
│   │   ├── room.dart                 # RCRoom, Conversation, ConversationType
│   │   ├── message.dart              # RCMessage, RCAttachment, ChatMessage, ChatAttachment
│   │   └── ddp_message.dart          # DDP 协议消息模型（connect/sub/method/changed）
│   ├── services/
│   │   ├── api_client.dart           # Dio HTTP 客户端 + 拦截器（自动注入认证头/401处理）
│   │   ├── api_service.dart          # Rocket.Chat REST API（15 个接口端点）
│   │   ├── ddp_client.dart           # DDP WebSocket 客户端（连接/登录/订阅/重连/心跳）
│   │   └── file_service.dart         # 文件下载服务（带认证头 + 自动打开）
│   ├── providers/
│   │   ├── auth_provider.dart        # 认证状态（login/logout/register/restore）
│   │   ├── chat_provider.dart        # 聊天状态（会话列表/消息/DDP实时/文件选择）
│   │   └── user_provider.dart        # 用户状态（用户列表/搜索/创建私聊）
│   ├── pages/
│   │   ├── login_page.dart           # 登录页（Card 卡片 + 错误提示）
│   │   ├── register_page.dart        # 注册页（用户名/密码/确认密码）
│   │   └── chat/
│   │       └── chat_home_page.dart   # 主界面（三栏布局，含空状态引导）
│   ├── widgets/
│   │   ├── conversation_list.dart    # 会话列表（左栏，lastMessage 排序 + 搜索过滤）
│   │   ├── conversation_tile.dart    # 会话条目（头像/名称/前缀图标/最后消息/时间）
│   │   ├── message_panel.dart        # 消息面板（中栏，消息列表 + 输入栏 + 发送按钮）
│   │   ├── message_bubble.dart       # 消息气泡（自己右侧/他人左侧，文字/图片/文件）
│   │   ├── attachment_widget.dart    # 附件渲染（图片预览/文件下载/视频占位）
│   │   ├── emoji_picker.dart         # 表情选择器（6 分类 GridView + BottomSheet）
│   │   ├── user_search.dart          # 用户搜索面板（右栏，搜索 + 列表 + 发起私聊）
│   │   └── user_tile.dart            # 用户条目（头像 + 用户名 + 状态指示器）
│   └── utils/
│       ├── auth_storage.dart         # Token 本地存储（SharedPreferences）
│       ├── constants.dart            # 服务端地址常量（rcHost / apiBase / wsUrl）
│       └── date_format.dart          # 时间格式化工具（刚刚/n分钟前/n天前/n个月前）
├── android/                          # Android 平台配置
├── ios/                              # iOS 平台配置
├── windows/                          # Windows 桌面端配置
├── macos/                            # macOS 桌面端配置
├── linux/                            # Linux 桌面端配置
├── web/                              # Web 端配置
├── pubspec.yaml                      # 依赖管理
├── analysis_options.yaml             # Dart 静态分析规则
└── README.md
```

---

## 快速开始

### 环境要求

- Flutter SDK >= 3.10.7
- Android Studio / Xcode（移动端）/ Visual Studio（Windows）
- Rocket.Chat 服务端运行中（默认 `http://192.168.1.189:3000`）

### 安装依赖

```bash
cd flutter_code
flutter pub get
```

### 启动

```bash
# 连接设备后，直接运行
flutter run

# 指定平台运行
flutter run -d android      # Android
flutter run -d ios          # iOS
flutter run -d windows      # Windows
flutter run -d macos        # macOS
flutter run -d chrome       # Web
```

### 配置服务端地址

编辑 `lib/utils/constants.dart`，修改 Rocket.Chat 后端地址：

```dart
/// Rocket.Chat 服务端地址
const String rcHost = 'http://192.168.1.189:3000';  // ← 改为你的地址

/// REST API 基准路径
const String apiBase = '$rcHost/api/v1';

/// WebSocket DDP 地址
const String wsUrl = 'ws://192.168.1.189:3000/websocket';  // ← 改为你的地址
```

---

## Rocket.Chat API 对接

| 功能 | Rocket.Chat REST API |
|------|---------------------|
| 登录 | `POST /api/v1/login` |
| 注册 | `POST /api/v1/users.register` |
| 登出 | `POST /api/v1/logout` |
| 当前用户 | `GET /api/v1/me` |
| 会话列表 | `GET /api/v1/channels.list` + `groups.list` + `im.list` |
| 消息历史 | `GET /api/v1/{type}.messages?roomId=xxx&count=50` |
| 发送消息 | `POST /api/v1/chat.postMessage` `{roomId, text}` |
| 删除消息 | `POST /api/v1/chat.delete` |
| 用户列表 | `GET /api/v1/users.list` |
| 用户信息 | `GET /api/v1/users.info?userId=xxx` |
| 创建私聊 | `POST /api/v1/im.create` |
| 文件上传 | `POST /api/v1/rooms.upload/{roomId}` |
| 用户在线状态 | `GET /api/v1/users.getPresence` |

### 认证机制

| | 认证头 | Token 格式 |
|------|------|------|
| Rocket.Chat | `X-Auth-Token` + `X-User-Id` | `{ userId, authToken }` 存储于 SharedPreferences |

Dio 拦截器自动为每个请求注入认证头，`401` 未授权时自动触发登出。

### 响应结构

Rocket.Chat 返回 `{ success: true, data: {...} }`，`ApiService` 自动解包 `data` 字段，调用方直接获取业务数据。

---

## 实时消息（DDP WebSocket）

使用 **Meteor DDP 协议** 通过 WebSocket 连接 Rocket.Chat，实现实时消息推送。

### 协议流程

```
1. 连接    → {"msg":"connect","version":"1","support":["1","pre2","pre1"]}
2. 响应    ← {"msg":"connected","session":"xxx"}
3. 登录    → {"msg":"method","method":"login","params":[{"resume":"TOKEN"}]}
4. 订阅    → {"msg":"sub","name":"stream-room-messages","params":["ROOM_ID",false]}
5. 推送    ← {"msg":"changed","fields":{"args":[{新消息对象}]}}
```

### 客户端特性

- 登录后自动建连
- 选择会话时 DDP 订阅房间消息流，切换会话时自动退订旧房间 + 订阅新房间
- 指数退避自动重连（最多 10 次，间隔 1s → 2s → 4s → … → 30s）
- 30 秒心跳 keepalive 保持连接
- 消息 `_id` 去重，防止重复显示

详见 `lib/services/ddp_client.dart`。

---

## 部署打包

### Android APK

```bash
flutter build apk --release
# 输出: build/app/outputs/flutter-apk/app-release.apk
```

### iOS

```bash
flutter build ios --release
# 然后在 Xcode 中 Archive → Distribute
```

### Windows

```bash
flutter build windows --release
# 输出: build/windows/x64/runner/Release/
```

### macOS

```bash
flutter build macos --release
# 输出: build/macos/Build/Products/Release/
```

---

## Docker 部署 Rocket.Chat

如需本地运行 Rocket.Chat 服务端：

```bash
# 使用 Docker Compose 快速启动
version: '3'
services:
  rocketchat:
    image: rocket.chat:latest
    ports:
      - "3000:3000"
    environment:
      - ROOT_URL=http://192.168.1.189:3000
      - MONGO_URL=mongodb://mongo:27017/rocketchat
    depends_on:
      - mongo

  mongo:
    image: mongo:6.0
    volumes:
      - mongo_data:/data/db

volumes:
  mongo_data:
```

---

## 与 Web 版 LumenIM 对应关系

| Web 版文件 | Flutter 版文件 | 功能 |
|------|------|------|
| `src/services/ddp-client.ts` | `lib/services/ddp_client.dart` | DDP WebSocket 客户端 |
| `src/apis/rocket-api.ts` | `lib/services/api_service.dart` | REST API 接口 |
| `src/apis/client.ts` | `lib/services/api_client.dart` | HTTP 客户端 |
| `src/stores/useAuthStore.ts` | `lib/providers/auth_provider.dart` | 认证状态 |
| `src/stores/useChatStore.ts` | `lib/providers/chat_provider.dart` | 聊天状态 |
| `src/stores/useUserStore.ts` | `lib/providers/user_provider.dart` | 用户状态 |
| `src/utils/auth.ts` | `lib/utils/auth_storage.dart` | Token 存储 |
| `src/types/rocket.ts` | `lib/models/*.dart` | 数据模型 |
| `src/views/auth/LoginView.vue` | `lib/pages/login_page.dart` | 登录页 |
| `src/views/chat/ChatView.vue` | `lib/pages/chat/chat_home_page.dart` | 聊天主页 |
| `src/views/chat/ConversationList.vue` | `lib/widgets/conversation_list.dart` | 会话列表 |
| `src/views/chat/MessagePanel.vue` | `lib/widgets/message_panel.dart` | 消息面板 |
| `src/views/chat/UserSearch.vue` | `lib/widgets/user_search.dart` | 用户搜索 |

---

## 开发说明

### 静态分析

```bash
# 运行代码分析（当前 0 error）
dart analyze lib/
```

### 运行测试

```bash
flutter test
```

### 代码生成（如需要）

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 开源协议

基于 [LumenIM](https://github.com/gzydong/LumenIM) 的前端 UI 设计改造，对接 Rocket.Chat 后端，保留原项目许可。

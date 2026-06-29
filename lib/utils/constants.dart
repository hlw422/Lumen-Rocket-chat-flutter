/// Rocket.Chat 服务端地址
const String rcHost = 'http://192.168.1.189:3000';

/// REST API 基准路径
const String apiBase = '$rcHost/api/v1';

/// WebSocket DDP 地址
const String wsUrl = 'ws://192.168.1.189:3000/websocket';

/// 服务器直连地址（备用，用于排查网络问题）
const String rcHostAlt = 'http://127.0.0.1:3000';
const String apiBaseAlt = '$rcHostAlt/api/v1';

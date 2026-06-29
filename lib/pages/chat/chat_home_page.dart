import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/conversation_list.dart';
import '../../widgets/message_panel.dart';
import '../../widgets/user_search.dart';

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});
  @override State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chat = context.read<ChatProvider>();
      chat.connectDdp();
      chat.loadConversations();
      context.read<UserProvider>().loadUsers();
      // 监听 currentRoomId 变化，手机端自动切到消息面板
      chat.addListener(_onProviderChanged);
    });
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final chat = context.read<ChatProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    // 手机端：currentRoomId 从 null 变为有值时自动切到消息面板
    if (!isWide && chat.currentRoomId != null && _tabIndex != 1) {
      setState(() => _tabIndex = 1);
    }
  }

  @override
  void dispose() {
    context.read<ChatProvider>().removeListener(_onProviderChanged);
    context.read<ChatProvider>().disposeResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final chat = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();

    if (isWide) {
      // 桌面：Row 三栏布局
      return Scaffold(
        appBar: _buildAppBar(context, auth),
        body: Column(
          children: [
            if (chat.conversationsError && chat.conversations.isEmpty)
              _buildErrorBanner(chat),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 300, child: _buildConvList(chat)),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildMsgPanel(chat)),
                  if (chat.currentRoomId != null) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(width: 280, child: const UserSearchPanel()),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 手机端：底部导航切换
    return Scaffold(
      appBar: _tabIndex == 1 && chat.currentConversation != null
        ? _buildAppBar(context, auth)
        : _tabIndex == 2
          ? AppBar(title: const Text('在线用户'))
          : _buildAppBar(context, auth),
      body: Column(
        children: [
          if (chat.conversationsError && chat.conversations.isEmpty)
            _buildErrorBanner(chat),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildConvList(chat),
                _buildMsgPanel(chat),
                const UserSearchPanel(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: '会话'),
          NavigationDestination(icon: Icon(Icons.message_outlined), selectedIcon: Icon(Icons.message), label: '消息'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: '用户'),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, AuthProvider auth) {
    final chat = context.read<ChatProvider>();
    return AppBar(
      title: Text(chat.currentConversation?.name ?? 'RocketChat'),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => setState(() => _tabIndex = 0),
      ),
      actions: [
        // DDP 连接状态
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            Icons.circle,
            size: 10,
            color: chat.ddpConnected ? Colors.green : Colors.red,
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'logout') {
              await auth.logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 20), const SizedBox(width: 8), const Text('退出登录')])),
          ],
        ),
      ],
    );
  }

  Widget _buildConvList(ChatProvider chat) => const ConversationListWidget();

  Widget _buildErrorBanner(ChatProvider chat) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.shade50,
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              chat.error ?? '无法连接服务器',
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              chat.loadConversations();
              chat.connectDdp();
            },
            child: const Text('重试', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildMsgPanel(ChatProvider chat) {
    if (chat.currentRoomId == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('选择一个会话开始聊天', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return const MessagePanelWidget();
  }
}

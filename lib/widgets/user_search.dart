import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/user.dart';
import 'user_tile.dart';

class UserSearchPanel extends StatefulWidget {
  const UserSearchPanel({super.key});
  @override State<UserSearchPanel> createState() => _UserSearchPanelState();
}

class _UserSearchPanelState extends State<UserSearchPanel> {
  final _searchCtrl = TextEditingController();
  List<RCUser> _filteredUsers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    final up = context.read<UserProvider>();
    await up.loadUsers();
    if (mounted) {
      setState(() {
        _filteredUsers = List.from(up.users);
        _loading = false;
      });
    }
  }

  void _search(String q) async {
    final up = context.read<UserProvider>();
    setState(() {
      _filteredUsers = up.searchLocal(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: '搜索用户...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _search,
          ),
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _filteredUsers.isEmpty
              ? const Center(child: Text('无用户', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (_, i) => UserTile(user: _filteredUsers[i]),
                ),
        ),
      ],
    );
  }

  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }
}

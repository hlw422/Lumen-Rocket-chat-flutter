import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final username = _userCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty||username.isEmpty||email.isEmpty||pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写所有必填项')));
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次密码不一致')));
      return;
    }
    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码至少6位')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(username: username, email: email, pass: pass, name: name);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('注册成功，请登录')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: '显示名称', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: '密码', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(),
                        suffixIcon: IconButton(icon: Icon(_obscure?Icons.visibility_off:Icons.visibility), onPressed: ()=>setState(()=>_obscure=!_obscure)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmCtrl,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: '确认密码', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                    ),
                    if (auth.error != null)
                      Padding(padding: const EdgeInsets.only(top: 12), child: Text(auth.error!, style: const TextStyle(color: Colors.red))),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 44,
                      child: ElevatedButton(
                        onPressed: auth.loading?null:_register,
                        child: auth.loading
                          ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2))
                          : const Text('注册', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override void dispose() {
    _nameCtrl.dispose(); _userCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose(); super.dispose();
  }
}

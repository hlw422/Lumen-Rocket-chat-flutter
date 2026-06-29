import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/chat/chat_home_page.dart';
import 'pages/login_page.dart';
import 'providers/auth_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return MaterialApp(
      title: 'LumenIM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: auth.isLoggedIn ? const ChatHomePage() : const LoginPage(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/chat':
            return MaterialPageRoute(builder: (_) => const ChatHomePage());
          default:
            return MaterialPageRoute(builder: (_) => const LoginPage());
        }
      },
    );
  }
}

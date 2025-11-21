import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'common/app_theme.dart';
import 'screens/wallets_screen.dart';
import 'screens/browser_screen.dart';
import 'screens/wallet_info_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/browser_setting_screen.dart';
import 'screens/master_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure window
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1400, 900),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Hide system buttons
    fullScreen: false, // Start in maximized mode, not fullscreen
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.maximize(); // Maximize window instead of fullscreen
    await windowManager.show();
    await windowManager.focus();
  });
  
  runApp(const BrowserApp());
}

class BrowserApp extends StatelessWidget {
  const BrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const MasterPasswordScreen(),
        '/wallet-setup': (context) => const WalletsScreen(),
        '/browser': (context) => const BrowserPage(),
        '/wallet-info': (context) => const WalletInfoScreen(),
        '/chat': (context) => const ChatScreen(),
        '/settings': (context) => const BrowserSettingScreen(),
      },
    );
  }
}

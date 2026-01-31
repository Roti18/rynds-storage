import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/theme.dart';
import 'screens/file_list_screen.dart';
import 'screens/login_screen.dart';
import 'data/file_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file not found, using defaults");
  }

  // Force login on every app start as requested
  bool isLoggedIn = false;

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
  runApp(FileManagerApp(isLoggedIn: isLoggedIn));
}

class FileManagerApp extends StatefulWidget {
  final bool isLoggedIn;
  
  const FileManagerApp({super.key, required this.isLoggedIn});

  @override
  State<FileManagerApp> createState() => _FileManagerAppState();
}

class _FileManagerAppState extends State<FileManagerApp> with WidgetsBindingObserver {
  late bool _isLoggedIn;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _isLoggedIn = widget.isLoggedIn;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If app goes to background (paused) or is inactive, we lock it
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      debugPrint("App went to background - Locking...");
      _lockApp();
    }
  }

  void _lockApp() {
    // 1. Clear memory token
    ApiFileRepository().clearToken();
    
    // 2. Redirect to Login Screen if we are not already there
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: ApiConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const ScrollBehavior().copyWith(
        overscroll: false,
        physics: const BouncingScrollPhysics(), 
      ),
      home: _isLoggedIn ? const FileListScreen() : const LoginScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/data_refresh_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'widgets/mawid_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const MawidApp());
}

/// Lets code outside the widget tree (specifically AuthGate, below) drive
/// navigation directly — needed to clear a stale navigation stack on
/// logout, since MaterialApp only exposes one Navigator and AuthGate
/// needs a handle to it from within its own build method.
final navigatorKey = GlobalKey<NavigatorState>();

class MawidApp extends StatelessWidget {
  const MawidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataRefreshProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'MAWID',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark, // dark mode only, per brand guideline
        home: const AuthGate(),
      ),
    );
  }
}

/// Decides what the user sees based on auth state:
/// unknown -> splash, unauthenticated -> Login, authenticated -> HomeShell.
///
/// Also handles a subtle bug: logging out from a screen that was pushed
/// on top of HomeShell (e.g. Settings) correctly swaps this widget's
/// content to LoginScreen underneath, but the pushed screen keeps
/// covering it until manually popped — "log out doesn't work until I hit
/// back" was that exact symptom. Fix: when status transitions FROM
/// authenticated TO unauthenticated, clear every pushed route back to
/// the root so the now-visible LoginScreen isn't hidden behind anything.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthStatus? _previousStatus;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_previousStatus == AuthStatus.authenticated &&
        auth.status == AuthStatus.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      });
    }
    _previousStatus = auth.status;

    switch (auth.status) {
      case AuthStatus.unknown:
        return const _SplashPlaceholder();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return const HomeShell();
    }
  }
}

class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: MawidLogoWordmark()),
    );
  }
}
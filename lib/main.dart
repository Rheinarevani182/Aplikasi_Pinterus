import 'package:flutter/material.dart';

import 'models/user_model.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFFFFFF);
    const elevatedSurface = Color(0xFFF5F5F5);
    const foreground = Color(0xFF111111);
    const border = Color(0xFFE5E5E5);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pinterus',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFFE60023),
              brightness: Brightness.light,
              surface: background,
            ).copyWith(
              primary: const Color(0xFFE60023),
              onPrimary: Colors.white,
              secondary: foreground,
              surface: background,
              onSurface: foreground,
              surfaceContainerHighest: elevatedSurface,
              outlineVariant: border,
            ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: foreground,
          surfaceTintColor: Colors.white,
          elevation: 0,
        ),
        bottomAppBarTheme: const BottomAppBarThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: foreground, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: foreground,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: foreground,
            side: const BorderSide(color: border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          showDragHandle: true,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: foreground,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final ApiService _apiService = ApiService();
  UserModel? _user;
  String? _startupError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _isLoading = true;
      _startupError = null;
    });

    try {
      await _apiService.loadStoredToken();
      if (_apiService.token.isNotEmpty) {
        _user = await _apiService.fetchCurrentUser();
      } else {
        _user = null;
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _apiService.clearStoredToken();
        _user = null;
      } else {
        _startupError = error.message;
      }
    } on Exception catch (error) {
      _startupError = error.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onAuthenticated(UserModel user) {
    setState(() {
      _user = user;
      _startupError = null;
    });
  }

  void _onSignedOut() {
    setState(() {
      _user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_startupError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Belum bisa terhubung ke Pinterus',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(_startupError!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _restoreSession,
                  child: const Text('Coba lagi'),
                ),
                TextButton(
                  onPressed: () async {
                    await _apiService.clearStoredToken();
                    if (mounted) {
                      setState(() {
                        _startupError = null;
                        _user = null;
                      });
                    }
                  },
                  child: const Text('Keluar dari akun ini'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = _user;
    if (user == null) {
      return AuthScreen(
        apiService: _apiService,
        onAuthenticated: _onAuthenticated,
      );
    }

    return HomeScreen(
      apiService: _apiService,
      currentUser: user,
      onUserUpdated: _onAuthenticated,
      onSignOut: _onSignedOut,
    );
  }
}

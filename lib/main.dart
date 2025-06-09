// main.dart -> FINAL CORRECTED VERSION
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Supabase/supabase_config.dart';
import 'authentication/register.dart';
import 'authentication/login.dart';
import 'main_screen.dart'; // Make sure this imports the screen with NewHomeScreen
import 'providers/skin_profile_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SkinProfileProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isProcessingGoogleSignUp = false;
  bool _isProcessingGoogleSignIn = false;

  @override
  void initState() {
    super.initState();
    _initializeAuthListener();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _initializeAuthListener() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final event = data.event;
      final session = data.session;
      final user = session?.user;

      if (event == AuthChangeEvent.signedIn && user != null) {
        if (_isProcessingGoogleSignUp) {
          _handleGoogleSignUpEvent(user);
          _isProcessingGoogleSignUp = false;
        } else if (_isProcessingGoogleSignIn) {
          _handleGoogleSignInEvent(user);
          _isProcessingGoogleSignIn = false;
        }
        // This else handles the native email/password login success
        else {
          navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/main', (route) => false);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // This handles any sign-out event, ensuring the user is returned to the login screen.
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }

  void _handleGoogleSignUpEvent(User user) {
    final isNewUser = user.lastSignInAt == null ||
        DateTime.parse(user.lastSignInAt!)
                .difference(DateTime.parse(user.createdAt!))
                .inSeconds <
            15;

    // We always sign out after a Google Sign Up attempt to enforce the clean login flow
    Supabase.instance.client.auth.signOut();
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (isNewUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created successfully! Please log in."),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "This Google account is already registered. Please log in.",
          ),
        ),
      );
    }
    // No navigation is needed here because the signOut() call will trigger
    // the AuthStateChange listener, which will handle navigation to /login.
  }

  void _handleGoogleSignInEvent(User user) {
  final isNewUser = user.lastSignInAt == null ||
      DateTime.parse(user.lastSignInAt!)
              .difference(DateTime.parse(user.createdAt!))
              .inSeconds <
          15;
  if (isNewUser) {
    // ... (failure path is fine)
    Supabase.instance.client.auth.signOut();
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.red,
        content: Text("Account not found. Please sign up first."),
      ),
    );
    // Stay on login page
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (route) => false);
  } else {
    // *** THIS IS THE FIX: EXPLICITLY NAVIGATE ON SUCCESS ***
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/main', (route) => false);
  }
}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SkinSafe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        '/login': (context) => LoginScreen(
              onGoogleSignIn: () => setState(() {
                _isProcessingGoogleSignIn = true;
                _isProcessingGoogleSignUp = false;
              }),
            ),
        '/register': (context) => RegisterScreen(
              onGoogleSignUp: () => setState(() {
                _isProcessingGoogleSignUp = true;
                _isProcessingGoogleSignIn = false;
              }),
            ),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}

// The AuthGate simply shows a loading screen initially and lets the listener handle navigation.
// This prevents build-time navigation errors.
class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // await a short delay to allow the widget to build
    await Future.delayed(Duration.zero);
    if (!mounted) {
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
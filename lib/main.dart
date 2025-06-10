// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Supabase/supabase_config.dart';
import 'authentication/register.dart';
import 'authentication/login.dart';
import 'main_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      final user = session?.user;

      if (event == AuthChangeEvent.signedIn && user != null) {
        
        // --- THIS IS THE FINAL, CRITICAL FIX ---
        // Check if this sign-in was via a social provider (like Google)
        final isSocialSignIn = user.appMetadata['provider'] == 'google';

        if (isSocialSignIn) {
          // If it was a Google sign-in, we must check for identity conflicts.
          final hasEmailIdentity = user.identities?.any((identity) => identity.provider == 'email') ?? false;

          if (hasEmailIdentity) {
            // CONFLICT! This user was created with email/password first.
            // Do not let them proceed with Google. Force them to use their password.
            _showErrorAndSignOut("This email is registered with a password. Please log in using your email and password.");
            return; // Stop processing
          }
        }
        // --- END OF CRITICAL FIX ---
        
        // If we reach here, there are no conflicts.
        // It's either a valid Google user or a valid email/password user.
        _navigateToProfileLoading();
        
      } 
      else if (event == AuthChangeEvent.signedOut) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });

    _handleInitialState();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _showErrorAndSignOut(String message) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text(message),
      ));
    }
    Supabase.instance.client.auth.signOut();
  }
  
  Future<void> _handleInitialState() async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (Supabase.instance.client.auth.currentSession == null) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    } else {
      _navigateToProfileLoading();
    }
  }

  Future<void> _navigateToProfileLoading() async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/loading', (route) => false);
    
    final profileProvider = context.read<SkinProfileProvider>();
    final success = await profileProvider.fetchAndSetUserProfile();
    
    final finalContext = navigatorKey.currentContext;
    if (finalContext == null || !finalContext.mounted) return;

    if (success) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/main', (route) => false);
    } else {
      _showErrorAndSignOut('Could not load profile. Please log in again.');
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
      home: const SplashScreen(),
      routes: {
        '/loading': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
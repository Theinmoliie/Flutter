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

// Use a global key for navigation without a build context.
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
    // This listener now coordinates everything.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      final user = session?.user;

      if (event == AuthChangeEvent.signedIn && user != null) {
        // A sign-in event occurred. Now we check the flags.
        if (_isProcessingGoogleSignUp) {
          _handleGoogleSignUpEvent(user);
        } else if (_isProcessingGoogleSignIn) {
          _handleGoogleSignInEvent(user);
        } else {
          // This is a native email/password login.
          _navigateToProfileLoading();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // Any sign out sends the user to the login screen.
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });

    // Handle the initial state when the app first loads.
    _handleInitialState();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
  
  // This function is called ONLY when the app starts.
  Future<void> _handleInitialState() async {
    // A short delay to allow the navigator to be ready.
    await Future.delayed(const Duration(milliseconds: 10));
    if (Supabase.instance.client.auth.currentSession != null) {
      _navigateToProfileLoading();
    } else {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  // This is the new "Splash Screen" navigation function.
  Future<void> _navigateToProfileLoading() async {
    // Show the splash screen while we fetch the profile.
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/loading', (route) => false);

    final profileProvider = navigatorKey.currentContext!.read<SkinProfileProvider>();
    final success = await profileProvider.fetchAndSetUserProfile();

    if (success) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/main', (route) => false);
    } else {
      // If fetching fails, sign out and show an error.
      await Supabase.instance.client.auth.signOut();
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Could not load profile. Please log in again.'),
        ));
      }
    }
  }
  
  // Your Google event handlers remain to manage the specific UX flows.
  void _handleGoogleSignUpEvent(User user) {
    Supabase.instance.client.auth.signOut();
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    final isNewUser = user.lastSignInAt == null ||
        DateTime.parse(user.lastSignInAt!).difference(DateTime.parse(user.createdAt!)).inSeconds < 3;
        
    if (isNewUser) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account created! Please log in.")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("This Google account is already registered.")));
    }
    // The signOut() triggers the listener, which navigates to /login.
    _isProcessingGoogleSignUp = false; // Reset flag
  }
  
  void _handleGoogleSignInEvent(User user) {
     final isNewUser = user.lastSignInAt == null ||
        DateTime.parse(user.lastSignInAt!).difference(DateTime.parse(user.createdAt!)).inSeconds < 3;

    if (isNewUser) {
      Supabase.instance.client.auth.signOut();
      final context = navigatorKey.currentContext;
      if (context == null) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Account not found. Please sign up first.")));
    } else {
      // On success, navigate to the loading screen to fetch the profile.
      _navigateToProfileLoading();
    }
    _isProcessingGoogleSignIn = false; // Reset flag
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
      // The initial screen is just a loading spinner. The logic in initState will navigate away.
      home: const SplashScreen(),
      routes: {
        '/loading': (context) => const SplashScreen(), // The new loading route
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

// A simple, reusable splash screen widget.
class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
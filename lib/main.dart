// main.dart

import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // May not be needed directly for app_links errors
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart'; // Import app_links
import 'dart:async';

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
      providers: [
        ChangeNotifierProvider(create: (_) => SkinProfileProvider()),
      ],
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
  User? _user;
  // Use AppLinks instance instead of StreamSubscription directly
  final _appLinks = AppLinks();
  bool _initialAuthChecked = false;
  bool _isProcessingGoogleSignUp = false; // <-- ADD THIS FLAG
  bool _isProcessingGoogleSignIn = false; // <-- ADD FOR Login screen flow


  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    _initialAuthChecked = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeepLinkListener(); // Initialize app_links listener
      _initializeAuthListener();
    });
  }

  @override
  void dispose() {
    // app_links doesn't require manual stream cancellation in the same way typically
    super.dispose();
  }

    // main.dart -> _MyAppState class

  void _initializeAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;

      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      final User? user = session?.user;

      print("Auth Event: $event, User: ${user?.email}, SignUpFlag: $_isProcessingGoogleSignUp, SignInFlag: $_isProcessingGoogleSignIn");

      // --- HANDLE SIGNED_IN EVENT ---
      if (event == AuthChangeEvent.signedIn && user != null) {
        // Check if it was from Register Screen Google Button
        if (_isProcessingGoogleSignUp) {
          _isProcessingGoogleSignUp = false; // Reset flag
          setState(() {});

          // Check if user is likely new (created during this flow)
          final createdAt = user.createdAt == null ? null : DateTime.tryParse(user.createdAt!);
          final lastSignInAt = user.lastSignInAt == null ? null : DateTime.tryParse(user.lastSignInAt!);
          bool isLikelyNewUser = true;

          if (createdAt != null && lastSignInAt != null) {
            final difference = lastSignInAt.difference(createdAt);
            if (difference.inSeconds > 60) { isLikelyNewUser = false; }
            print("SignUP Check: New: $isLikelyNewUser");
          } else { print("SignUP Check: Timestamps unreliable."); }

          if (isLikelyNewUser) {
            // New user via Google Sign-Up -> Navigate to Main with success snackbar
            print("Navigating to /main (New Google User from Sign Up)");
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainScreen(showSuccessDialog: true), settings: const RouteSettings(name: '/main')),
              (route) => false,
            );
          } else {
            // Existing user tried Sign Up via Google -> Show snackbar, sign out
            print("Existing Google User attempted Sign Up. Showing snackbar & signing out.");
            final context = navigatorKey.currentContext;
            if (context != null && ScaffoldMessenger.maybeOf(context) != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("This Google account is already registered. Please log in."), duration: Duration(seconds: 4), behavior: SnackBarBehavior.floating),
              );
            }
            Supabase.instance.client.auth.signOut().catchError((e){ print("Error signing out: $e"); });
          }
        }
        // --- ADD CHECK FOR LOGIN SCREEN GOOGLE BUTTON ---
        else if (_isProcessingGoogleSignIn) {
           _isProcessingGoogleSignIn = false; // Reset flag
           setState(() {});

           // Check if user is likely new (created during THIS flow)
           final createdAt = user.createdAt == null ? null : DateTime.tryParse(user.createdAt!);
           final lastSignInAt = user.lastSignInAt == null ? null : DateTime.tryParse(user.lastSignInAt!);
           bool isLikelyNewUser = true; // Assume new unless proven otherwise

           if (createdAt != null && lastSignInAt != null) {
              final difference = lastSignInAt.difference(createdAt);
              // If difference is SMALL, it means they were just created NOW by this login attempt
              if (difference.inSeconds > 60) { isLikelyNewUser = false; } // They existed before
              print("SignIN Check: New: $isLikelyNewUser");
           } else { print("SignIN Check: Timestamps unreliable."); }

           if (isLikelyNewUser) {
              // User was JUST CREATED by this login attempt -> NOT registered before
              print("Google User was not registered. Showing snackbar & signing out.");
              final context = navigatorKey.currentContext;
              if (context != null && ScaffoldMessenger.maybeOf(context) != null) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Account not registered. Please sign up."), duration: Duration(seconds: 4), behavior: SnackBarBehavior.floating),
                 );
              }
               // Sign them out because they shouldn't have been created via Login
              Supabase.instance.client.auth.signOut().catchError((e){ print("Error signing out: $e"); });
           } else {
              // Existing user logged in via Google -> Navigate to Main
              print("Navigating to /main (Existing Google User from Sign In)");
              // Ensure user state is updated before navigating if MainScreen needs it immediately
              setState(() { _user = user; });
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/main', (route) => false);
           }
        }
        // --- END CHECK FOR LOGIN SCREEN GOOGLE BUTTON ---
        else {
          // Normal Sign In (Email/Pass) -> Navigate to Main
          print("Navigating to /main (Email/Pass Sign In)");
           setState(() { _user = user; });
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/main', (route) => false);
        }
      }
      // --- HANDLE SIGNED_OUT EVENT ---
      else if (event == AuthChangeEvent.signedOut) {
        print("Navigating to /login due to SIGNED_OUT event");
        // Reset flags
        _isProcessingGoogleSignUp = false;
        _isProcessingGoogleSignIn = false;
        // Update user state
        setState(() { _user = null; });
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
      }
      // --- UPDATE USER STATE FOR OTHER EVENTS ---
      else {
        setState(() { _user = user; });
      }
    });
  }


  // --- Update Deep Link Listener using app_links ---
  Future<void> _initializeDeepLinkListener() async {
    try {
       // 1. (Updated) Listen for links while app is running (this will include the initial link)
      _appLinks.uriLinkStream.listen((Uri uri) { // Just start listening here
        if (mounted) {
          print("Received link stream: $uri");
          _handleDeepLink(uri); // Handle initial and subsequent links
        }
      }, onError: (err) {
         if (mounted) {
           print('app_links error: $err');
           // Use ScaffoldMessenger safely with the navigatorKey's context
           final context = navigatorKey.currentContext;
           if (context != null && ScaffoldMessenger.maybeOf(context) != null) {
               ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error processing link: $err')),
               );
           } else {
              print("Could not show Snackbar for app_links error - no context/scaffold.");
           }
         }
      });

    } catch (e) {
       // Catch potential errors during stream setup, although less common
       print('app_links stream setup error: $e');
    }
  }


  // --- Deep Link Handler ---
void _handleDeepLink(Uri uri) {
  print("Handling deep link: $uri");
  // --- UPDATE SCHEME CHECK ---
  if (uri.scheme == 'io.supabase.flutter') { // Check for the new scheme
    // Check host for SIGNUP
    // IMPORTANT: Verify if your signup callback ALSO uses this new scheme now.
    // If signup still uses 'io.supabase.flutterquickstart', you'll need separate 'if' checks for schemes.
    // Assuming signup also uses 'io.supabase.flutter' for consistency:
    if (uri.host == 'signup-callback') {
      print("Signup callback detected (using io.supabase.flutter scheme). Setting signup flag.");
      setState(() { _isProcessingGoogleSignUp = true; });
    }
    // Check host for LOGIN (this definitely uses the new scheme/host)
    else if (uri.host == 'login-callback') {
      print("Login callback detected. Setting signin flag.");
      setState(() { _isProcessingGoogleSignIn = true; });
    }
  }
  // --- Example if schemes DIFFER ---
  /* else if (uri.scheme == 'io.supabase.flutterquickstart' && uri.host == 'signup-callback') {
     print("Signup callback detected (using old scheme). Setting signup flag.");
     setState(() { _isProcessingGoogleSignUp = true; });
  } */
  // Add other handlers if needed
}


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: !_initialAuthChecked
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _user == null ? LoginScreen() : MainScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/main': (context) => MainScreen(),
      },
    );
  }
}
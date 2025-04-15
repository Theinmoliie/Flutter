// login.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register.dart';
import '../main_screen.dart'; // Or your home screen

class LoginScreen extends StatefulWidget {

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

 

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
     if (!mounted) return;
    setState(() => _isLoading = true);
     try {
       await _supabase.auth.signInWithPassword(
         email: _emailController.text.trim(),
         password: _passwordController.text.trim(),
       );
       // No navigation here - onAuthStateChange listener handles it
     } on AuthException catch (e) {
        if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Login Failed: ${e.message}")),
         );
       }
     } catch (e) {
        if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("An unexpected error occurred: $e")),
         );
       }
     } finally {
       if (mounted) {
         setState(() => _isLoading = false);
       }
     }
  }

  Future<void> _handleGoogleSignIn() async {
    // This button on the LOGIN screen should use a LOGIN callback if needed
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
       await Supabase.instance.client.auth.signInWithOAuth(
         OAuthProvider.google,
         // Use a different callback for login if you want to distinguish flows
         // redirectTo: 'io.supabase.flutterquickstart://login-callback/',
         // Or reuse the signup-callback if the destination is always LoginScreen initially
         redirectTo: 'io.supabase.flutter://login-callback', // Or your preferred callback
       );
       // No navigation here
    } on AuthException catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Google Sign In Failed: ${e.message}")),
         );
      }
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("An unexpected error occurred: $e")),
         );
      }
    } finally {
       if (mounted) {
         setState(() => _isLoading = false);
       }
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
       backgroundColor: colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 const SizedBox(height: 60.0),
                 Image.asset('assets/skinsafeLogo.png', height: 80),
                 const SizedBox(height: 30),
                 Text(
                   "Log In",
                   textAlign: TextAlign.center,
                   style: textTheme.headlineMedium?.copyWith(
                     fontWeight: FontWeight.bold,
                     color: colorScheme.onBackground,
                   ),
                 ),
                 const SizedBox(height: 30),
                 // --- Email ---
                 TextFormField(
                   controller: _emailController,
                   decoration: InputDecoration( /* ... Input Decoration ... */
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                      filled: true,
                      fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: colorScheme.primary, width: 1.5)),
                   ),
                   keyboardType: TextInputType.emailAddress,
                 ),
                 const SizedBox(height: 15),
                 // --- Password ---
                 TextFormField(
                   controller: _passwordController,
                    decoration: InputDecoration( /* ... Input Decoration ... */
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                      filled: true,
                      fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: colorScheme.primary, width: 1.5)),
                   ),
                   obscureText: true,
                 ),
                 const SizedBox(height: 30),
                 // --- Login Button ---
                 ElevatedButton(
                   onPressed: _isLoading ? null : _handleLogin,
                   style: ElevatedButton.styleFrom( /* ... Button Style ... */
                     backgroundColor: colorScheme.primary,
                     foregroundColor: colorScheme.onPrimary,
                     padding: const EdgeInsets.symmetric(vertical: 16),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                     elevation: 2,
                   ),
                   child: Text(_isLoading ? "Logging In..." : "Log In"),
                 ),
                 const SizedBox(height: 25),
                 // --- Divider ---
                 Row( /* ... Divider ... */
                    children: [
                      Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Text('Or log in with', style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600))),
                      Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                    ]
                 ),
                 const SizedBox(height: 25),
                  // --- Google Sign In Button ---
                 OutlinedButton.icon(
                    icon: Image.asset('assets/google_logo.png', height: 20.0),
                    label: const Text("Log In with Google"),
                    onPressed: _isLoading ? null : _handleGoogleSignIn, // Add this handler
                    style: OutlinedButton.styleFrom( /* ... Button Style ... */
                      foregroundColor: colorScheme.onBackground,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                  ),
                  const SizedBox(height: 30),
                 // --- Register Link ---
                 Row( /* ... Register Link ... */
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Text("Don't have an account?", style: textTheme.bodyMedium),
                     TextButton(
                       onPressed: () {
                         Navigator.pushReplacement(
                           context,
                           MaterialPageRoute(builder: (context) => RegisterScreen()),
                         );
                       },
                       style: TextButton.styleFrom(foregroundColor: colorScheme.primary, padding: const EdgeInsets.symmetric(horizontal: 4.0)),
                       child: const Text("Sign Up"),
                     ),
                   ]
                 ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
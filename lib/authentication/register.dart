// lib/authentication/register.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  // No longer needs a callback.
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  // This function is for email/password and is correct.
  Future<void> _handleSignUp() async {
    setState(() => _isLoading = true);
    final currentContext = context;

    try {
      await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // This is crucial to force the user to confirm their email.
      await _supabase.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
            content: Text("Account created! Please check your email for a confirmation link."),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pushReplacementNamed(currentContext, '/login');
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text("Sign Up Failed: ${e.message}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text("An unexpected error occurred: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Unified Google handler.
  Future<void> _handleGoogleAuth() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback',
      );
    } on AuthException catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Google Sign Up Failed: ${e.message}")),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("An unexpected error occurred: $e")),
      );
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
                const SizedBox(height: 50.0),
                Image.asset('assets/skinsafeLogo.png', height: 80),
                const SizedBox(height: 30),
                Text("Sign Up", textAlign: TextAlign.center, style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onBackground)),
                const SizedBox(height: 30),
                TextFormField(controller: _emailController, decoration: InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)), filled: true, fillColor: colorScheme.surfaceVariant.withOpacity(0.3), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: colorScheme.primary, width: 1.5))), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 15),
                TextFormField(controller: _passwordController, decoration: InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)), filled: true, fillColor: colorScheme.surfaceVariant.withOpacity(0.3), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: colorScheme.primary, width: 1.5))), obscureText: true),
                const SizedBox(height: 30),
                ElevatedButton(onPressed: _isLoading ? null : _handleSignUp, style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), elevation: 2), child: Text(_isLoading ? "Creating Account..." : "Sign Up")),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0), child: Text('Or continue with', style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600))),
                    Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 25),
                OutlinedButton.icon(
                  icon: Image.asset('assets/google_logo.png', height: 20.0),
                  label: const Text("Continue with Google"),
                  onPressed: _isLoading ? null : _handleGoogleAuth,
                  style: OutlinedButton.styleFrom(foregroundColor: colorScheme.onBackground, padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: Colors.grey.shade400), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already have an account?", style: textTheme.bodyMedium),
                    TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/login'), style: TextButton.styleFrom(foregroundColor: colorScheme.primary, padding: const EdgeInsets.symmetric(horizontal: 4.0)), child: const Text("Log In")),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
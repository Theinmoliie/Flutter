// lib/authentication/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        // This must match the deep link you will set up next
        redirectTo: 'io.supabase.flutter://reset-password', 
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Password reset link sent! Please check your email.'),
          ),
        );
        Navigator.of(context).pop(); // Go back to login screen
      }
    } on AuthException catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error: ${e.message}'),
          ),
        );
      }
    } catch (e) {
      // Handle other potential errors
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your account email and we will send a link to reset your password.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendResetLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(_isLoading ? 'Sending...' : 'Send Reset Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
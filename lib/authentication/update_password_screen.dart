// lib/authentication/update_password_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({Key? key}) : super(key: key);

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Password updated successfully! Please log in.'),
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } on AuthException catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(e.message)),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Password'),
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
                'Please enter your new password below.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
                // --- START: NEW VALIDATION LOGIC ---
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password cannot be empty';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  // RegEx to check for at least one letter and one digit
                  final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
                  final hasDigit = RegExp(r'[0-9]').hasMatch(value);
                  
                  if (!hasLetter || !hasDigit) {
                    return 'Password must contain both letters and digits';
                  }
                  
                  return null; // Return null if the password is valid
                },
                // --- END: NEW VALIDATION LOGIC ---
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(_isLoading ? 'Saving...' : 'Update Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
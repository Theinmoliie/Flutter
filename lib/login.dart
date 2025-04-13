import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register.dart'; // Ensure this points to your RegisterScreen
import 'home.dart'; // Replace with your actual home screen

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Login successful, navigate to home screen
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => HomeScreen()),
        // );

         Navigator.pushReplacementNamed(context, '/main');

      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Failed: ${e.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An unexpected error occurred: $e")),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: "io.supabase.flutter://login-callback",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign In Successful!")),
      );

      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => HomeScreen()),
      // );

       Navigator.pushReplacementNamed(context, '/main');
       
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign In Failed: ${e.message}")),
      );
    }
  }

//  Future<void> _resetPassword() async {
  //   String email = _emailController.text.trim();
  //   if (email.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Please enter your email to reset password")),
  //     );
  //     return;
  //   }

  //   try {
  //     await _supabase.auth.resetPasswordForEmail(
  //       email,
  //       redirectTo: "io.supabase.flutter://reset-password",
  //     );
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Password reset email sent! Check your inbox.")),
  //     );
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Error: $e")),
  //     );
  //   }
  // }


 @override
  Widget build(BuildContext context) {
    // Use theme colors
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background, // Use theme background
      body: SafeArea( // Ensure content is not under status bars/notches
        child: SingleChildScrollView( // Prevent overflow on smaller screens
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons stretch
              children: [
                 const SizedBox(height: 50.0),
                // Logo - Consider adjusting size/padding based on your logo
                Image.asset('assets/skinsafeLogo.png', height: 80), // Adjusted height
                const SizedBox(height: 30),

                // Title
                Text(
                  "Log In", // Title
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 30),

                // Email Field
                TextFormField(
                  controller: _emailController, // Make sure you have _emailController defined in your LoginScreen state
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.3), // Subtle fill
                    enabledBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12.0),
                       borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12.0),
                       borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),

                // Password Field
                TextFormField(
                  controller: _passwordController, // Make sure you have _passwordController defined in your LoginScreen state
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                     border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                     enabledBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12.0),
                       borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12.0),
                       borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                    ),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 30),

                // Log In Button (Corrected)
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin, // Ensure _isLoading and _handleLogin exist in your LoginScreen state
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary, // This will now apply
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 2, // Subtle shadow
                  ),
                  child: Text(
                      _isLoading ? "Loging in..." : "Log In"
                      // Removed the explicit style property
                  ),
                ),
                const SizedBox(height: 25),

                // Divider "Or log in with"
                Row(
                  children: [
                    Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'Or log in with',
                        style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ),
                    Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 25),

                // Google Log In Button (Outlined style)
                OutlinedButton.icon(
                  icon: Image.asset( // Use Image.asset for the Google logo
                      'assets/google_logo.png', // Replace with your actual Google logo asset path
                      height: 20.0, // Adjust size as needed
                  ),
                  label: const Text("Log In with Google"),
                  onPressed: _isLoading ? null : _handleGoogleSignIn, // Ensure _handleGoogleSignIn exists in your LoginScreen state
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onBackground, // Text color
                    padding: const EdgeInsets.symmetric(vertical: 14), // Slightly less padding than main button
                    side: BorderSide(color: Colors.grey.shade400), // Border color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Sign Up Link
                Row( // Changed this Row for better structure
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?", style: textTheme.bodyMedium),
                    TextButton(
                      onPressed: () {
                        // Use pushReplacement to avoid stacking login/registration screens
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => RegisterScreen()), // Make sure RegisterScreen is imported
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary, // Use theme color
                        padding: const EdgeInsets.symmetric(horizontal: 4.0), // Minimal padding
                      ),
                      child: const Text("Sign up here"),
                    ),
                  ],
                ),
                 // Add some space at the bottom if needed when keyboard is not visible
                 const SizedBox(height: 20.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart'; // Make sure this is the correct import for your login screen
// import 'home.dart'; // Import your actual home screen if needed for navigation check

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  // Optional: Add a form key for validation later if needed
  // final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    // Optional: Add form validation
    // if (!_formKey.currentState!.validate()) {
    //   return;
    // }

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Account created! Please log in to continue.")),
        );
        // Navigate to a screen telling the user to check their email,
        // or potentially the login screen. Avoid navigating directly to home
        // before email verification is confirmed by Supabase session change.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }

    } on AuthException catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sign Up Failed: ${e.message}")),
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
    setState(() => _isLoading = true); // Indicate loading for Google button too
    try {
      // Note: Google Sign-In typically handles navigation via deep linking callbacks
      // defined in your Supabase setup and native configurations (Android/iOS).
      // Automatic navigation after this call might not be reliable or immediate.
      // Listen to auth state changes for navigation instead.
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        // Ensure this matches your Supabase > Auth > URL Configuration > Redirect URLs
        // AND your native platform setup (AndroidManifest.xml / Info.plist)
        redirectTo: 'io.supabase.flutterquickstart://login-callback/', // Replace with your actual scheme if different
      );

      // Showing success immediately might be premature as the callback handles the final login.
      // It's better to rely on the auth state listener in your main app/splash screen.
      // If you MUST show something:
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text("Redirecting to Google Sign In...")),
      //  );
      // }

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
                  "Sign Up", // Title
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 30),

                // Email Field
                TextFormField(
                  controller: _emailController,
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
                  // Optional: Add validator
                  // validator: (value) { ... }
                ),
                const SizedBox(height: 15),

                // Password Field
                TextFormField(
                  controller: _passwordController,
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
                   // Optional: Add validator
                  // validator: (value) { ... }
                ),
                const SizedBox(height: 30),

                // Sign Up Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 2, // Subtle shadow
                  ),
                  child: Text(_isLoading ? "Creating Account..." : "Sign Up"),
                ),
                const SizedBox(height: 25),

                // Divider "Or sign up with"
                Row(
                  children: [
                    Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'Or sign up with',
                        style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ),
                    Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 25),

                // Google Sign Up Button (Outlined style)
                OutlinedButton.icon(
                  icon: Image.asset( // Use Image.asset for the Google logo
                      'assets/google_logo.png', // Replace with your actual Google logo asset path
                      height: 20.0, // Adjust size as needed
                  ),
                  label: const Text("Sign Up with Google"),
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
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

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already have an account?", style: textTheme.bodyMedium),
                    TextButton(
                      onPressed: () {
                        // Use pushReplacement to avoid stacking registration screens
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => LoginScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary, // Use theme color
                        padding: const EdgeInsets.symmetric(horizontal: 4.0), // Minimal padding
                      ),
                      child: const Text("Log In"),
                    ),
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
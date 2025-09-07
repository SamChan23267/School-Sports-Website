// lib/login_page.dart

import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService.instance;
  bool _isLoading = false;

  /// --- UPDATED SIGN-IN LOGIC ---
  void _signIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Call the new method that uses a popup.
    final userCredential = await _authService.signInWithGoogle();

    // This check is important to prevent errors if the user navigates away
    // while the async sign-in operation is in progress.
    if (!mounted) return;

    // After the popup closes, check if we got a valid user.
    if (userCredential?.user != null) {
      // If sign-in was successful, close the login page.
      // The UserProvider listening to the auth stream will handle updating the UI.
      Navigator.of(context).pop();
    } else {
      // This handles cases where the user closes the popup or an error occurs.
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign-in was cancelled.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sign In',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _signIn,
                      // You might need to add the google_logo.png to an assets folder
                      // and declare it in your pubspec.yaml
                      icon: Image.asset('assets/google_logo.png', height: 24.0),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 24),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}


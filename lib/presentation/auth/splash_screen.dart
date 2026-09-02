import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<User?>? _authSubscription;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _listenToAuthentication();
  }

  void _listenToAuthentication() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Firebase Auth error: $error');
        debugPrintStack(stackTrace: stackTrace);
        _navigateTo(AppRoutes.login);
      },
    );
  }

  void _handleAuthState(User? user) {
    if (!mounted || _hasNavigated) {
      return;
    }

    final String route = user == null ? AppRoutes.login : AppRoutes.home;

    debugPrint(
      'Firebase Auth state: ${user == null ? 'signed out' : 'signed in'}',
    );

    _navigateTo(route);
  }

  void _navigateTo(String route) {
    if (!mounted || _hasNavigated) {
      return;
    }

    _hasNavigated = true;
    debugPrint('Splash navigation: $route');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed(route);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
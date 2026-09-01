import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Text('Login Screen', style: AppTextStyles.headingMedium),
      ),
    );
  }
}

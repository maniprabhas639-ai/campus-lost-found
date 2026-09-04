import 'package:flutter/material.dart';

import '../../data/models/lost_found_item.dart';
import '../../presentation/auth/forgot_password_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/signup_screen.dart';
import '../../presentation/auth/splash_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/item/edit_item_screen.dart';
import '../../presentation/item/item_details_screen.dart';
import '../../presentation/my_posts/my_posts_screen.dart';
import '../../presentation/profile/profile_screen.dart';
import '../../presentation/report/report_item_screen.dart';
import '../../presentation/messaging/chat_screen.dart';
import '../../presentation/messaging/conversations_screen.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SplashScreen(),
        );

      case AppRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );

      case AppRoutes.signup:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SignupScreen(),
        );

      case AppRoutes.forgotPassword:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ForgotPasswordScreen(),
        );

      case AppRoutes.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );

      case AppRoutes.reportItem:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ReportItemScreen(),
        );

      case AppRoutes.itemDetails:
        final LostFoundItem item = settings.arguments! as LostFoundItem;

        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ItemDetailsScreen(item: item),
        );

      case AppRoutes.chat:
        final LostFoundItem item = settings.arguments! as LostFoundItem;

        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ChatScreen(item: item),
        );

      case AppRoutes.conversations:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ConversationsScreen(),
        );

      case AppRoutes.editItem:
        final LostFoundItem item = settings.arguments! as LostFoundItem;

        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => EditItemScreen(item: item),
        );

      case AppRoutes.myPosts:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MyPostsScreen(),
        );

      case AppRoutes.profile:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ProfileScreen(),
        );

      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}

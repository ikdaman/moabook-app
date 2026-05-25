import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screen/login_screen.dart';
import '../../features/auth/screen/signup_screen.dart';
import '../../features/splash/screen/splash_screen.dart';
import 'routes.dart';

final appRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(
      path: Routes.splash,
      builder: (context, _) => const SplashScreen(),
    ),
    GoRoute(
      path: Routes.login,
      builder: (context, _) => const LoginScreen(),
    ),
    GoRoute(
      path: Routes.signup,
      builder: (context, state) {
        final extra = state.extra as Map<String, String>? ?? {};
        return SignupScreen(
          socialToken: extra['socialToken'] ?? '',
          provider:    extra['provider']    ?? '',
          providerId:  extra['providerId']  ?? '',
        );
      },
    ),
    GoRoute(
      path: Routes.addBook,
      builder: (context, _) =>
          const Scaffold(body: Center(child: Text('AddBook'))),
    ),
    GoRoute(
      path: Routes.manualBookInput,
      builder: (context, _) =>
          const Scaffold(body: Center(child: Text('ManualBookInput'))),
    ),
    GoRoute(
      path: Routes.barcode,
      builder: (context, _) =>
          const Scaffold(body: Center(child: Text('Barcode'))),
    ),
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (context, _) =>
              const Scaffold(body: Center(child: Text('Home'))),
        ),
        GoRoute(
          path: Routes.searchBook,
          builder: (context, _) =>
              const Scaffold(body: Center(child: Text('SearchBook'))),
        ),
        GoRoute(
          path: Routes.history,
          builder: (context, _) =>
              const Scaffold(body: Center(child: Text('History'))),
        ),
        GoRoute(
          path: Routes.setting,
          builder: (context, _) =>
              const Scaffold(body: Center(child: Text('Setting'))),
        ),
        GoRoute(
          path: Routes.searchMyBook,
          builder: (context, _) =>
              const Scaffold(body: Center(child: Text('SearchMyBook'))),
        ),
        GoRoute(
          path: '/main/book-info/:mybookId',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['mybookId']!);
            return Scaffold(body: Center(child: Text('BookInfo $id')));
          },
        ),
      ],
    ),
  ],
);

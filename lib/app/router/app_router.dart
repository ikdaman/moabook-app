import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';

final appRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(
      path: Routes.splash,
      builder: (context, _) => const Scaffold(body: Center(child: Text('Splash'))),
    ),
    GoRoute(
      path: Routes.login,
      builder: (context, _) => const Scaffold(body: Center(child: Text('Login'))),
    ),
    GoRoute(
      path: Routes.signup,
      builder: (context, _) => const Scaffold(body: Center(child: Text('Signup'))),
    ),
    GoRoute(
      path: Routes.addBook,
      builder: (context, _) => const Scaffold(body: Center(child: Text('AddBook'))),
    ),
    GoRoute(
      path: Routes.manualBookInput,
      builder: (context, _) =>
          const Scaffold(body: Center(child: Text('ManualBookInput'))),
    ),
    GoRoute(
      path: Routes.barcode,
      builder: (context, _) => const Scaffold(body: Center(child: Text('Barcode'))),
    ),
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (context, _) => const Scaffold(body: Center(child: Text('Home'))),
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
          builder: (_, state) {
            final id = int.parse(state.pathParameters['mybookId']!);
            return Scaffold(body: Center(child: Text('BookInfo $id')));
          },
        ),
      ],
    ),
  ],
);

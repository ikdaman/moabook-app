import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screen/login_screen.dart';
import '../../features/auth/screen/signup_screen.dart';
import '../../features/book_search/screen/add_book_screen.dart';
import '../../features/book_search/screen/manual_book_input_screen.dart';
import '../../features/book_search/screen/search_book_screen.dart';
import '../../features/home/screen/home_screen.dart';
import '../../features/splash/screen/splash_screen.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
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
      builder: (context, _) => const AddBookScreen(),
    ),
    GoRoute(
      path: Routes.manualBookInput,
      builder: (context, _) => const ManualBookInputScreen(),
    ),
    GoRoute(
      path: Routes.barcode,
      builder: (context, _) =>
          const Scaffold(body: Center(child: Text('Barcode - Phase 4'))),
    ),
    // ── Main shell with BottomNavBar ──────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => Scaffold(
        body: child,
        bottomNavigationBar: const BottomNavBar(),
      ),
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (context, _) => const HomeScreen(),
        ),
        GoRoute(
          path: Routes.searchBook,
          builder: (context, _) => const SearchBookScreen(),
        ),
        GoRoute(
          path: Routes.history,
          builder: (context, _) =>
              const Scaffold(body: Center(child: Text('History - Phase 3d'))),
        ),
        GoRoute(
          path: Routes.setting,
          builder: (context, _) =>
              const Scaffold(body: Center(child: Text('Setting - Phase 3d'))),
        ),
        GoRoute(
          path: Routes.searchMyBook,
          builder: (context, _) =>
              const Scaffold(body: Center(child: Text('SearchMyBook - Phase 3c'))),
        ),
        GoRoute(
          path: '/main/book-info/:mybookId',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['mybookId']!);
            return Scaffold(
                body: Center(child: Text('BookInfo $id - Phase 3c')));
          },
        ),
      ],
    ),
  ],
);

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screen/login_screen.dart';
import '../../features/onboarding/screen/onboarding_screen.dart';
import '../../features/auth/screen/signup_screen.dart';
import '../../features/book_info/screen/book_info_screen.dart';
import '../../features/capture/screen/book_capture_screen.dart';
import '../../features/book_search/screen/add_book_screen.dart';
import '../../features/book_search/screen/manual_book_input_screen.dart';
import '../../features/book_search/screen/search_book_screen.dart';
import '../../features/history/screen/history_screen.dart';
import '../../features/home/screen/home_screen.dart';
import '../../features/my_book_search/screen/my_book_search_screen.dart';
import '../../features/settings/screen/settings_screen.dart';
import '../../features/splash/screen/splash_screen.dart';
import '../../core/env/env.dart';
import '../../features/reading/screen/reading_library_screen.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import 'routes.dart';

final appRouter = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(path: Routes.splash, builder: (context, _) => const SplashScreen()),
    GoRoute(path: Routes.login, builder: (context, _) => const LoginScreen()),
    GoRoute(
      path: Routes.onboarding,
      builder: (context, _) => const OnboardingScreen(),
    ),
    GoRoute(
      path: Routes.signup,
      builder: (context, state) {
        final extra = state.extra as Map<String, String>? ?? {};
        return SignupScreen(
          socialToken: extra['socialToken'] ?? '',
          provider: extra['provider'] ?? '',
          providerId: extra['providerId'] ?? '',
        );
      },
    ),
    GoRoute(
      path: Routes.addBook,
      redirect: (_, _) => Env.useNewReadingUi ? Routes.searchBook : null,
      builder: (context, _) => const AddBookScreen(),
    ),
    GoRoute(
      path: Routes.manualBookInput,
      redirect: (_, _) => Env.useNewReadingUi ? Routes.searchBook : null,
      builder: (context, _) => const ManualBookInputScreen(),
    ),
    GoRoute(
      path: Routes.capture,
      builder: (context, state) => BookCaptureScreen(
        selectionOnly:
            Env.useNewReadingUi ||
            state.uri.queryParameters['selection'] == 'true',
      ),
    ),
    // ── Main shell with BottomNavBar ──────────────────────────────────
    ShellRoute(
      builder: (context, state, child) {
        final path = state.uri.path;
        // Settings is a standalone screen in both reading UI modes.
        if (path == Routes.setting) return child;
        if (Env.useNewReadingUi &&
            ([Routes.home, Routes.searchBook, Routes.history].contains(path) ||
                path.startsWith('/main/book-info/'))) {
          return child;
        }
        return Scaffold(body: child, bottomNavigationBar: const BottomNavBar());
      },
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (context, _) => Env.useNewReadingUi
              ? const ReadingLibraryScreen()
              : const HomeScreen(),
        ),
        GoRoute(
          path: Routes.searchBook,
          builder: (context, _) => Env.useNewReadingUi
              ? const ReadingLibraryScreen(initialScreen: 'search')
              : const SearchBookScreen(),
        ),
        GoRoute(
          path: Routes.history,
          builder: (context, _) => Env.useNewReadingUi
              ? const ReadingLibraryScreen(initialScreen: 'collection')
              : const HistoryScreen(),
        ),
        GoRoute(
          path: Routes.setting,
          builder: (context, _) => const SettingsScreen(),
        ),
        GoRoute(
          path: Routes.searchMyBook,
          builder: (context, _) => const MyBookSearchScreen(),
        ),
        GoRoute(
          path: '/main/book-info/:mybookId',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['mybookId']!);
            return Env.useNewReadingUi
                ? ReadingLibraryScreen(
                    initialScreen: 'card-front',
                    bookId: id.toString(),
                  )
                : BookInfoScreen(mybookId: id);
          },
        ),
      ],
    ),
  ],
);

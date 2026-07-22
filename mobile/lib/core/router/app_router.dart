import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/statistics/presentation/statistics_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../shared/widgets/app_shell.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (authState.status == AuthStatus.checking) return null;

      if (authState.status == AuthStatus.unauthenticated && !loggingIn) return '/login';
      if (authState.status == AuthStatus.authenticated && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen()),
          GoRoute(path: '/statistics', builder: (context, state) => const StatisticsScreen()),
          GoRoute(path: '/finance', builder: (context, state) => const FinanceScreen()),
        ],
      ),
    ],
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/relationship/persons_list_screen.dart';
import '../screens/relationship/person_detail_screen.dart';
import '../screens/relationship/person_form_screen.dart';
import '../screens/relationship/group_detail_screen.dart';
import '../screens/partner/partner_dashboard_screen.dart';
import '../screens/memory/memories_list_screen.dart';
import '../screens/memory/memory_detail_screen.dart';
import '../screens/memory/memory_form_screen.dart';
import '../screens/expense/expense_form_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/time_categories_screen.dart';
import '../screens/settings/expense_categories_screen.dart';
import '../screens/settings/currency_settings_screen.dart';
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/loading',
    routes: [
      GoRoute(
        path: '/loading',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          // Home = Memories list
          GoRoute(
            path: '/home',
            builder: (_, _) => const MemoriesListScreen(),
          ),
          // Relationships
          GoRoute(
            path: '/people',
            builder: (_, _) => const PersonsListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const PersonFormScreen(),
              ),
              GoRoute(
                path: 'groups/:groupId',
                builder: (_, state) => GroupDetailScreen(
                    groupId: state.pathParameters['groupId']!),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    PersonDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => PersonFormScreen(
                        personId: state.pathParameters['id']),
                  ),
                  GoRoute(
                    path: 'partner',
                    builder: (_, state) => PartnerDashboardScreen(
                        personId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          // Memories
          GoRoute(
            path: '/memories',
            builder: (_, _) => const MemoriesListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const MemoryFormScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    MemoryDetailScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => MemoryFormScreen(
                        memoryId: state.pathParameters['id']),
                  ),
                  // New expense linked to this memory
                  GoRoute(
                    path: 'expenses/new',
                    builder: (_, state) => ExpenseFormScreen(
                        memoryId: state.pathParameters['id']),
                  ),
                  // Edit an expense belonging to this memory
                  GoRoute(
                    path: 'expenses/:txId/edit',
                    builder: (_, state) => ExpenseFormScreen(
                        transactionId: state.pathParameters['txId']),
                  ),
                ],
              ),
            ],
          ),
          // Settings
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'categories',
                builder: (_, _) => const TimeCategoriesScreen(),
              ),
              GoRoute(
                path: 'expense-categories',
                builder: (_, _) => const ExpenseCategoriesScreen(),
              ),
              GoRoute(
                path: 'currencies',
                builder: (_, _) => const CurrencySettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});


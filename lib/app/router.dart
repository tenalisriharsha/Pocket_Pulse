import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/transactions/presentation/pages/transactions_page.dart';
import '../features/budgets/presentation/pages/budgets_page.dart';
import '../features/recurring/presentation/pages/recurring_page.dart';
import '../features/reports/presentation/pages/reports_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../shared/animations/page_transitions.dart';
import '../shared/widgets/animated_nav_destination.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (_, state) => slideFadePage(
              key: state.pageKey,
              child: const DashboardPage(),
            ),
          ),
          GoRoute(
            path: '/transactions',
            pageBuilder: (_, state) => slideFadePage(
              key: state.pageKey,
              child: const TransactionsPage(),
            ),
          ),
          GoRoute(
            path: '/budgets',
            pageBuilder: (_, state) => slideFadePage(
              key: state.pageKey,
              child: const BudgetsPage(),
            ),
          ),
          GoRoute(
            path: '/recurring',
            pageBuilder: (_, state) => slideFadePage(
              key: state.pageKey,
              child: const RecurringPage(),
            ),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (_, state) => slideFadePage(
              key: state.pageKey,
              child: const ReportsPage(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (_, state) => slideFadePage(
              key: state.pageKey,
              child: const SettingsPage(),
            ),
          ),
        ],
      ),
    ],
  );
}

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    ('/dashboard',   Icons.dashboard_outlined,      Icons.dashboard_rounded,      'Home'),
    ('/transactions',Icons.receipt_long_outlined,   Icons.receipt_long_rounded,   'Payments'),
    ('/budgets',     Icons.pie_chart_outline,       Icons.pie_chart_rounded,      'Budgets'),
    ('/recurring',   Icons.autorenew_outlined,      Icons.autorenew_rounded,      'Recurring'),
    ('/reports',     Icons.insights_outlined,       Icons.insights_rounded,       'Reports'),
    ('/settings',    Icons.settings_outlined,       Icons.settings_rounded,       'Settings'),
  ];

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _locationToIndex(String location) {
    for (var i = 0; i < MainShell._tabs.length; i++) {
      if (location.startsWith(MainShell._tabs[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < MainShell._tabs.length; i++)
                  Expanded(
                    child: AnimatedNavDestination(
                      isSelected: i == currentIndex,
                      icon: MainShell._tabs[i].$2,
                      activeIcon: MainShell._tabs[i].$3,
                      label: MainShell._tabs[i].$4,
                      onTap: () => context.go(MainShell._tabs[i].$1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

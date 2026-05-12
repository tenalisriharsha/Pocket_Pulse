import 'package:flutter/material.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class PocketPulseApp extends StatelessWidget {
  const PocketPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PocketPulse',
      theme: AppTheme.light(),
      routerConfig: createRouter(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Global error widget fallback
        ErrorWidget.builder = (details) {
          return Material(
            child: Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exception.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        };
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:customer_sync/core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Wait for animation + artificial delay
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Go to /login which handles auto-redirect to /customer if already logged in.
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBGStart : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Animation
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/splash_logo.png'),
                  fit: BoxFit.contain,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ).animate()
             .fadeIn(duration: 800.ms, curve: Curves.easeOut)
             .scale(duration: 800.ms, begin: const Offset(0.5, 0.5), end: const Offset(1, 1), curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            // Text Animation
            Text(
              "BarberBook",
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: 1.2,
              ),
            ).animate()
             .fadeIn(delay: 500.ms, duration: 800.ms)
             .slideY(begin: 0.3, end: 0, duration: 800.ms, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}

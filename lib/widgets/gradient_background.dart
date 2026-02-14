import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer_sync/core/theme/app_theme.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const GradientBackground({
    super.key,
    required this.child,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppTheme.darkBGStart,
                    AppTheme.darkBGMiddle,
                    AppTheme.darkBGEnd,
                  ]
                : [
                    AppTheme.lightBGStart,
                    AppTheme.lightBGMiddle,
                    AppTheme.lightBGEnd,
                  ],
          ),
        ),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

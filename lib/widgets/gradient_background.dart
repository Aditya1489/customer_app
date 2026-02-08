import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:customer_sync/core/theme/app_theme.dart';

class GradientBackground extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const GradientBackground({
    super.key,
    required this.child,
    this.isDark = true,
  });

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: widget.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: widget.isDark ? AppTheme.darkBGStart : AppTheme.lightBGStart,
        body: Stack(
          children: [
            if (widget.isDark)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Stack(
                    children: [
                      // Bottom base color
                      Container(color: AppTheme.darkBGStart),
                      // Animated Mesh Blob 1
                      Positioned(
                        top: -100 + 100 * sin(_controller.value * 2 * pi),
                        right: -100 + 50 * cos(_controller.value * 2 * pi),
                        child: _MeshBlob(color: AppTheme.darkBGEnd.withOpacity(0.5), size: 500),
                      ),
                      // Animated Mesh Blob 2
                      Positioned(
                        bottom: -150 + 80 * cos(_controller.value * 2 * pi),
                        left: -150 + 120 * sin(_controller.value * 2 * pi),
                        child: _MeshBlob(color: const Color(0xFF0F172A).withOpacity(0.4), size: 600), // Deep blue blob
                      ),
                    ],
                  );
                },
              ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _MeshBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _MeshBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

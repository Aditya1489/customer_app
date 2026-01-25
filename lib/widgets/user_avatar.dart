import 'package:flutter/material.dart';
import 'dart:io';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/core/theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final User user;
  final double radius;
  final bool isDark;

  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 50,
    required this.isDark,
  });

  String get initials {
    final cleanName = user.name.trim();
    if (cleanName.isEmpty) return "C";
    
    List<String> parts = cleanName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (user.profilePhoto != null && user.profilePhoto!.isNotEmpty) {
      final isNetwork = user.profilePhoto!.startsWith('http');
      return CircleAvatar(
        radius: radius,
        backgroundImage: isNetwork 
          ? NetworkImage(user.profilePhoto!) as ImageProvider
          : FileImage(File(user.profilePhoto!)),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

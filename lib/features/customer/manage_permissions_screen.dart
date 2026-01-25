import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:customer_sync/core/theme/app_theme.dart';
import 'package:customer_sync/widgets/gradient_background.dart';
import 'package:customer_sync/core/providers/theme_provider.dart';
import 'package:customer_sync/core/providers/user_provider.dart';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/services/api_service.dart';

class ManagePermissionsScreen extends ConsumerStatefulWidget {
  const ManagePermissionsScreen({super.key});

  @override
  ConsumerState<ManagePermissionsScreen> createState() => _ManagePermissionsScreenState();
}

class _ManagePermissionsScreenState extends ConsumerState<ManagePermissionsScreen> {
  late bool isDark;

  void _togglePermission(String key, bool value) async {
    final user = ref.read(userProvider);
    final apiService = ref.read(apiServiceProvider);
    
    // Optimistic update
    final nextPermissions = Map<String, bool>.from(user.permissions);
    nextPermissions[key] = value;
    
    final updatedUser = User(
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      profilePhoto: user.profilePhoto,
      permissions: nextPermissions,
    );
    
    ref.read(userProvider.notifier).state = updatedUser;

    // Persist to backend
    try {
      await apiService.updatePermissions(user.id, {key: value});
    } catch (e) {
      // Revert on error
      ref.read(userProvider.notifier).state = user;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update permission on server')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    isDark = ref.watch(themeProvider);
    return GradientBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: isDark ? Colors.white : Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Manage Permissions',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: ListView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'App Permissions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage which permissions the app can access',
              style: TextStyle(
                fontSize: 14,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            
            _buildPermissionItem(
              icon: LucideIcons.mapPin,
              title: 'Location',
              subtitle: 'Allow app to access your location for nearby shops',
              value: ref.watch(userProvider).permissions['location'] ?? false,
              onChanged: (value) => _togglePermission('location', value),
            ),
            
            _buildPermissionItem(
              icon: LucideIcons.bell,
              title: 'Notifications',
              subtitle: 'Receive booking confirmations and reminders',
              value: ref.watch(userProvider).permissions['notifications'] ?? false,
              onChanged: (value) => _togglePermission('notifications', value),
            ),
            
            _buildPermissionItem(
              icon: LucideIcons.camera,
              title: 'Camera',
              subtitle: 'Take photos for profile picture',
              value: ref.watch(userProvider).permissions['camera'] ?? false,
              onChanged: (value) => _togglePermission('camera', value),
            ),
            
            _buildPermissionItem(
              icon: LucideIcons.folder,
              title: 'Storage',
              subtitle: 'Save booking receipts and photos',
              value: ref.watch(userProvider).permissions['storage'] ?? false,
              onChanged: (value) => _togglePermission('storage', value),
            ),
            
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.blue : AppTheme.lightAccent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark ? Colors.blue : AppTheme.lightAccent).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.info,
                    color: isDark ? Colors.blue : AppTheme.lightAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Some features may not work properly if permissions are disabled',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
          ),
        ],
      ),
    );
  }
}

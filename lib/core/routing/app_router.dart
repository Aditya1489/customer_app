import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_sync/features/auth/login_screen.dart';
import 'package:customer_sync/features/customer/customer_home.dart';
import 'package:customer_sync/features/auth/registration_flow_screen.dart';
import 'package:customer_sync/features/customer/edit_profile_screen.dart';
import 'package:customer_sync/features/customer/manage_permissions_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationFlowScreen(),
      ),
      GoRoute(
        path: '/customer',
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/manage-permissions',
        builder: (context, state) => const ManagePermissionsScreen(),
      ),
    ],
  );
});

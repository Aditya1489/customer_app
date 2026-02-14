import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_sync/features/auth/login_screen.dart';
import 'package:customer_sync/features/customer/customer_home.dart';
import 'package:customer_sync/features/auth/registration_flow_screen.dart';
import 'package:customer_sync/features/customer/edit_profile_screen.dart';
import 'package:customer_sync/features/customer/manage_permissions_screen.dart';
import 'package:customer_sync/features/customer/submit_review_screen.dart';
import 'package:customer_sync/features/customer/shop_preview_screen.dart';
import 'package:customer_sync/features/customer/staff_preview_screen.dart';
import 'package:customer_sync/features/customer/booking_screen.dart';
import 'package:customer_sync/models/models.dart';
import 'package:customer_sync/core/providers/user_provider.dart';
import 'package:customer_sync/features/common/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Use a ValueNotifier to trigger router refreshes without rebuilding the router itself
  final enableRefresh = ValueNotifier<int>(0);
  
  ref.listen<User?>(userProvider, (_, __) {
    enableRefresh.value++;
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: enableRefresh,
    redirect: (context, state) {
      final user = ref.read(userProvider);
      final isSplashing = state.matchedLocation == '/splash';
      
      // Always allow splash to render. The SplashScreen widget will handle navigation.
      if (isSplashing) return null;

      final isRegistering = state.matchedLocation == '/register';
      final isLoggingIn = state.matchedLocation == '/login';

      // 1. Unauthenticated -> Login
      if (user == null) {
        return (isLoggingIn || isRegistering || isSplashing) ? null : '/login';
      }

      // 2. Temp User -> Force Register
      if (user.id == 'temp') {
        if (!isRegistering) {
            return '/register';
        }
        return null; // Stay on register
      }
      
      // 3. Authenticated -> Home (if trying to login/register/splash)
      if (isLoggingIn || isRegistering || isSplashing) {
        return '/customer';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
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
      GoRoute(
        path: '/submit-review',
        builder: (context, state) {
          final bookingData = (state.extra as Map<String, dynamic>?) ?? {};
          return SubmitReviewScreen(bookingData: bookingData);
        },
      ),
      GoRoute(
        path: '/shop-preview',
        builder: (context, state) {
          final shop = state.extra as BarberShop;
          return ShopPreviewScreen(shop: shop);
        },
      ),
      GoRoute(
        path: '/staff-preview',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          // Defensive check: Handle both wrapped Staff object and raw staff Map
          final Staff staff = extras['staff'] is Staff 
              ? extras['staff'] as Staff 
              : Staff.fromJson(extras);
          final shop = extras['shop'] as BarberShop?;
          return StaffPreviewScreen(staff: staff, shop: shop);
        },
      ),
      GoRoute(
        path: '/booking',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          final shop = extras['shop'] as BarberShop;
          final staff = extras['staff'] as Staff?;
          return BookingScreen(shop: shop, initialStaff: staff);
        },
      ),
    ],
  );
});

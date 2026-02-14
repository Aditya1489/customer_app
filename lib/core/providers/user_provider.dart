import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_sync/models/models.dart';

import 'package:customer_sync/services/storage_service.dart';

class UserNotifier extends StateNotifier<User?> {
  final StorageService _storageService;

  UserNotifier(this._storageService) : super(null) {
    _init();
  }

  Future<void> _init() async {
    final user = await _storageService.getUser();
    print('🔐 [USER] Initializing UserProvider: ${user?.id ?? "null"}');
    if (state == null) {
      state = user;
    }
  }

  Future<void> setUser(User? user) async {
    print('🔐 [USER] Setting user: ${user?.id ?? "null"}');
    state = user;
    if (user != null) {
      await _storageService.saveUser(user);
      print('✅ [USER] User saved to storage: ${user.id}');
    } else {
      await _storageService.clearUser();
      print('✅ [USER] User cleared from storage');
    }
  }

  void setTemporaryUser(User user) {
    print('🔐 [USER] Setting temporary user: ${user.id}');
    state = user;
  }
}

final userProvider = StateNotifierProvider<UserNotifier, User?>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return UserNotifier(storageService);
});

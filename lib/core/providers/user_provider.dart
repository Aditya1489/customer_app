import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:customer_sync/models/models.dart';

final userProvider = StateProvider<User>((ref) {
  return User(
    id: "116b2e11-4319-4204-9bd9-004b56332f12", // Real Customer ID from DB
    name: "Alex Johnson",
    email: "alex.johnson@email.com",
    phone: "+1 234 567 890",
    role: AppRole.customer,
    profilePhoto: null,
    permissions: {
      "location": true,
      "notifications": true,
      "camera": true,
      "storage": false,
    },
  );
});

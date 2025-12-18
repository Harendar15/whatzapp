import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adchat/controller/repo/auth_repository.dart';
import 'package:adchat/models/user_model.dart';

/// This file DOES NOT create a new authRepositoryProvider.
/// It REUSES the one defined in auth_repository.dart

/// Stream of current user data
final userDataAuthProvider = StreamProvider<UserModel?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final uid = repo.auth.currentUser?.uid;

  if (uid == null) {
    return const Stream.empty();
  }

  return repo.userData(uid);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/preferences_model.dart';

/// Provider for UserRepository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// Stream provider for user profile
final userProfileStreamProvider =
    StreamProvider.family<User, String>((ref, userId) {
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.getUserProfileStream(userId);
});

/// Future provider for user profile
final userProfileProvider = FutureProvider.family<User, String>((ref, userId) {
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.getUserProfile(userId);
});

/// Future provider for user preferences
final userPreferencesProvider =
    FutureProvider.family<UserPreferencesModel, String>((ref, userId) {
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.getUserPreferences(userId);
});

/// State notifier for user profile actions
class UserNotifier extends StateNotifier<AsyncValue<void>> {
  final UserRepository _userRepository;

  UserNotifier(this._userRepository) : super(const AsyncValue.data(null));

  // Update user profile
  Future<void> updateUserProfile(User user) async {
    state = const AsyncValue.loading();
    try {
      await _userRepository.updateUserProfile(user);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Update profile field
  Future<void> updateProfileField(
    String userId,
    String field,
    dynamic value,
  ) async {
    try {
      await _userRepository.updateProfileField(userId, field, value);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Update user preferences
  Future<void> updateUserPreferences(UserPreferencesModel preferences) async {
    state = const AsyncValue.loading();
    try {
      await _userRepository.updateUserPreferences(preferences);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Update notification preferences
  Future<void> updateNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    try {
      await _userRepository.updateNotificationPreferences(userId, preferences);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Update privacy preferences
  Future<void> updatePrivacyPreferences(
    String userId,
    PrivacyPreferences preferences,
  ) async {
    try {
      await _userRepository.updatePrivacyPreferences(userId, preferences);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Update wellness preferences
  Future<void> updateWellnessPreferences(
    String userId,
    WellnessPreferences preferences,
  ) async {
    try {
      await _userRepository.updateWellnessPreferences(userId, preferences);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Update UI preferences
  Future<void> updateUIPreferences(
    String userId,
    UIPreferences preferences,
  ) async {
    try {
      await _userRepository.updateUIPreferences(userId, preferences);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Update streak
  Future<void> updateStreak(String userId, int currentStreak) async {
    try {
      await _userRepository.updateStreak(userId, currentStreak);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Increment total check-ins
  Future<void> incrementTotalCheckIns(String userId) async {
    try {
      await _userRepository.incrementTotalCheckIns(userId);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Update subscription
  Future<void> updateSubscription({
    required String userId,
    required String tier,
    DateTime? expiresAt,
  }) async {
    try {
      await _userRepository.updateSubscription(
        userId: userId,
        tier: tier,
        expiresAt: expiresAt,
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Deactivate account
  Future<void> deactivateAccount(String userId) async {
    try {
      await _userRepository.deactivateAccount(userId);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Reactivate account
  Future<void> reactivateAccount(String userId) async {
    try {
      await _userRepository.reactivateAccount(userId);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}

/// Provider for UserNotifier
final userNotifierProvider =
    StateNotifierProvider<UserNotifier, AsyncValue<void>>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return UserNotifier(userRepository);
});

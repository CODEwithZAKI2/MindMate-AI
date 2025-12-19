import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/data_export_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/mood_repository.dart';
import '../../data/repositories/chat_repository.dart';

/// Provider for user repository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// Provider for mood repository
final moodRepositoryProvider = Provider<MoodRepository>((ref) {
  return MoodRepository();
});

/// Provider for DataExportService
final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DataExportService(
    userRepository: ref.read(userRepositoryProvider),
    moodRepository: ref.read(moodRepositoryProvider),
    chatRepository: ref.read(chatRepositoryProvider),
  );
});

/// Provider for chat repository (already exists in chat_provider.dart)
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

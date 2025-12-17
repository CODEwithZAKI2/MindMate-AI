# MindMate AI – Flutter App Structure

## Folder Structure
```
lib/
├── main.dart
├── app.dart
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   ├── api_endpoints.dart
│   │   └── asset_paths.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── colors.dart
│   │   └── typography.dart
│   ├── utils/
│   │   ├── validators.dart
│   │   ├── date_utils.dart
│   │   └── logger.dart
│   └── errors/
│       ├── exceptions.dart
│       └── failures.dart
│
├── data/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── mood_log_model.dart
│   │   ├── chat_message_model.dart
│   │   └── preferences_model.dart
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── chat_repository.dart
│   │   ├── mood_repository.dart
│   │   └── user_repository.dart
│   └── services/
│       ├── api_service.dart
│       ├── firebase_service.dart
│       ├── secure_storage_service.dart
│       └── notification_service.dart
│
├── domain/
│   ├── entities/
│   │   ├── user.dart
│   │   ├── mood_log.dart
│   │   └── chat_session.dart
│   └── usecases/
│       ├── send_chat_message.dart
│       ├── log_mood.dart
│       └── get_mood_trends.dart
│
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── chat_provider.dart
│   │   ├── mood_provider.dart
│   │   └── settings_provider.dart
│   ├── screens/
│   │   ├── splash/
│   │   ├── onboarding/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── chat/
│   │   ├── mood/
│   │   ├── insights/
│   │   ├── exercises/
│   │   └── settings/
│   ├── widgets/
│   │   ├── common/
│   │   ├── chat/
│   │   ├── mood/
│   │   └── charts/
│   └── navigation/
│       ├── app_router.dart
│       └── routes.dart
│
└── l10n/
    ├── app_en.arb
    └── app_es.arb
```

## Key Screens

| Screen | Purpose |
|--------|---------|
| **SplashScreen** | App initialization, auth check |
| **OnboardingScreen** | Welcome slides, feature highlights |
| **DisclaimerScreen** | Legal disclaimer acceptance (blocking) |
| **SignInScreen** | Email/Google/Apple sign-in |
| **SignUpScreen** | Account creation with email verification |
| **HomeScreen** | Dashboard with mood summary, quick actions |
| **ChatScreen** | AI conversation interface |
| **MoodCheckInScreen** | Daily mood entry with scale + notes |
| **MoodHistoryScreen** | Calendar view, trend charts |
| **InsightsScreen** | AI-generated weekly insights (Premium) |
| **ExercisesScreen** | Breathing, journaling, CBT exercises |
| **SettingsScreen** | Profile, notifications, privacy, logout |
| **CrisisScreen** | Crisis resources (overlay/modal) |

## Navigation Flow
```
App Launch
    │
    ▼
SplashScreen
    │
    ├─── [Not Authenticated] ──► OnboardingScreen ──► SignInScreen
    │
    └─── [Authenticated] ──► DisclaimerCheck
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
            [Not Accepted]                   [Accepted]
                    │                               │
                    ▼                               ▼
            DisclaimerScreen                  HomeScreen
                    │                               │
                    └───────► [Accept] ─────────────┘
                                                    │
                                                    ▼
                              ┌──────────────────────────────────────┐
                              │            MAIN NAVIGATION           │
                              │  (Bottom Nav: Home | Chat | Mood |   │
                              │           Insights | Settings)       │
                              └──────────────────────────────────────┘
```

## State Management Approach

**Choice: Riverpod 2.x**

**Why Riverpod:**
- Compile-time safety (catches errors early)
- No BuildContext dependency for providers
- Excellent testing support with ProviderContainer
- Auto-dispose for efficient memory management
- Works well with async operations (FutureProvider, StreamProvider)
- Recommended by Flutter community for production apps

**Provider Organization:**
```dart
// Auth State
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Chat State
final chatMessagesProvider = StateNotifierProvider<ChatNotifier, AsyncValue<List<ChatMessage>>>((ref) {
  return ChatNotifier(ref.watch(chatRepositoryProvider));
});

// Mood State
final moodLogsProvider = FutureProvider.family<List<MoodLog>, DateRange>((ref, range) {
  return ref.watch(moodRepositoryProvider).getMoodLogs(range);
});

// Combined State (for insights)
final weeklyInsightsProvider = FutureProvider<WeeklyInsight>((ref) async {
  final moods = await ref.watch(moodLogsProvider(thisWeek).future);
  final chats = await ref.watch(chatSummariesProvider.future);
  return InsightGenerator.generate(moods, chats);
});
```
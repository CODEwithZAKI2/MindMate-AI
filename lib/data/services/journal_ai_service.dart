import 'package:cloud_functions/cloud_functions.dart';

/// Service for Journal AI features via Cloud Functions
class JournalAIService {
  final FirebaseFunctions _functions;

  JournalAIService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  /// Generate AI reflection for a journal entry
  /// Returns null if entry is too short or crisis is detected
  Future<JournalReflectionResult> generateReflection({
    required String entryId,
    required String content,
    required String userId,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateJournalReflection');
      final result = await callable.call<Map<String, dynamic>>({
        'entryId': entryId,
        'content': content,
        'userId': userId,
      });

      final data = result.data;

      if (data['success'] != true) {
        return JournalReflectionResult.error(data['error'] ?? 'Unknown error');
      }

      if (data['safe'] == false) {
        return JournalReflectionResult.crisis(
          crisisResponse:
              data['crisisResponse'] ?? 'Please reach out for support.',
        );
      }

      final reflection = data['reflection'];
      if (reflection == null) {
        return JournalReflectionResult.noReflection();
      }

      return JournalReflectionResult.success(
        toneSummary: reflection['toneSummary'] ?? '',
        reflectionQuestions: List<String>.from(
          reflection['reflectionQuestions'] ?? [],
        ),
      );
    } catch (e) {
      return JournalReflectionResult.error(e.toString());
    }
  }

  /// Generate contextual smart prompts based on user's mood and time
  Future<List<SmartPrompt>> generateSmartPrompts({
    required String userId,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateSmartPrompts');
      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
      });

      final data = result.data;

      if (data['success'] != true || data['prompts'] == null) {
        return _fallbackPrompts;
      }

      return (data['prompts'] as List)
          .map(
            (p) => SmartPrompt(
              category: p['category'] ?? '',
              prompt: p['prompt'] ?? '',
            ),
          )
          .toList();
    } catch (e) {
      return _fallbackPrompts;
    }
  }

  /// Reframe text with CBT-inspired perspective
  Future<String?> reframeText({
    required String userId,
    required String text,
  }) async {
    try {
      final callable = _functions.httpsCallable('reframeJournalText');
      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
        'text': text,
      });

      final data = result.data;

      if (data['success'] == true && data['reframed'] != null) {
        return data['reframed'] as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  List<SmartPrompt> get _fallbackPrompts => [
    SmartPrompt(
      category: 'gratitude',
      prompt: "What's one small thing you're grateful for today?",
    ),
    SmartPrompt(
      category: 'reflection',
      prompt: "What moment stood out to you today?",
    ),
    SmartPrompt(
      category: 'reframing',
      prompt: "What's one thing that went better than expected?",
    ),
    SmartPrompt(
      category: 'self_compassion',
      prompt: "What would you tell a friend feeling this way?",
    ),
  ];

  /// Generate weekly or monthly emotional summary
  Future<EmotionalSummary?> generateEmotionalSummary({
    required String userId,
    required String period, // 'weekly' or 'monthly'
  }) async {
    try {
      final callable = _functions.httpsCallable('generateEmotionalSummary');
      final result = await callable.call<Map<String, dynamic>>({
        'userId': userId,
        'period': period,
      });

      final data = result.data;

      if (data['success'] != true || data['summary'] == null) {
        return null;
      }

      final s = data['summary'];
      return EmotionalSummary(
        periodStart: s['periodStart'] ?? '',
        periodEnd: s['periodEnd'] ?? '',
        entryCount: s['entryCount'] ?? 0,
        averageMood: (s['averageMood'] ?? 0).toDouble(),
        moodTrend: s['moodTrend'] ?? 'steady',
        topEmotions: List<String>.from(s['topEmotions'] ?? []),
        highlights: s['highlights'] ?? '',
        insights: s['insights'] ?? '',
        encouragement: s['encouragement'] ?? '',
      );
    } catch (e) {
      return null;
    }
  }
}

/// Result of journal reflection generation
class JournalReflectionResult {
  final bool success;
  final bool isCrisis;
  final String? toneSummary;
  final List<String>? reflectionQuestions;
  final String? crisisResponse;
  final String? error;

  JournalReflectionResult._({
    required this.success,
    this.isCrisis = false,
    this.toneSummary,
    this.reflectionQuestions,
    this.crisisResponse,
    this.error,
  });

  factory JournalReflectionResult.success({
    required String toneSummary,
    required List<String> reflectionQuestions,
  }) {
    return JournalReflectionResult._(
      success: true,
      toneSummary: toneSummary,
      reflectionQuestions: reflectionQuestions,
    );
  }

  factory JournalReflectionResult.crisis({required String crisisResponse}) {
    return JournalReflectionResult._(
      success: true,
      isCrisis: true,
      crisisResponse: crisisResponse,
    );
  }

  factory JournalReflectionResult.noReflection() {
    return JournalReflectionResult._(success: true);
  }

  factory JournalReflectionResult.error(String error) {
    return JournalReflectionResult._(success: false, error: error);
  }

  bool get hasReflection => toneSummary != null && reflectionQuestions != null;
}

/// Smart prompt for journaling
class SmartPrompt {
  final String category;
  final String prompt;

  SmartPrompt({required this.category, required this.prompt});
}

/// Emotional summary for weekly/monthly analysis
class EmotionalSummary {
  final String periodStart;
  final String periodEnd;
  final int entryCount;
  final double averageMood;
  final String moodTrend;
  final List<String> topEmotions;
  final String highlights;
  final String insights;
  final String encouragement;

  EmotionalSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.entryCount,
    required this.averageMood,
    required this.moodTrend,
    required this.topEmotions,
    required this.highlights,
    required this.insights,
    required this.encouragement,
  });
}

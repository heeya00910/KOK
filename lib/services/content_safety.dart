class ContentSafetyFilter {
  static final ContentSafetyFilter _instance = ContentSafetyFilter._();
  factory ContentSafetyFilter() => _instance;
  ContentSafetyFilter._();

  static const _blockedPatterns = [
    // Unverified rumors
    r'열애설',
    r'사생활',
    // Minors
    r'미성년.*성적',
    // Appearance shaming
    r'외모.*비하',
    r'성형.*의혹',
    // Criminal assertions
    r'범죄.*단정',
    r'학교폭력.*확인',
    // Self-harm
    r'자살',
    r'자해',
    // Hate speech
    r'인종.*혐오',
    r'국적.*혐오',
    // Private info
    r'주소.*공개',
    r'연락처.*공개',
    r'가족.*신상',
    // Sexual harassment
    r'성희롱',
  ];

  static const _reviewPatterns = [
    r'논란',
    r'의혹',
    r'갈등',
    r'법적.*분쟁',
    r'소송',
    r'폭로',
    r'학폭',
    r'탈퇴',
    r'해체',
    r'계약.*해지',
    r'왕따',
    r'불화',
  ];

  static const _blockedKeywordsEn = [
    'unverified dating rumor',
    'private address',
    'phone number leak',
    'suicide details',
    'self-harm method',
    'racial slur',
    'sexual harassment detail',
    'minor sexualization',
  ];

  SafetyResult checkKoreanContent(String title, String body) {
    final combined = '$title $body'.toLowerCase();

    for (final pattern in _blockedPatterns) {
      if (RegExp(pattern).hasMatch(combined)) {
        return SafetyResult(
          level: SafetyLevel.blocked,
          reason: 'Matched blocked pattern: $pattern',
        );
      }
    }

    for (final pattern in _reviewPatterns) {
      if (RegExp(pattern).hasMatch(combined)) {
        return SafetyResult(
          level: SafetyLevel.reviewNeeded,
          reason: 'Contains potentially sensitive content: $pattern',
        );
      }
    }

    return SafetyResult(level: SafetyLevel.safe, reason: '');
  }

  SafetyResult checkTranslatedContent(String content) {
    final lower = content.toLowerCase();

    for (final keyword in _blockedKeywordsEn) {
      if (lower.contains(keyword)) {
        return SafetyResult(
          level: SafetyLevel.blocked,
          reason: 'Blocked keyword in output: $keyword',
        );
      }
    }

    return SafetyResult(level: SafetyLevel.safe, reason: '');
  }

  String sanitizeComment(String comment) {
    var clean = comment;
    final phoneRegex = RegExp(r'\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{4}');
    clean = clean.replaceAll(phoneRegex, '[redacted]');
    final emailRegex = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
    clean = clean.replaceAll(emailRegex, '[redacted]');
    return clean;
  }
}

enum SafetyLevel { safe, reviewNeeded, blocked }

class SafetyResult {
  final SafetyLevel level;
  final String reason;

  SafetyResult({required this.level, required this.reason});
}

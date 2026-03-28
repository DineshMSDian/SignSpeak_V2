// gemini_service.dart
// Gemini Pro API integration for multilingual translation
// ASL: fingerspelled letters → word reconstruction → Tamil/Hindi translation
// ISL: gesture labels → natural sentence → Tamil/Hindi translation
//
// CRITICAL: Never call on every frame — only on button tap or 3s silence
// Temperature: 0.2 (deterministic output)
// API key loaded from .env file

class GeminiService {
  // TODO: Load API key from .env
  // TODO: Implement translateASL(List<String> letters)
  // TODO: Implement translateISL(List<String> gestures)
  // TODO: Parse JSON response {english, tamil, hindi}
}

class TranslationResult {
  final String english;
  final String tamil;
  final String hindi;

  TranslationResult({
    required this.english,
    required this.tamil,
    required this.hindi,
  });
}

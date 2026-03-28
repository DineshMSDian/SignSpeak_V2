// gemini_service.dart
// Gemini Pro API integration for multilingual translation
// ASL: fingerspelled letters → word reconstruction → Tamil/Hindi translation
// ISL: gesture labels → natural sentence → Tamil/Hindi translation
//
// CRITICAL: Never call on every frame — only on button tap or 3s silence
// Temperature: 0.2 (deterministic output)
// API key loaded from .env file

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class TranslationResult {
  final String english;
  final String tamil;
  final String hindi;

  TranslationResult({
    required this.english,
    required this.tamil,
    required this.hindi,
  });

  factory TranslationResult.empty() => TranslationResult(
        english: 'Translation failed',
        tamil: 'மொழிபெயர்ப்பு தோல்வியடைந்தது',
        hindi: 'अनुवाद विफल रहा',
      );
}

class GeminiService {
  String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      debugPrint('🚨 CRITICAL: GEMINI_API_KEY is missing from .env file');
      return '';
    }
    return key;
  }

  /// Translates a sequence of signs into a grammatically correct English sentence, 
  /// and then translates that sentence into Tamil and Hindi.
  Future<TranslationResult> translateSequence(List<String> sequence, bool isASL) async {
    if (_apiKey.isEmpty || sequence.isEmpty) {
      return TranslationResult.empty();
    }

    final prompt = _buildPrompt(sequence, isASL);
    
    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
             'temperature': 0.1, // Highly deterministic
             'responseMimeType': 'application/json',
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contentText = data['candidates'][0]['content']['parts'][0]['text'];
        
        // Ensure the response is stripped of markdown formatting if any
        final cleanJson = contentText.replaceAll('```json', '').replaceAll('```', '').trim();
        final parsed = jsonDecode(cleanJson);
        
        return TranslationResult(
          english: parsed['english'] ?? 'Error',
          tamil: parsed['tamil'] ?? 'பிழை',
          hindi: parsed['hindi'] ?? 'त्रुटि',
        );
      } else {
        debugPrint('Gemini API Error: ${response.statusCode} - ${response.body}');
        return TranslationResult.empty();
      }
    } catch (e) {
      debugPrint('Gemini Service Exception: $e');
      return TranslationResult.empty();
    }
  }

  String _buildPrompt(List<String> sequence, bool isASL) {
    final joinedSequence = sequence.join(isASL ? '' : ' ');
    
    return '''
You are an expert Sign Language Translator. 
I will provide you with a sequence of detected signs.
Your task is to:
1. Reconstruct the logical English sentence (ignoring grammatical errors inherent to sign language syntax).
2. Translate that correct English sentence into Tamil.
3. Translate that correct English sentence into Hindi.

Context: ${isASL ? 'These are ASL fingerspelled letters (e.g., H E L L O = Hello)' : 'These are distinct ISL word gestures.'}
Provided Sequence: "$joinedSequence"

Output the result STRICTLY as a raw JSON object containing exactly these three keys:
{
  "english": "the corrected english sentence",
  "tamil": "the tamil translation",
  "hindi": "the hindi translation"
}
''';
  }
}

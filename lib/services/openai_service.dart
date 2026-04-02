import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nikki/models/explanation.dart';
import 'package:nikki/models/explanation_category.dart';

class OpenAiService {
  static const _baseUrl = 'https://api.openai.com/v1/chat/completions';

  http.Client? _activeClient;

  /// Cancel any in-flight HTTP request.
  void cancelPending() {
    _activeClient?.close();
    _activeClient = null;
  }

  Future<Explanation> getExplanation({
    required String apiKey,
    required String selectedText,
    required String surroundingContext,
    required String sourceLanguage,
    required String targetLanguage,
    required Set<ExplanationCategory> enabledCategories,
  }) async {
    if (apiKey.isEmpty) throw Exception('API key not set. Add your OpenAI key in Settings.');

    final systemPrompt = 'You are a language tutor. The user is reading a novel in $sourceLanguage and learning vocabulary. Respond ONLY with valid JSON, no extra text.';

    final userPrompt = StringBuffer()
      ..writeln('Selected text: "$selectedText"')
      ..writeln('Surrounding context: "$surroundingContext"')
      ..writeln('Source language: $sourceLanguage')
      ..writeln('Target language: $targetLanguage')
      ..writeln()
      ..writeln('Provide the following in JSON format:')
      ..writeln('{');

    if (enabledCategories.contains(ExplanationCategory.meaning)) {
      userPrompt.writeln('  "meaning": "definition in $targetLanguage",');
    }
    if (enabledCategories.contains(ExplanationCategory.reading)) {
      userPrompt.writeln('  "reading": "pronunciation/furigana/romanization",');
    }
    if (enabledCategories.contains(ExplanationCategory.context)) {
      userPrompt.writeln('  "context": "what it means in this specific context",');
    }
    if (enabledCategories.contains(ExplanationCategory.examples)) {
      userPrompt.writeln('  "examples": ["example sentence 1", "example sentence 2", "example sentence 3"],');
    }
    if (enabledCategories.contains(ExplanationCategory.breakdown)) {
      userPrompt.writeln('  "breakdown": "morphological breakdown of the word",');
    }
    if (enabledCategories.contains(ExplanationCategory.formality)) {
      userPrompt.writeln('  "formality": "register/formality level",');
    }
    if (enabledCategories.contains(ExplanationCategory.similarWords)) {
      userPrompt.writeln('  "similar_words": [{"word": "...", "reading": "...", "brief": "one-line difference"}]');
    }

    userPrompt
      ..writeln('}')
      ..writeln()
      ..writeln('Be concise. Use $targetLanguage for all explanations. Include 3-5 similar words if requested.');

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt.toString()},
      ],
      'response_format': {'type': 'json_object'},
    });

    final client = http.Client();
    _activeClient = client;
    try {
      final response = await client.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error']?['message'] ?? 'API request failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      final json = jsonDecode(content) as Map<String, dynamic>;
      return Explanation.fromJson(json);
    } finally {
      if (_activeClient == client) _activeClient = null;
      client.close();
    }
  }

  Future<ComparisonResult> getComparison({
    required String apiKey,
    required String originalWord,
    required String comparedWord,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (apiKey.isEmpty) throw Exception('API key not set');

    final systemPrompt = 'You are a language tutor comparing two $sourceLanguage words. Respond ONLY with valid JSON.';

    final userPrompt = '''
Compare these two $sourceLanguage words for a $targetLanguage speaker:

Word A: "$originalWord"
Word B: "$comparedWord"

Respond in JSON:
{
  "word_a": {"word": "$originalWord", "reading": "...", "meaning": "..."},
  "word_b": {"word": "$comparedWord", "reading": "...", "meaning": "..."},
  "difference": "key difference in meaning/usage",
  "nuance": "subtle connotation or cultural difference",
  "example_a": "example sentence using word A with translation",
  "example_b": "example sentence using word B with translation"
}

Be concise. Use $targetLanguage for explanations.''';

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'response_format': {'type': 'json_object'},
    });

    final client = http.Client();
    _activeClient = client;
    try {
      final response = await client.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error']?['message'] ?? 'API request failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ComparisonResult.fromJson(json);
    } finally {
      if (_activeClient == client) _activeClient = null;
      client.close();
    }
  }
}

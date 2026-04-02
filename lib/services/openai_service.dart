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

    final systemPrompt = '''You are an expert $sourceLanguage language tutor helping a learner who is reading a novel in $sourceLanguage. The learner's native language is $targetLanguage. Respond ONLY with valid JSON, no extra text.

CRITICAL RULES:
- All example sentences MUST be written in $sourceLanguage using the word/phrase being explained.
- NEVER write example sentences in $targetLanguage. The learner needs to see real $sourceLanguage usage.
- For Japanese: add furigana in parentheses after every kanji. Format: 漢字(かんじ)を読(よ)む. Every single kanji must have furigana, no exceptions.
- Explanations (meaning, context, breakdown, formality) should be in $targetLanguage so the learner understands them.
- Examples must be natural, everyday sentences that a native speaker would use.''';

    final userPrompt = StringBuffer()
      ..writeln('Selected text: "$selectedText"')
      ..writeln('Surrounding context from the novel: "$surroundingContext"')
      ..writeln('Source language: $sourceLanguage')
      ..writeln('Target language: $targetLanguage')
      ..writeln()
      ..writeln('Provide the following in JSON format:')
      ..writeln('{');

    if (enabledCategories.contains(ExplanationCategory.meaning)) {
      userPrompt.writeln('  "meaning": "clear definition in $targetLanguage",');
    }
    if (enabledCategories.contains(ExplanationCategory.reading)) {
      userPrompt.writeln('  "reading": "full furigana reading (e.g. かんじ for 漢字)",');
    }
    if (enabledCategories.contains(ExplanationCategory.context)) {
      userPrompt.writeln('  "context": "what it specifically means in this novel passage, explained in $targetLanguage",');
    }
    if (enabledCategories.contains(ExplanationCategory.examples)) {
      userPrompt.writeln('  "examples": ["$sourceLanguage sentence with furigana on all kanji", "another $sourceLanguage sentence", "third $sourceLanguage sentence"] — each example MUST be in $sourceLanguage with furigana, followed by $targetLanguage translation in parentheses,');
    }
    if (enabledCategories.contains(ExplanationCategory.breakdown)) {
      userPrompt.writeln('  "breakdown": "morphological breakdown explained in $targetLanguage, showing each component with furigana",');
    }
    if (enabledCategories.contains(ExplanationCategory.formality)) {
      userPrompt.writeln('  "formality": "register/politeness level explained in $targetLanguage",');
    }
    if (enabledCategories.contains(ExplanationCategory.similarWords)) {
      userPrompt.writeln('  "similar_words": [{"word": "...", "reading": "furigana reading", "brief": "one-line difference in $targetLanguage"}]');
    }

    userPrompt
      ..writeln('}')
      ..writeln()
      ..writeln('REMEMBER: Example sentences must be in $sourceLanguage with furigana on every kanji, not in $targetLanguage. Include a $targetLanguage translation in parentheses after each example. Include 3-5 similar words if requested. Be concise.');

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

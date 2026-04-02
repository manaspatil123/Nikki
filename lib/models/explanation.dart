class Explanation {
  final String? meaning;
  final String? reading;
  final String? context;
  final List<String>? examples;
  final String? breakdown;
  final String? formality;
  final List<SimilarWord>? similarWords;
  final List<ComparisonResult>? comparisons;

  Explanation({
    this.meaning,
    this.reading,
    this.context,
    this.examples,
    this.breakdown,
    this.formality,
    this.similarWords,
    this.comparisons,
  });

  Explanation copyWith({List<ComparisonResult>? comparisons}) => Explanation(
    meaning: meaning,
    reading: reading,
    context: context,
    examples: examples,
    breakdown: breakdown,
    formality: formality,
    similarWords: similarWords,
    comparisons: comparisons ?? this.comparisons,
  );

  factory Explanation.fromJson(Map<String, dynamic> json) => Explanation(
    meaning: _asString(json['meaning']),
    reading: _asString(json['reading']),
    context: _asString(json['context']),
    examples: (json['examples'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    breakdown: _asString(json['breakdown']),
    formality: _asString(json['formality']),
    similarWords: (json['similar_words'] as List<dynamic>?)
        ?.whereType<Map<String, dynamic>>()
        .map((e) => SimilarWord.fromJson(e))
        .toList(),
    comparisons: (json['comparisons'] as List<dynamic>?)
        ?.whereType<Map<String, dynamic>>()
        .map((e) => ComparisonResult.fromJson(e))
        .toList(),
  );

  /// Safely convert a value to String — handles cases where the API
  /// returns a Map or other non-string type for a field.
  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  Map<String, dynamic> toJson() => {
    if (meaning != null) 'meaning': meaning,
    if (reading != null) 'reading': reading,
    if (context != null) 'context': context,
    if (examples != null) 'examples': examples,
    if (breakdown != null) 'breakdown': breakdown,
    if (formality != null) 'formality': formality,
    if (similarWords != null) 'similar_words': similarWords!.map((e) => e.toJson()).toList(),
    if (comparisons != null && comparisons!.isNotEmpty)
      'comparisons': comparisons!.map((e) => e.toJson()).toList(),
  };
}

class SimilarWord {
  final String word;
  final String reading;
  final String brief;

  SimilarWord({required this.word, required this.reading, required this.brief});

  factory SimilarWord.fromJson(Map<String, dynamic> json) => SimilarWord(
    word: json['word'] as String? ?? '',
    reading: json['reading'] as String? ?? '',
    brief: json['brief'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'word': word, 'reading': reading, 'brief': brief};
}

class ComparisonResult {
  final ComparisonWord wordA;
  final ComparisonWord wordB;
  final String difference;
  final String nuance;
  final String exampleA;
  final String exampleB;

  ComparisonResult({
    required this.wordA,
    required this.wordB,
    required this.difference,
    required this.nuance,
    required this.exampleA,
    required this.exampleB,
  });

  factory ComparisonResult.fromJson(Map<String, dynamic> json) => ComparisonResult(
    wordA: ComparisonWord.fromJson(json['word_a'] as Map<String, dynamic>? ?? {}),
    wordB: ComparisonWord.fromJson(json['word_b'] as Map<String, dynamic>? ?? {}),
    difference: json['difference'] as String? ?? '',
    nuance: json['nuance'] as String? ?? '',
    exampleA: json['example_a'] as String? ?? '',
    exampleB: json['example_b'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'word_a': wordA.toJson(),
    'word_b': wordB.toJson(),
    'difference': difference,
    'nuance': nuance,
    'example_a': exampleA,
    'example_b': exampleB,
  };
}

class ComparisonWord {
  final String word;
  final String reading;
  final String meaning;

  ComparisonWord({required this.word, required this.reading, required this.meaning});

  factory ComparisonWord.fromJson(Map<String, dynamic> json) => ComparisonWord(
    word: json['word'] as String? ?? '',
    reading: json['reading'] as String? ?? '',
    meaning: json['meaning'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'reading': reading,
    'meaning': meaning,
  };
}

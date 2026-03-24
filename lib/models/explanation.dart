class Explanation {
  final String? meaning;
  final String? reading;
  final String? context;
  final List<String>? examples;
  final String? breakdown;
  final String? formality;
  final List<SimilarWord>? similarWords;

  Explanation({
    this.meaning,
    this.reading,
    this.context,
    this.examples,
    this.breakdown,
    this.formality,
    this.similarWords,
  });

  factory Explanation.fromJson(Map<String, dynamic> json) => Explanation(
    meaning: json['meaning'] as String?,
    reading: json['reading'] as String?,
    context: json['context'] as String?,
    examples: (json['examples'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    breakdown: json['breakdown'] as String?,
    formality: json['formality'] as String?,
    similarWords: (json['similar_words'] as List<dynamic>?)
        ?.map((e) => SimilarWord.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    if (meaning != null) 'meaning': meaning,
    if (reading != null) 'reading': reading,
    if (context != null) 'context': context,
    if (examples != null) 'examples': examples,
    if (breakdown != null) 'breakdown': breakdown,
    if (formality != null) 'formality': formality,
    if (similarWords != null) 'similar_words': similarWords!.map((e) => e.toJson()).toList(),
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
}

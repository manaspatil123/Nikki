class WordEntry {
  final int? id;
  final int novelId;
  final String selectedText;
  final String surroundingContext;
  final String explanationJson; // full AI response as JSON string
  final int createdAt;

  WordEntry({
    this.id,
    required this.novelId,
    required this.selectedText,
    required this.surroundingContext,
    required this.explanationJson,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'novelId': novelId,
    'selectedText': selectedText,
    'surroundingContext': surroundingContext,
    'explanationJson': explanationJson,
    'createdAt': createdAt,
  };

  factory WordEntry.fromMap(Map<String, dynamic> map) => WordEntry(
    id: map['id'] as int?,
    novelId: map['novelId'] as int,
    selectedText: map['selectedText'] as String,
    surroundingContext: map['surroundingContext'] as String,
    explanationJson: map['explanationJson'] as String,
    createdAt: map['createdAt'] as int,
  );
}

class WordEntry {
  final int? id;
  final int? novelId;
  final String selectedText;
  final String surroundingContext;
  final String explanationJson;
  final int createdAt;
  final String notes;

  WordEntry({
    this.id,
    this.novelId,
    required this.selectedText,
    required this.surroundingContext,
    required this.explanationJson,
    required this.createdAt,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'novelId': novelId,
    'selectedText': selectedText,
    'surroundingContext': surroundingContext,
    'explanationJson': explanationJson,
    'createdAt': createdAt,
    'notes': notes,
  };

  factory WordEntry.fromMap(Map<String, dynamic> map) => WordEntry(
    id: map['id'] as int?,
    novelId: map['novelId'] as int?,
    selectedText: map['selectedText'] as String,
    surroundingContext: map['surroundingContext'] as String,
    explanationJson: map['explanationJson'] as String,
    createdAt: map['createdAt'] as int,
    notes: map['notes'] as String? ?? '',
  );
}

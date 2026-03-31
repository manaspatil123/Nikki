class WordEntry {
  final int? id;
  final int? novelId;
  final String selectedText;
  final String surroundingContext;
  final String explanationJson;
  final int createdAt;
  final String notes;
  final bool hiddenFromHistory;

  WordEntry({
    this.id,
    this.novelId,
    required this.selectedText,
    required this.surroundingContext,
    required this.explanationJson,
    required this.createdAt,
    this.notes = '',
    this.hiddenFromHistory = false,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'novelId': novelId,
    'selectedText': selectedText,
    'surroundingContext': surroundingContext,
    'explanationJson': explanationJson,
    'createdAt': createdAt,
    'notes': notes,
    'hiddenFromHistory': hiddenFromHistory ? 1 : 0,
  };

  factory WordEntry.fromMap(Map<String, dynamic> map) => WordEntry(
    id: map['id'] as int?,
    novelId: map['novelId'] as int?,
    selectedText: map['selectedText'] as String,
    surroundingContext: map['surroundingContext'] as String,
    explanationJson: map['explanationJson'] as String,
    createdAt: map['createdAt'] as int,
    notes: map['notes'] as String? ?? '',
    hiddenFromHistory: (map['hiddenFromHistory'] as int? ?? 0) == 1,
  );
}

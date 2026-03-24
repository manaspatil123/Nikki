class Novel {
  final int? id;
  final String name;
  final String sourceLanguage;
  final String targetLanguage;
  final int createdAt; // milliseconds since epoch
  final int sortOrder;

  Novel({
    this.id,
    required this.name,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.createdAt,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'createdAt': createdAt,
    'sortOrder': sortOrder,
  };

  factory Novel.fromMap(Map<String, dynamic> map) => Novel(
    id: map['id'] as int?,
    name: map['name'] as String,
    sourceLanguage: map['sourceLanguage'] as String,
    targetLanguage: map['targetLanguage'] as String,
    createdAt: map['createdAt'] as int,
    sortOrder: map['sortOrder'] as int? ?? 0,
  );

  Novel copyWith({int? id, String? name, String? sourceLanguage, String? targetLanguage, int? createdAt, int? sortOrder}) =>
    Novel(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
}

class Subject {
  final int id;
  final String name;
  final String? subjectImageUrl;

  Subject({required this.id, required this.name, this.subjectImageUrl});

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      subjectImageUrl: json['subjectImageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (subjectImageUrl != null) 'subjectImageUrl': subjectImageUrl,
    };
  }

  Subject copyWith({int? id, String? name, String? subjectImageUrl}) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      subjectImageUrl: subjectImageUrl ?? this.subjectImageUrl,
    );
  }
}

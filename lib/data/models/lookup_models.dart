class EducationStage {
  final int id;
  final String name;

  EducationStage({required this.id, required this.name});

  factory EducationStage.fromJson(Map<String, dynamic> json) {
    return EducationStage(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
    );
  }
}

class Subject {
  final int id;
  final String name;

  Subject({required this.id, required this.name});

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
    );
  }
}

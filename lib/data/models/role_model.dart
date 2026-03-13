class Role {
  final String id;
  final String name;
  final bool isDeleted;

  Role({required this.id, required this.name, required this.isDeleted});

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      isDeleted: json['isDeleted'] ?? false,
    );
  }
}

class RegisterAssistantRequest {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final int teacherId;

  RegisterAssistantRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.teacherId,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'firstName': firstName,
    'lastName': lastName,
    'teacherId': teacherId,
  };
}

class Assistant {
  final int assistantId;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final int teacherId;
  final String teacherName;

  Assistant({
    required this.assistantId,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.teacherId,
    required this.teacherName,
  });

  factory Assistant.fromJson(Map<String, dynamic> json) {
    return Assistant(
      assistantId: json['assistantId'] ?? 0,
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      fullName: json['fullName'] ?? '',
      teacherId: json['teacherId'] ?? 0,
      teacherName: json['teacherName'] ?? '',
    );
  }
}

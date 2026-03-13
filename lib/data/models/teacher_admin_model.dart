class TeacherAdminModel {
  final int teacherId;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String phoneNumber;
  final String? photoUrl;
  final int subjectId;
  final String subjectName;
  final bool isVerified;
  final bool isDisabled;

  TeacherAdminModel({
    required this.teacherId,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.phoneNumber,
    this.photoUrl,
    required this.subjectId,
    required this.subjectName,
    required this.isVerified,
    required this.isDisabled,
  });

  factory TeacherAdminModel.fromJson(Map<String, dynamic> json) {
    return TeacherAdminModel(
      teacherId: json['teacherId'] ?? 0,
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      fullName: json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      photoUrl: json['photoUrl'],
      subjectId: json['subjectId'] ?? 0,
      subjectName: json['subjectName'] ?? '',
      isVerified: json['isVerified'] ?? false,
      isDisabled: json['isDisable'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teacherId': teacherId,
      'userId': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'isVerified': isVerified,
      'isDisabled': isDisabled,
    };
  }
}

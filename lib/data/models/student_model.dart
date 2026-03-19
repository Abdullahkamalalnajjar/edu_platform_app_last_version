class StudentModel {
  final int studentId;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final int gradeYear;
  final String parentPhoneNumber;
  final String studentPhoneNumber;

  StudentModel({
    required this.studentId,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.gradeYear,
    required this.parentPhoneNumber,
    this.studentPhoneNumber = '',
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      studentId: json['studentId'] ?? 0,
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      fullName: json['fullName'] ?? '',
      gradeYear: json['gradeYear'] ?? 0,
      parentPhoneNumber: json['parentPhoneNumber'] ?? '',
      studentPhoneNumber: json['studentPhoneNumber'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'userId': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'gradeYear': gradeYear,
      'parentPhoneNumber': parentPhoneNumber,
      'studentPhoneNumber': studentPhoneNumber,
    };
  }
}


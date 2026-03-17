class ParentChildCourse {
  final int courseId;
  final String courseTitle;
  final String teacherName;
  final String status;
  final DateTime? enrolledAt;

  ParentChildCourse({
    required this.courseId,
    required this.courseTitle,
    required this.teacherName,
    required this.status,
    this.enrolledAt,
  });

  factory ParentChildCourse.fromJson(Map<String, dynamic> json) {
    return ParentChildCourse(
      courseId: json['courseId'] ?? 0,
      courseTitle: json['courseTitle'] ?? '',
      teacherName: json['teacherName'] ?? '',
      status: json['status'] ?? '',
      enrolledAt: json['enrolledAt'] != null
          ? DateTime.tryParse(json['enrolledAt'])
          : null,
    );
  }
}

class ParentChild {
  final int studentId;
  final String studentFullName;
  final String studentEmail;
  final String studentPhoneNumber;
  final List<ParentChildCourse> courses;

  ParentChild({
    required this.studentId,
    required this.studentFullName,
    required this.studentEmail,
    required this.studentPhoneNumber,
    this.courses = const [],
  });

  factory ParentChild.fromJson(Map<String, dynamic> json) {
    return ParentChild(
      studentId: json['studentId'] ?? 0,
      studentFullName: json['studentFullName'] ?? '',
      studentEmail: json['studentEmail'] ?? '',
      studentPhoneNumber: json['studentPhoneNumber'] ?? '',
      courses: json['courses'] != null
          ? (json['courses'] as List)
              .map((e) => ParentChildCourse.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

class ParentAdminModel {
  final int parentId;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String parentPhoneNumber;
  final int childrenCount;
  final List<ParentChild> children;

  ParentAdminModel({
    required this.parentId,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.parentPhoneNumber,
    required this.childrenCount,
    this.children = const [],
  });

  factory ParentAdminModel.fromJson(Map<String, dynamic> json) {
    return ParentAdminModel(
      parentId: json['parentId'] ?? 0,
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      fullName: json['fullName'] ?? '',
      parentPhoneNumber: json['parentPhoneNumber'] ?? '',
      childrenCount: json['childrenCount'] ?? 0,
      children: json['children'] != null
          ? (json['children'] as List)
              .map((e) => ParentChild.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

import '../models/course_models.dart';

class CourseSubscription {
  final int courseSubscriptionId;
  final int studentId;
  final String studentName;
  final String studentEmail;
  final String studentPhone;
  final int courseId;
  final String courseName;
  final String teacherName;
  final int educationStageId;
  final String educationStageName;
  final String status; // Pending, Approved, Rejected
  final DateTime createdAt;
  final List<Lecture> lectures;

  CourseSubscription({
    required this.courseSubscriptionId,
    required this.studentId,
    required this.studentName,
    this.studentEmail = '',
    this.studentPhone = '',
    required this.courseId,
    required this.courseName,
    required this.teacherName,
    required this.educationStageId,
    required this.educationStageName,
    required this.status,
    required this.createdAt,
    this.lectures = const [],
  });

  factory CourseSubscription.fromJson(Map<String, dynamic> json) {
    return CourseSubscription(
      courseSubscriptionId: json['courseSubscriptionId'] ?? 0,
      studentId: json['studentId'] ?? 0,
      studentName: json['studentName'] ?? '',
      studentEmail: json['studentEmail'] ?? json['email'] ?? '',
      studentPhone: json['studentPhone'] ?? json['phoneNumber'] ?? json['parentPhoneNumber'] ?? '',
      courseId: json['courseId'] ?? 0,
      courseName: json['courseName'] ?? '',
      teacherName: json['teacherName'] ?? '',
      educationStageId: json['educationStageId'] ?? 0,
      educationStageName: json['educationStageName'] ?? '',
      status: json['status'] ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lectures: json['lectures'] != null
          ? (json['lectures'] as List).map((e) => Lecture.fromJson(e)).toList()
          : [],
    );
  }
}

class UpdateSubscriptionStatusRequest {
  final int id;
  final String status; // "Approved" or "Rejected"

  UpdateSubscriptionStatusRequest({required this.id, required this.status});

  Map<String, dynamic> toJson() => {'id': id, 'status': status};
}

class CourseSubscription {
  final int courseSubscriptionId;
  final int studentId;
  final String studentName;
  final int courseId;
  final String courseName;
  final String teacherName;
  final int educationStageId;
  final String educationStageName;
  final String status;
  final String createdAt;
  final List<dynamic>? lectures; // List of lecture objects

  CourseSubscription({
    required this.courseSubscriptionId,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.courseName,
    required this.teacherName,
    required this.educationStageId,
    required this.educationStageName,
    required this.status,
    required this.createdAt,
    this.lectures,
  });

  factory CourseSubscription.fromJson(Map<String, dynamic> json) {
    return CourseSubscription(
      courseSubscriptionId: json['courseSubscriptionId'] ?? 0,
      studentId: json['studentId'] ?? 0,
      studentName: json['studentName'] ?? '',
      courseId: json['courseId'] ?? 0,
      courseName: json['courseName'] ?? '',
      teacherName: json['teacherName'] ?? '',
      educationStageId: json['educationStageId'] ?? 0,
      educationStageName: json['educationStageName'] ?? '',
      status: json['status'] ?? 'Pending',
      createdAt: json['createdAt'] ?? '',
      lectures: json['lectures'] as List<dynamic>?,
    );
  }
}

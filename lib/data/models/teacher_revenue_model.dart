class TeacherRevenueResponse {
  final int teacherId;
  final String teacherName;
  final List<CourseRevenueDetail> courses;
  final double totalRevenue;
  final int totalApprovedSubscriptions;

  TeacherRevenueResponse({
    required this.teacherId,
    required this.teacherName,
    required this.courses,
    required this.totalRevenue,
    required this.totalApprovedSubscriptions,
  });

  factory TeacherRevenueResponse.fromJson(Map<String, dynamic> json) {
    return TeacherRevenueResponse(
      teacherId: json['teacherId'] ?? 0,
      teacherName: json['teacherName'] ?? '',
      courses: json['courses'] != null
          ? (json['courses'] as List)
                .map((e) => CourseRevenueDetail.fromJson(e))
                .toList()
          : [],
      totalRevenue: json['totalRevenue'] != null
          ? (json['totalRevenue'] as num).toDouble()
          : 0.0,
      totalApprovedSubscriptions: json['totalApprovedSubscriptions'] ?? 0,
    );
  }
}

class CourseRevenueDetail {
  final int courseId;
  final String courseTitle;
  final double? coursePrice;
  final double? discountedPrice;
  final int approvedSubscriptions;
  final double courseRevenue;
  final List<StudentRevenueDetail> students;

  CourseRevenueDetail({
    required this.courseId,
    required this.courseTitle,
    this.coursePrice,
    this.discountedPrice,
    required this.approvedSubscriptions,
    required this.courseRevenue,
    required this.students,
  });

  factory CourseRevenueDetail.fromJson(Map<String, dynamic> json) {
    return CourseRevenueDetail(
      courseId: json['courseId'] ?? 0,
      courseTitle: json['courseTitle'] ?? '',
      coursePrice: json['coursePrice'] != null
          ? (json['coursePrice'] as num).toDouble()
          : null,
      discountedPrice: json['discountedPrice'] != null
          ? (json['discountedPrice'] as num).toDouble()
          : null,
      approvedSubscriptions: json['approvedSubscriptions'] ?? 0,
      courseRevenue: json['courseRevenue'] != null
          ? (json['courseRevenue'] as num).toDouble()
          : 0.0,
      students: json['students'] != null
          ? (json['students'] as List)
                .map((e) => StudentRevenueDetail.fromJson(e))
                .toList()
          : [],
    );
  }
}

class StudentRevenueDetail {
  final int studentId;
  final String studentName;
  final String studentEmail;
  final double paidAmount;
  final DateTime subscriptionDate;

  StudentRevenueDetail({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.paidAmount,
    required this.subscriptionDate,
  });

  factory StudentRevenueDetail.fromJson(Map<String, dynamic> json) {
    return StudentRevenueDetail(
      studentId: json['studentId'] ?? 0,
      studentName: json['studentName'] ?? '',
      studentEmail: json['studentEmail'] ?? '',
      paidAmount: json['paidAmount'] != null
          ? (json['paidAmount'] as num).toDouble()
          : 0.0,
      subscriptionDate: json['subscriptionDate'] != null
          ? DateTime.parse(json['subscriptionDate'])
          : DateTime.now(),
    );
  }
}

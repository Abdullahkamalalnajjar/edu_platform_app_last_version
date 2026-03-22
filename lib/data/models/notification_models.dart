/// Model for a single notification
class NotificationItem {
  final int id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String? type;
  final int? courseId;
  final int? examId;
  final int? lectureId;
  final String? status;
  final int? teacherId;
  final String? lectureName;
  final String? courseName;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.isRead,
    this.type,
    this.courseId,
    this.examId,
    this.lectureId,
    this.status,
    this.teacherId,
    this.lectureName,
    this.courseName,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    // Support both camelCase and PascalCase from backend
    return NotificationItem(
      id: json['id'] ?? json['Id'] ?? 0,
      title: json['title'] ?? json['Title'] ?? '',
      body: json['body'] ?? json['Body'] ?? '',
      timestamp: (json['timestamp'] ?? json['Timestamp']) != null
          ? DateTime.parse((json['timestamp'] ?? json['Timestamp']))
          : DateTime.now(),
      isRead: json['isRead'] ?? json['IsRead'] ?? false,
      type: json['type'] ?? json['Type'],
      courseId: _toInt(json['courseId'] ?? json['CourseId']),
      examId: _toInt(json['examId'] ?? json['ExamId']),
      lectureId: _toInt(json['lectureId'] ?? json['LectureId']),
      status: json['status'] ?? json['Status'],
      teacherId: _toInt(json['teacherId'] ?? json['TeacherId']),
      lectureName: json['lectureName'] ?? json['LectureName'],
      courseName: json['courseName'] ?? json['CourseName'],
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  bool get hasNavigationData =>
      type != null || courseId != null || examId != null || lectureId != null;

  Map<String, dynamic> toNavigationData() {
    final d = <String, dynamic>{};
    if (type != null) d['type'] = type;
    if (courseId != null) d['courseId'] = courseId.toString();
    if (examId != null) d['examId'] = examId.toString();
    if (lectureId != null) d['lectureId'] = lectureId.toString();
    if (status != null) d['status'] = status;
    if (teacherId != null) d['teacherId'] = teacherId.toString();
    if (lectureName != null) d['lectureName'] = lectureName;
    if (courseName != null) d['courseName'] = courseName;
    if (title.isNotEmpty) d['title'] = title;
    return d;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }
}

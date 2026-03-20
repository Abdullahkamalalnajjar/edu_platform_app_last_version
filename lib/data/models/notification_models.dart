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
    return NotificationItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      type: json['type'],
      courseId: _toInt(json['courseId']),
      examId: _toInt(json['examId']),
      lectureId: _toInt(json['lectureId']),
      status: json['status'],
      teacherId: _toInt(json['teacherId']),
      lectureName: json['lectureName'],
      courseName: json['courseName'],
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

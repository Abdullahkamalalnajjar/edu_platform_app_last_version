class StudentCourseScore {
  final int studentId;
  final String studentName;
  final String studentEmail;
  final String? parentPhone;
  final String? studentPhone;
  final double totalScore;
  final double maxScore;
  final double percentage;
  final int examsTaken;
  final int examsCompleted;

  StudentCourseScore({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.parentPhone,
    this.studentPhone,
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.examsTaken,
    required this.examsCompleted,
  });

  factory StudentCourseScore.fromJson(Map<String, dynamic> json) {
    return StudentCourseScore(
      studentId: json['studentId'] ?? 0,
      studentName: json['studentName'] ?? '',
      studentEmail: json['studentEmail'] ?? '',
      parentPhone: json['parentPhone'],
      studentPhone: json['studentPhone'],
      totalScore: (json['totalScore'] ?? 0).toDouble(),
      maxScore: (json['maxScore'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
      examsTaken: json['examsTaken'] ?? 0,
      examsCompleted: json['examsCompleted'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'parentPhone': parentPhone,
      'studentPhone': studentPhone,
      'totalScore': totalScore,
      'maxScore': maxScore,
      'percentage': percentage,
      'examsTaken': examsTaken,
      'examsCompleted': examsCompleted,
    };
  }
}

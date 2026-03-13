class ParentStudent {
  final int studentId;
  final String userId;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final int? gradeYear;
  final List<LinkedCourse> courses;

  ParentStudent({
    required this.studentId,
    required this.userId,
    this.email,
    this.firstName,
    this.lastName,
    this.fullName,
    this.gradeYear,
    required this.courses,
  });

  factory ParentStudent.fromJson(Map<String, dynamic> json) {
    return ParentStudent(
      studentId: json['studentId'] ?? 0,
      userId: json['userId'] ?? '',
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      fullName: json['fullName'],
      gradeYear: json['gradeYear'],
      courses:
          (json['courses'] as List<dynamic>?)
              ?.map((e) => LinkedCourse.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class LinkedCourse {
  final int courseId;
  final String? courseTitle;
  final String? status;
  final String? createdAt;

  LinkedCourse({
    required this.courseId,
    this.courseTitle,
    this.status,
    this.createdAt,
  });

  factory LinkedCourse.fromJson(Map<String, dynamic> json) {
    return LinkedCourse(
      courseId: json['courseId'] ?? 0,
      courseTitle: json['courseTitle'],
      status: json['status'],
      createdAt: json['createdAt'],
    );
  }
}

class StudentExamScore {
  final int examId;
  final String? examTitle;
  final double totalScore;
  final double maxScore;
  final bool isFinished;
  final DateTime? submittedAt;
  final int correctAnswers;
  final int totalQuestions;
  final double percentage;

  StudentExamScore({
    required this.examId,
    this.examTitle,
    required this.totalScore,
    required this.maxScore,
    required this.isFinished,
    this.submittedAt,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.percentage,
  });

  factory StudentExamScore.fromJson(Map<String, dynamic> json) {
    return StudentExamScore(
      examId: json['examId'] ?? 0,
      examTitle: json['examTitle'],
      totalScore: (json['totalScore'] ?? 0).toDouble(),
      maxScore: (json['maxScore'] ?? 0).toDouble(),
      isFinished: json['isFinished'] ?? false,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'])
          : null,
      correctAnswers: json['correctAnswers'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

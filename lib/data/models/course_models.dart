class CourseRequest {
  final String title;
  final int gradeYear;
  final int teacherId;
  final int educationStageId;
  final double price;
  final double discountedPrice;
  final String? imagePath;

  CourseRequest({
    required this.title,
    required this.gradeYear,
    required this.teacherId,
    required this.educationStageId,
    required this.price,
    required this.discountedPrice,
    this.imagePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'gradeYear': gradeYear,
      'teacherId': teacherId,
      'educationStageId': educationStageId,
      'price': price,
      'discountedPrice': discountedPrice,
    };
  }

  Map<String, String> toFields() {
    return {
      'Title': title,
      'TeacherId': teacherId.toString(),
      'EducationStageId': educationStageId.toString(),
      // 'gradeYear': gradeYear.toString(), // Commented out as per screenshot
      'Price': price.toString(),
      'DiscountedPrice': discountedPrice.toString(),
    };
  }
}

class LectureRequest {
  final String title;
  final int courseId;

  LectureRequest({required this.title, required this.courseId});

  Map<String, dynamic> toJson() {
    return {'title': title, 'courseId': courseId};
  }
}

/// Material types: Video, Pdf, Image, Homework
class MaterialRequest {
  final String type;
  final int lectureId;
  final String? videoUrl;
  final String? title;
  final bool isFree;

  MaterialRequest({
    required this.type,
    required this.lectureId,
    this.videoUrl,
    this.title,
    this.isFree = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'lectureId': lectureId,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (title != null) 'title': title,
      'isFree': isFree,
    };
  }
}

class CourseMaterial {
  final int id;
  final String type;
  final String fileUrl;
  final String? title;
  final bool isFree;

  CourseMaterial({
    required this.id,
    required this.type,
    required this.fileUrl,
    this.title,
    required this.isFree,
  });

  factory CourseMaterial.fromJson(Map<String, dynamic> json) {
    return CourseMaterial(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      fileUrl: json['fileUrl'] ?? json['videoUrl'] ?? '',
      title: json['title'],
      isFree: json['isFree'] ?? json['is_free'] ?? false,
    );
  }
}

class Lecture {
  final int id;
  final String title;
  final int courseId;
  final List<CourseMaterial> materials;
  final bool isVisible;
  final int index;

  Lecture({
    required this.id,
    required this.title,
    required this.courseId,
    this.materials = const [],
    this.isVisible = true,
    this.index = 0,
  });

  factory Lecture.fromJson(Map<String, dynamic> json) {
    return Lecture(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      courseId: json['courseId'] ?? 0,
      materials: json['materials'] != null
          ? (json['materials'] as List)
              .map((e) => CourseMaterial.fromJson(e))
              .toList()
          : [],
      // Handle both camelCase and snake_case, defaulting to true if neither exists
      isVisible: json['isVisible'] ?? json['is_visible'] ?? true,
      index: json['index'] ?? 0,
    );
  }
}

class Course {
  final int id;
  final String title;
  final int gradeYear;
  final String? educationStageName;
  final int teacherId;
  final String teacherName;
  final String? courseImageUrl;
  final double price;
  final double discountedPrice;
  final List<Lecture> lectures;
  final int index;

  Course({
    required this.id,
    required this.title,
    required this.gradeYear,
    this.educationStageName,
    required this.teacherId,
    this.teacherName = '',
    this.courseImageUrl,
    this.price = 0.0,
    this.discountedPrice = 0.0,
    this.lectures = const [],
    this.index = 0,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      // Support both gradeYear and educationStageId for backwards compatibility
      gradeYear: json['educationStageId'] ?? json['gradeYear'] ?? 0,
      educationStageName: json['educationStageName'],
      teacherId: json['teacherId'] ?? 0,
      teacherName: json['teacherName'] ?? '',
      courseImageUrl: json['courseImageUrl'],
      price: json['price'] != null ? (json['price'] as num).toDouble() : 0.0,
      discountedPrice: json['discountedPrice'] != null
          ? (json['discountedPrice'] as num).toDouble()
          : 0.0,
      lectures: json['lectures'] != null
          ? ((json['lectures'] as List).map((e) => Lecture.fromJson(e)).toList()
            ..sort((a, b) => a.index.compareTo(b.index)))
          : [],
      index: json['index'] ?? 0,
    );
  }
}

class ExamRequest {
  final String title;
  final int lectureId;
  final String? deadline;
  final int durationInMinutes;

  final int type;
  final bool isRandomized;
  final bool isFree;

  ExamRequest({
    required this.title,
    required this.lectureId,
    this.deadline,
    this.durationInMinutes = 0,
    this.type = 1,
    this.isRandomized = true,
    this.isFree = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'lectureId': lectureId,
      if (deadline != null) 'deadline': deadline,
      'durationInMinutes': durationInMinutes,
      'type': type,
      'isRandomized': isRandomized,
      'isFree': isFree,
    };
  }
}

class QuestionRequest {
  final String questionType;
  final String content;
  final String? filePath; // For multipart upload
  final List<int>? fileBytes; // For Web upload
  final String? fileName; // Required if fileBytes is used
  final String answerType;
  final int score;
  final int examId;
  final bool correctByAssistant;
  final String? correctAnswer;
  final String? correctAnswerFilePath;
  final List<int>? correctAnswerFileBytes;
  final String? correctAnswerFileName;

  QuestionRequest({
    required this.questionType,
    required this.content,
    this.filePath,
    this.fileBytes,
    this.fileName,
    required this.answerType,
    required this.score,
    required this.examId,
    this.correctByAssistant = false,
    this.correctAnswer,
    this.correctAnswerFilePath,
    this.correctAnswerFileBytes,
    this.correctAnswerFileName,
  });

  Map<String, String> toFields() {
    final fields = {
      'QuestionType': questionType,
      'Content': content,
      'AnswerType': answerType,
      'Score': score.toString(),
      'ExamId': examId.toString(),
      'CorrectByAssistant': correctByAssistant.toString(),
    };
    if (correctAnswer != null) {
      fields['CorrectAnswer'] = correctAnswer!;
    }
    return fields;
  }
}

class Question {
  final int id;
  final String questionType;
  final String content;
  final String answerType;
  final int score;
  final bool correctByAssistant;
  final int examId;
  final List<QuestionOption> options;
  final String? correctAnswer; // Text answer
  final String? correctAnswerImageUrl; // URL of the correct answer image

  Question({
    required this.id,
    required this.questionType,
    required this.content,
    required this.answerType,
    required this.score,
    required this.correctByAssistant,
    required this.examId,
    this.options = const [],
    this.correctAnswer,
    this.correctAnswerImageUrl,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] ?? 0,
      questionType: json['questionType'] ?? '',
      content: json['content'] ?? '',
      answerType: json['answerType'] ?? '',
      score: json['score'] ?? 0,
      correctByAssistant: json['correctByAssistant'] ?? false,
      examId: json['examId'] ?? 0,
      options: json['options'] != null
          ? (json['options'] as List)
              .map((e) => QuestionOption.fromJson(e))
              .toList()
          : [],
      correctAnswer: json['correctAnswer'],
      correctAnswerImageUrl: json['correctAnswerImageUrl'],
    );
  }
}

class QuestionOption {
  final int id;
  final String content;
  final bool isCorrect;
  final int questionId;

  QuestionOption({
    required this.id,
    required this.content,
    required this.isCorrect,
    required this.questionId,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      isCorrect: json['isCorrect'] ?? false,
      questionId: json['questionId'] ?? 0,
    );
  }
}

class QuestionOptionRequest {
  final int? id; // Required for update, null for create
  final String content;
  final bool isCorrect;
  final int questionId;

  QuestionOptionRequest({
    this.id,
    required this.content,
    required this.isCorrect,
    required this.questionId,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'content': content,
      'isCorrect': isCorrect,
      'questionId': questionId,
    };
  }
}

class Exam {
  final int id;
  final String title;
  final int lectureId;
  final String? lectureName;
  final DateTime? deadline;
  final int durationInMinutes;
  final String? type;
  final bool isRandomized;
  final List<Question> questions;
  final bool isVisible;
  final bool isFree;

  Exam({
    required this.id,
    required this.title,
    required this.lectureId,
    this.lectureName,
    this.deadline,
    this.durationInMinutes = 0,
    this.type,
    this.isRandomized = true,
    this.questions = const [],
    this.isVisible = true,
    this.isFree = false,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      lectureId: json['lectureId'] ?? 0,
      lectureName: json['lectureName'],
      deadline:
          json['deadline'] != null ? DateTime.tryParse(json['deadline']) : null,
      durationInMinutes: (json['durationInMinutes'] is num)
          ? (json['durationInMinutes'] as num).toInt()
          : 0,
      type: json['type'],
      isRandomized:
          json['isRandomized'] ?? true, // Default to true if not present
      questions: json['questions'] != null
          ? (json['questions'] as List)
              .map((e) => Question.fromJson(e))
              .toList()
          : [],
      isVisible: json['isVisible'] ?? true,
      isFree: json['isFree'] ?? false,
    );
  }
}

class ExamSubmissionRequest {
  final int examId;
  final int studentId;
  final List<ExamAnswerRequest> answers;

  ExamSubmissionRequest({
    required this.examId,
    required this.studentId,
    required this.answers,
  });

  Map<String, dynamic> toJson() {
    return {
      'examId': examId,
      'studentId': studentId,
      'answers': answers.map((e) => e.toJson()).toList(),
    };
  }
}

class ExamAnswerRequest {
  final int questionId;
  final List<int> selectedOptionIds;
  final String? textAnswer;
  final String? imageAnswerUrl;

  ExamAnswerRequest({
    required this.questionId,
    this.selectedOptionIds = const [],
    this.textAnswer,
    this.imageAnswerUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'questionId': questionId,
      'selectedOptionIds': selectedOptionIds,
      'textAnswer': textAnswer,
      'imageAnswerUrl': imageAnswerUrl,
    };
  }
}

// --- Exam Result Models ---

class QuestionOptionResult {
  final int optionId;
  final String optionContent;
  final bool isCorrect;
  final bool isSelected;

  QuestionOptionResult({
    required this.optionId,
    required this.optionContent,
    required this.isCorrect,
    required this.isSelected,
  });

  factory QuestionOptionResult.fromJson(Map<String, dynamic> json) {
    return QuestionOptionResult(
      optionId: json['optionId'] ?? 0,
      optionContent: json['optionContent'] ?? '',
      isCorrect: json['isCorrect'] ?? false,
      isSelected: json['isSelected'] ?? false,
    );
  }
}

class StudentAnswerResult {
  final int studentAnswerId;
  final int questionId;
  final String questionContent;
  final String questionType;
  final String answerType;
  final int maxScore;
  final double? pointsEarned;
  final bool isCorrect;
  final String? textAnswer;
  final String? imageAnswerUrl;
  final String? feedback;
  final String? gradedByName;
  final List<dynamic> selectedOptions; // IDs of selected options if any
  final List<QuestionOptionResult> questionOptions;

  StudentAnswerResult({
    required this.studentAnswerId,
    required this.questionId,
    required this.questionContent,
    required this.questionType,
    required this.answerType,
    required this.maxScore,
    this.pointsEarned,
    required this.isCorrect,
    this.textAnswer,
    this.imageAnswerUrl,
    this.feedback,
    this.gradedByName,
    required this.selectedOptions,
    required this.questionOptions,
  });

  factory StudentAnswerResult.fromJson(Map<String, dynamic> json) {
    return StudentAnswerResult(
      studentAnswerId:
          json['studentAnswerId'] ?? json['id'] ?? json['answerId'] ?? 0,
      questionId: json['questionId'] ?? 0,
      questionContent: json['questionContent'] ?? '',
      questionType: json['questionType'] ?? '',
      answerType: json['answerType'] ?? '',
      maxScore: (json['maxScore'] ??
              json['questionScore'] ??
              json['score'] ??
              json['questionMaxScore'] ??
              0)
          .toInt(),
      pointsEarned: json['pointsEarned']?.toDouble(),
      isCorrect: json['isCorrect'] ?? false,
      textAnswer: json['textAnswer'],
      imageAnswerUrl: json['imageAnswerUrl'],
      feedback: json['feedback'],
      gradedByName: json['gradedByName'],
      selectedOptions: json['selectedOptions'] ?? [],
      questionOptions: json['questionOptions'] != null
          ? (json['questionOptions'] as List)
              .map((e) => QuestionOptionResult.fromJson(e))
              .toList()
          : [],
    );
  }
}

class StudentExamResult {
  final int studentExamResultId;
  final double totalScore;
  final bool isFinished;
  final bool isGraded;
  final DateTime? submittedAt;
  final List<StudentAnswerResult> studentAnswers;
  final String? gradedByName;

  StudentExamResult({
    required this.studentExamResultId,
    required this.totalScore,
    required this.isFinished,
    required this.isGraded,
    this.submittedAt,
    required this.studentAnswers,
    this.gradedByName,
  });

  factory StudentExamResult.fromJson(Map<String, dynamic> json) {
    return StudentExamResult(
      studentExamResultId: json['studentExamResultId'] ?? 0,
      totalScore: (json['totalScore'] ?? 0).toDouble(),
      isFinished: json['isFinished'] ?? false,
      isGraded: json['isGraded'] ?? false,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'])
          : null,
      studentAnswers: json['studentAnswers'] != null
          ? (json['studentAnswers'] as List)
              .map((e) => StudentAnswerResult.fromJson(e))
              .toList()
          : [],
      gradedByName: json['gradedByName'],
    );
  }
}

class ExamSubmission {
  final int studentExamResultId;
  final int studentId;
  final String studentName;
  final String? studentEmail;
  final int examId;
  final String examTitle;
  final double currentTotalScore;
  final int maxScore;
  final bool isFinished;
  final DateTime? submittedAt;
  final int totalAnswers;
  final int manuallyGradedAnswers;
  final int pendingGradingAnswers;
  final String? parentPhoneNumber;
  final String? studentPhoneNumber;
  final String? gradedByName;

  ExamSubmission({
    required this.studentExamResultId,
    required this.studentId,
    required this.studentName,
    this.studentEmail,
    required this.examId,
    required this.examTitle,
    required this.currentTotalScore,
    required this.maxScore,
    required this.isFinished,
    this.submittedAt,
    required this.totalAnswers,
    required this.manuallyGradedAnswers,
    required this.pendingGradingAnswers,
    this.parentPhoneNumber,
    this.studentPhoneNumber,
    this.gradedByName,
  });

  factory ExamSubmission.fromJson(Map<String, dynamic> json) {
    return ExamSubmission(
      studentExamResultId: json['studentExamResultId'] ?? 0,
      studentId: json['studentId'] ?? 0,
      studentName: json['studentName'] ?? '',
      studentEmail: json['studentEmail'],
      examId: json['examId'] ?? 0,
      examTitle: json['examTitle'] ?? '',
      currentTotalScore: (json['currentTotalScore'] ?? 0).toDouble(),
      maxScore: (json['maxScore'] ??
              json['examMaxScore'] ??
              json['totalMaxScore'] ??
              0)
          .toInt(),
      isFinished: json['isFinished'] ?? false,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'])
          : null,
      totalAnswers: json['totalAnswers'] ?? 0,
      manuallyGradedAnswers: json['manuallyGradedAnswers'] ?? 0,
      pendingGradingAnswers: json['pendingGradingAnswers'] ?? 0,
      parentPhoneNumber: json['parentPhoneNumber'],
      studentPhoneNumber: json['studentPhoneNumber'],
      gradedByName: json['gradedByName'] ?? json['teacherName'],
    );
  }
}

class GradedAnswerRequest {
  final int studentAnswerId;
  final double pointsEarned;
  final bool isCorrect;
  final String? feedback;

  GradedAnswerRequest({
    required this.studentAnswerId,
    required this.pointsEarned,
    required this.isCorrect,
    this.feedback,
  });

  Map<String, dynamic> toJson() => {
        'studentAnswerId': studentAnswerId,
        'pointsEarned': pointsEarned,
        'isCorrect': isCorrect,
        if (feedback != null) 'feedback': feedback,
      };
}

class GradeExamRequest {
  final int studentExamResultId;
  final List<GradedAnswerRequest> gradedAnswers;
  final String command;

  GradeExamRequest({
    required this.studentExamResultId,
    required this.gradedAnswers,
    this.command = 'GradeExam',
  });

  Map<String, dynamic> toJson() => {
        'command': command,
        'studentExamResultId': studentExamResultId,
        'gradedAnswers': gradedAnswers.map((x) => x.toJson()).toList(),
      };
}

class GradeExamResponse {
  final int studentExamResultId;
  final double previousTotalScore;
  final double newTotalScore;
  final double pointsFromManualGrading;
  final String message;

  GradeExamResponse({
    required this.studentExamResultId,
    required this.previousTotalScore,
    required this.newTotalScore,
    required this.pointsFromManualGrading,
    required this.message,
  });

  factory GradeExamResponse.fromJson(Map<String, dynamic> json) {
    return GradeExamResponse(
      studentExamResultId: json['studentExamResultId'] ?? 0,
      previousTotalScore: (json['previousTotalScore'] ?? 0).toDouble(),
      newTotalScore: (json['newTotalScore'] ?? 0).toDouble(),
      pointsFromManualGrading:
          (json['pointsFromManualGrading'] ?? 0).toDouble(),
      message: json['message'] ?? '',
    );
  }
}

class EnrolledStudent {
  final int studentId;
  final String studentName;
  final String studentEmail;
  final String? parentPhoneNumber;
  final int courseId;
  final String courseName;
  final String status;
  final DateTime subscribedAt;

  EnrolledStudent({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.parentPhoneNumber,
    required this.courseId,
    required this.courseName,
    required this.status,
    required this.subscribedAt,
  });

  factory EnrolledStudent.fromJson(Map<String, dynamic> json) {
    return EnrolledStudent(
      studentId: json['studentId'] ?? 0,
      studentName: json['studentName'] ?? '',
      studentEmail: json['studentEmail'] ?? '',
      parentPhoneNumber: json['parentPhoneNumber'],
      courseId: json['courseId'] ?? 0,
      courseName: json['courseName'] ?? '',
      status: json['status'] ?? '',
      subscribedAt: json['subscribedAt'] != null
          ? DateTime.parse(json['subscribedAt'])
          : DateTime.now(),
    );
  }
}

class DeadlineExceptionRequest {
  final int examId;
  final int studentId;
  final DateTime extendedDeadline;
  final bool allowedAfterDeadline;
  final String? reason;

  DeadlineExceptionRequest({
    required this.examId,
    required this.studentId,
    required this.extendedDeadline,
    this.allowedAfterDeadline = true,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'examId': examId,
      'studentId': studentId,
      'extendedDeadline': extendedDeadline.toIso8601String(),
      'allowedAfterDeadline': allowedAfterDeadline,
      if (reason != null) 'reason': reason,
    };
  }
}

class ExamAccessResponse {
  final int examId;
  final int studentId;
  final bool hasException;
  final DateTime? deadline;
  final DateTime? extendedDeadline;
  final String? reason;
  final String message;

  ExamAccessResponse({
    required this.examId,
    required this.studentId,
    required this.hasException,
    this.deadline,
    this.extendedDeadline,
    this.reason,
    required this.message,
  });

  factory ExamAccessResponse.fromJson(Map<String, dynamic> json) {
    // Parse extendedDeadline first
    final parsedExtendedDeadline = json['extendedDeadline'] != null
        ? DateTime.tryParse(json['extendedDeadline'])
        : null;

    // Infer hasException: if extendedDeadline exists, student has exception
    final inferredHasException =
        json['hasException'] ?? (parsedExtendedDeadline != null);

    return ExamAccessResponse(
      examId: json['examId'] ?? 0,
      studentId: json['studentId'] ?? 0,
      hasException: inferredHasException,
      deadline:
          json['deadline'] != null ? DateTime.tryParse(json['deadline']) : null,
      extendedDeadline: parsedExtendedDeadline,
      reason: json['reason'],
      message: json['message'] ?? '',
    );
  }

  /// Helper method to check if student can access the exam
  bool get canAccess {
    if (hasException) {
      // If has exception, check the extendedDeadline
      if (extendedDeadline != null) {
        return DateTime.now().isBefore(extendedDeadline!);
      }
      // If no extendedDeadline specified, allow access
      return true;
    }

    // If no exception, check if original deadline has passed
    if (deadline != null) {
      return DateTime.now().isBefore(deadline!);
    }

    // No deadline means always accessible
    return true;
  }

  /// Get the effective deadline (extendedDeadline if has exception, otherwise original deadline)
  DateTime? get effectiveDeadline {
    if (hasException && extendedDeadline != null) {
      return extendedDeadline;
    }
    return deadline;
  }
}

class StudentCourseScore {
  final int courseId;
  final String courseName;
  final int studentId;
  final double totalScore;
  final int maxScore;
  final double percentage;
  final int examsCount;
  final int completedExamsCount;

  StudentCourseScore({
    required this.courseId,
    required this.courseName,
    required this.studentId,
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.examsCount,
    required this.completedExamsCount,
  });

  factory StudentCourseScore.fromJson(Map<String, dynamic> json) {
    return StudentCourseScore(
      courseId: json['courseId'] ?? 0,
      courseName: json['courseName'] ?? '',
      studentId: json['studentId'] ?? 0,
      totalScore: (json['totalScore'] ?? 0).toDouble(),
      maxScore: json['maxScore'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
      examsCount: json['examsCount'] ?? 0,
      completedExamsCount: json['completedExamsCount'] ?? 0,
    );
  }
}

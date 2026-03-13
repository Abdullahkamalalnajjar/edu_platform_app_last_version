class ApiConstants {
  static const String baseUrl = 'https://bosla-education.com/api';

  // Auth Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Auth Endpoints
  static const String signin = '$baseUrl/api/v1/auth/signin';
  static const String signup = '$baseUrl/api/v1/auth/signup';
  static const String googleSignin = '$baseUrl/api/v1/google/signin';
  static const String getRoles = '$baseUrl/GetRoles';
  static const String subjects = '$baseUrl/api/v1/subjects';
  static const String editSubject = '$baseUrl/api/v1/subjects/Edit';
  static String getSubjectById(int id) => '$baseUrl/api/v1/subjects/$id';
  static String deleteSubject(int id) => '$baseUrl/api/v1/subjects/$id';
  static const String educationStages = '$baseUrl/api/v1/education-stages';
  static const String governorates = '$baseUrl/governorates';
  static const String courses = '$baseUrl/api/v1/courses';
  static String getCourseById(int id) => '$baseUrl/api/v1/courses/$id';
  static const String lectures = '$baseUrl/api/v1/lectures';
  static const String materials = '$baseUrl/api/v1/lectures/materials';
  static const String courseSubscriptions =
      '$baseUrl/api/v1/course-subscriptions';
  static const String exams = '$baseUrl/api/v1/exams';
  static const String examQuestions = '$baseUrl/api/v1/exams/questions';
  static const String questionOptions = '$baseUrl/api/v1/question-options';

  static const String studentAnswersImage =
      '$baseUrl/api/v1/student-answers/image';

  // Update student answer image (for teacher editing during grading)
  static String updateStudentAnswerImage(int studentAnswerId) =>
      '$baseUrl/api/v1/student-answers/$studentAnswerId/image';

  static const String studentExamResults =
      '$baseUrl/api/v1/student-exam-results';

  static String startExamUrl(int examId) =>
      '$baseUrl/api/v1/exams/$examId/start';

  static String getLectureExam(int lectureId) =>
      '$baseUrl/api/v1/lectures/$lectureId/exam';

  static String getExamSubmissions(int lectureId) =>
      '$baseUrl/api/v1/lectures/$lectureId/exam-submissions';

  static const String gradeExam = '$baseUrl/api/v1/exams/grade';

  static String getSubmissionsByExamId(int examId) =>
      '$baseUrl/api/v1/exams/$examId/submissions';

  // Get exam by ID
  static String getExamById(int examId) => '$baseUrl/api/v1/exams/$examId';

  // Deadline Exception Endpoints
  static const String createDeadlineException =
      '$baseUrl/api/v1/exams/deadline-exception';

  static String checkExamAccess(int examId, int studentId) =>
      '$baseUrl/api/v1/exams/$examId/students/$studentId/access';

  static String getMyStudents(int userId) => '$baseUrl/MyStudents/$userId';

  // Admin Endpoints
  static const String adminStudents = '$baseUrl/api/v1/Admin/users/students';
  static const String adminTeachers = '$baseUrl/api/v1/Admin/users/teachers';
  static const String adminParents = '$baseUrl/api/v1/Admin/users/parents';
  static const String approveTeacher = '$baseUrl/ApproveTeacher';
  static const String toggleBlockUser = '$baseUrl/ToggleBlockUser';
  static String deleteUser(String userId) => '$baseUrl/DeleteUser/$userId';
  static const String adminStatistics = '$baseUrl/api/v1/Admin/statistics';

  // Session Management Endpoints (Correct API paths)
  static String getActiveSessions(String userId, {String? currentDeviceId}) {
    String url = '$baseUrl/active-sessions/$userId';
    if (currentDeviceId != null) {
      url += '?currentDeviceId=$currentDeviceId';
    }
    return url;
  }

  static const String logoutDevice = '$baseUrl/logout-device';
  static const String logoutAllDevices = '$baseUrl/logout-all-devices';

  // Password Management
  static const String changePassword = '$baseUrl/api/v1/auth/change-password';

  // Forgot Password Flow
  static String sendOtp(String email) =>
      '$baseUrl/api/v1/auth/send-otp?email=$email';
  static const String verifyOtp = '$baseUrl/api/v1/auth/verify-otp';
  static const String resetPassword = '$baseUrl/api/v1/auth/reset-password';

  // FCM Token Management
  static const String updateFcmToken = '$baseUrl/api/v1/auth/update-fcm-token';

  // Notifications
  static String getUserNotifications(String userId, {bool? isRead}) {
    String url = '$baseUrl/api/v1/Notification/$userId';
    if (isRead != null) {
      url += '?isRead=$isRead';
    }
    return url;
  }

  static String getUnreadNotifications(String userId) =>
      '$baseUrl/api/v1/Notification/$userId/unread';

  static String getAllUserNotifications(String userId) =>
      '$baseUrl/api/v1/Notification/$userId/all';

  static String markNotificationAsRead(int notificationId) =>
      '$baseUrl/api/v1/Notification/$notificationId/mark-as-read';

  static String markAllNotificationsAsRead(String userId) =>
      '$baseUrl/api/v1/Notification/$userId/read-all';

  static String deleteAllNotifications(String userId) =>
      '$baseUrl/api/v1/Notification/user/$userId/all';

  static String deleteNotification(int id, String userId) =>
      '$baseUrl/api/v1/Notification/$id?userId=$userId';

  static const String updateStudentProfile = '$baseUrl/api/v1/students/profile';
  static const String updateTeacherProfile = '$baseUrl/api/v1/teachers/profile';

  static const String createStudentProfile =
      '$baseUrl/api/v1/students/create-profile';
  static const String createTeacherProfile =
      '$baseUrl/api/v1/teachers/create-profile';

  static String getStudentProfile(String userGuid) =>
      '$baseUrl/api/v1/students/profile/$userGuid';

  // Settings
  static const String aboutUs = '$baseUrl/api/v1/settings/about-us';
  static const String updateAppInfo = '$baseUrl/api/v1/settings/app-info';
  static const String applicationUrl =
      '$baseUrl/api/v1/settings/application-url';
  static const String explanationVideo =
      '$baseUrl/api/v1/settings/explanation-video';
  static const String supportPhone = '$baseUrl/api/v1/settings/support-phone';
  static const String version = '$baseUrl/api/v1/settings/version';
  static const String googleLoginEnabled =
      '$baseUrl/api/v1/settings/google-enable';
  static const String deleteAccountEnabled =
      'https://bosla-education.com/api/api/v1/settings/btn-delete-account-enabled';
  static const String iconPricerEnabled =
      '$baseUrl/api/v1/settings/icon-pricer-enabled';
}

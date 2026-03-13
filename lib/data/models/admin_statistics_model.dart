/// Model class for Admin Statistics API response
class AdminStatisticsModel {
  final int totalTeachers;
  final int totalRegisteredUsers;
  final int totalParents;
  final int totalStudents;
  final int totalExams;
  final int totalCourses;
  final String teachersChangeMessage;
  final String registeredUsersChangeMessage;
  final String parentsChangeMessage;
  final String studentsChangeMessage;
  final String examsChangeMessage;
  final String coursesChangeMessage;

  AdminStatisticsModel({
    required this.totalTeachers,
    required this.totalRegisteredUsers,
    required this.totalParents,
    required this.totalStudents,
    required this.totalExams,
    required this.totalCourses,
    required this.teachersChangeMessage,
    required this.registeredUsersChangeMessage,
    required this.parentsChangeMessage,
    required this.studentsChangeMessage,
    required this.examsChangeMessage,
    required this.coursesChangeMessage,
  });

  factory AdminStatisticsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatisticsModel(
      totalTeachers: json['totalTeachers'] ?? 0,
      totalRegisteredUsers: json['totalRegisteredUsers'] ?? 0,
      totalParents: json['totalParents'] ?? 0,
      totalStudents: json['totalStudents'] ?? 0,
      totalExams: json['totalExams'] ?? 0,
      totalCourses: json['totalCourses'] ?? 0,
      teachersChangeMessage: json['teachersChangeMessage'] ?? '',
      registeredUsersChangeMessage: json['registeredUsersChangeMessage'] ?? '',
      parentsChangeMessage: json['parentsChangeMessage'] ?? '',
      studentsChangeMessage: json['studentsChangeMessage'] ?? '',
      examsChangeMessage: json['examsChangeMessage'] ?? '',
      coursesChangeMessage: json['coursesChangeMessage'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTeachers': totalTeachers,
      'totalRegisteredUsers': totalRegisteredUsers,
      'totalParents': totalParents,
      'totalStudents': totalStudents,
      'totalExams': totalExams,
      'totalCourses': totalCourses,
      'teachersChangeMessage': teachersChangeMessage,
      'registeredUsersChangeMessage': registeredUsersChangeMessage,
      'parentsChangeMessage': parentsChangeMessage,
      'studentsChangeMessage': studentsChangeMessage,
      'examsChangeMessage': examsChangeMessage,
      'coursesChangeMessage': coursesChangeMessage,
    };
  }
}

class ParentAdminModel {
  final int parentId;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String parentPhoneNumber;
  final int childrenCount;

  ParentAdminModel({
    required this.parentId,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.parentPhoneNumber,
    required this.childrenCount,
  });

  factory ParentAdminModel.fromJson(Map<String, dynamic> json) {
    return ParentAdminModel(
      parentId: json['parentId'] ?? 0,
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      fullName: json['fullName'] ?? '',
      parentPhoneNumber: json['parentPhoneNumber'] ?? '',
      childrenCount: json['childrenCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parentId': parentId,
      'userId': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'parentPhoneNumber': parentPhoneNumber,
      'childrenCount': childrenCount,
    };
  }
}

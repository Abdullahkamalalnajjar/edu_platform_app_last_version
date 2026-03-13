class AuthResponse {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String token;
  final bool isDisable;
  final int tokenExpiresIn;
  final String refreshToken;
  final String refreshTokenExpiresIn;
  final List<String> roles;
  final String? applicationUserId;
  final int? userId;
  final String? phoneNumber;
  final String? facebookUrl;
  final String? telegramUrl;
  final String? whatsAppNumber;
  final String? photoUrl;
  final String? youTubeChannelUrl;
  final int? teacherId;
  final String? governorate;
  final String? city;
  final bool isProfileComplete;

  AuthResponse({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.token,
    required this.isDisable,
    required this.tokenExpiresIn,
    required this.refreshToken,
    required this.refreshTokenExpiresIn,
    this.roles = const [],
    this.applicationUserId,
    this.userId,
    this.phoneNumber,
    this.facebookUrl,
    this.telegramUrl,
    this.whatsAppNumber,
    this.photoUrl,
    this.youTubeChannelUrl,
    this.teacherId,
    this.governorate,
    this.city,
    this.isProfileComplete = true,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      token: json['token'] ?? '',
      isDisable: json['isDisable'] ?? false,
      tokenExpiresIn: json['tokenExpiresIn'] ?? 0,
      refreshToken: json['refreshToken'] ?? '',
      refreshTokenExpiresIn: json['refreshTokenExpiresIn'] ?? '',
      roles: json['roles'] != null ? List<String>.from(json['roles']) : [],
      applicationUserId: json['applicationUserId'],
      userId: json['userId'] ?? json['UserId'],
      phoneNumber: json['phoneNumber'],
      facebookUrl: json['facebookUrl'],
      telegramUrl: json['telegramUrl'],
      whatsAppNumber: json['whatsAppNumber'],
      photoUrl: json['photoUrl'],
      youTubeChannelUrl: json['youTubeChannelUrl'],
      teacherId: json['teacherId'] ?? json['TeacherId'],
      governorate: json['governorate'],
      city: json['city'],
      isProfileComplete: json['isProfileComplete'] ?? false,
    );
  }
}

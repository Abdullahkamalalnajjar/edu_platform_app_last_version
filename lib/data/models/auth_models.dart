class LoginRequest {
  final String email;
  final String password;
  final String? deviceId;
  final String? deviceName;
  final String? fcmToken;
  final bool forceLogin; // Force logout from other devices

  LoginRequest({
    required this.email,
    required this.password,
    this.deviceId,
    this.deviceName,
    this.fcmToken,
    this.forceLogin = false,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'email': email,
      'password': password,
      'forceLogin': forceLogin,
    };
    if (deviceId != null) json['deviceId'] = deviceId;
    if (deviceName != null) json['deviceName'] = deviceName;
    if (fcmToken != null) json['fcmToken'] = fcmToken;
    return json;
  }
}

class SignupRequest {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String role;
  final int? gradeYear;
  final String? phoneNumber;
  final String? facebookUrl;
  final String? telegramUrl;
  final String? whatsAppNumber;
  final String? parentPhoneNumber;
  final int? subjectId;
  final String? nationalId;
  final int? teacherId;
  final List<int>? educationStageIds;
  final String? photoPath;
  final String? youTubeChannelUrl;
  final String? studentNumber;
  final String? governorate;
  final String? city;

  SignupRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    this.role = "Student",
    this.gradeYear,
    this.parentPhoneNumber,
    this.subjectId,
    this.nationalId,
    this.teacherId,
    this.educationStageIds,
    this.phoneNumber,
    this.facebookUrl,
    this.telegramUrl,
    this.whatsAppNumber,
    this.photoPath,
    this.youTubeChannelUrl,
    this.studentNumber,
    this.governorate,
    this.city,
  });

  Map<String, String> toFields() {
    final Map<String, String> fields = {
      'Email': email,
      'Password': password,
      'FirstName': firstName,
      'LastName': lastName,
      'Role': role,
    };

    if (gradeYear != null) fields['GradeYear'] = gradeYear.toString();
    if (parentPhoneNumber != null)
      fields['ParentPhoneNumber'] = parentPhoneNumber!;
    if (subjectId != null) fields['SubjectId'] = subjectId.toString();
    if (nationalId != null) fields['NationalId'] = nationalId!;
    if (teacherId != null) fields['TeacherId'] = teacherId.toString();
    if (studentNumber != null) fields['StudentNumber'] = studentNumber!;

    // Arrays need special handling in multipart usually, but often [0],[1] or just same key
    // For now we will handle list in service loop

    if (phoneNumber != null) fields['PhoneNumber'] = phoneNumber!;
    if (facebookUrl != null) fields['FacebookUrl'] = facebookUrl!;
    if (telegramUrl != null) fields['TelegramUrl'] = telegramUrl!;
    if (whatsAppNumber != null) fields['WhatsAppNumber'] = whatsAppNumber!;
    if (youTubeChannelUrl != null)
      fields['YouTubeChannelUrl'] = youTubeChannelUrl!;
    if (governorate != null) fields['Governorate'] = governorate!;
    if (city != null) fields['City'] = city!;

    return fields;
  }

  // Old toJson for JSON based requests (if needed)
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'gradeYear': gradeYear,
      'parentPhoneNumber': parentPhoneNumber,
      'subjectId': subjectId,
      'nationalId': nationalId,
      'teacherId': teacherId,
      'educationStageIds': educationStageIds,
      'phoneNumber': phoneNumber,
      'facebookUrl': facebookUrl,
      'telegramUrl': telegramUrl,
      'whatsAppNumber': whatsAppNumber,
      'youTubeChannelUrl': youTubeChannelUrl,
      'studentNumber': studentNumber,
      'governorate': governorate,
      'city': city,
    };
  }
}

class EditUserProfileRequest {
  final String userId;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String? facebookUrl;
  final String? telegramUrl;
  final String? youTubeChannelUrl;
  final String? whatsAppNumber;
  final String? photoPath;

  EditUserProfileRequest({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.facebookUrl,
    this.telegramUrl,
    this.youTubeChannelUrl,
    this.whatsAppNumber,
    this.photoPath,
  });

  Map<String, String> toFields() {
    final Map<String, String> fields = {
      'UserId': userId,
      'FirstName': firstName,
      'LastName': lastName,
    };
    if (phoneNumber != null) fields['PhoneNumber'] = phoneNumber!;
    if (facebookUrl != null) fields['FacebookUrl'] = facebookUrl!;
    if (telegramUrl != null) fields['TelegramUrl'] = telegramUrl!;
    if (youTubeChannelUrl != null)
      fields['YouTubeChannelUrl'] = youTubeChannelUrl!;
    if (whatsAppNumber != null) fields['WhatsAppNumber'] = whatsAppNumber!;
    return fields;
  }
}

class ChangePasswordRequest {
  final String id;
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;

  ChangePasswordRequest({
    required this.id,
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    };
  }
}

class VerifyOtpRequest {
  final String email;
  final String otp;

  VerifyOtpRequest({required this.email, required this.otp});

  Map<String, dynamic> toJson() {
    return {'email': email, 'otp': otp};
  }
}

class ResetPasswordRequest {
  final String email;
  final String newPassword;

  ResetPasswordRequest({required this.email, required this.newPassword});

  Map<String, dynamic> toJson() {
    return {'email': email, 'newPassword': newPassword};
  }
}

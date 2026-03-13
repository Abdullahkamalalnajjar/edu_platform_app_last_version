/// Model for an active session
class ActiveSession {
  final int sessionId;
  final String deviceId;
  final String deviceName;
  final String? ipAddress;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  final DateTime expiresAt;
  final bool isCurrentSession;

  ActiveSession({
    required this.sessionId,
    required this.deviceId,
    required this.deviceName,
    this.ipAddress,
    required this.createdAt,
    required this.lastActivityAt,
    required this.expiresAt,
    required this.isCurrentSession,
  });

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      sessionId: json['sessionId'] ?? 0,
      deviceId: json['deviceId'] ?? '',
      deviceName: json['deviceName'] ?? 'جهاز غير معروف',
      ipAddress: json['ipAddress'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      lastActivityAt:
          DateTime.tryParse(json['lastActivityAt'] ?? '') ?? DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expiresAt'] ?? '') ??
          DateTime.now().add(const Duration(days: 14)),
      isCurrentSession: json['isCurrentSession'] ?? false,
    );
  }
}

/// Response model for active sessions list
class ActiveSessionsResponse {
  final String userId;
  final String email;
  final int totalActiveSessions;
  final List<ActiveSession> activeSessions;

  ActiveSessionsResponse({
    required this.userId,
    required this.email,
    required this.totalActiveSessions,
    required this.activeSessions,
  });

  factory ActiveSessionsResponse.fromJson(Map<String, dynamic> json) {
    return ActiveSessionsResponse(
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      totalActiveSessions: json['totalActiveSessions'] ?? 0,
      activeSessions: json['activeSessions'] != null
          ? (json['activeSessions'] as List)
                .map((e) => ActiveSession.fromJson(e))
                .toList()
          : [],
    );
  }
}

/// Request to logout from a specific device
class LogoutDeviceRequest {
  final String userId;
  final int sessionId;

  LogoutDeviceRequest({required this.userId, required this.sessionId});

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'sessionId': sessionId};
  }
}

/// Request to logout from all devices
class LogoutAllDevicesRequest {
  final String userId;

  LogoutAllDevicesRequest({required this.userId});

  Map<String, dynamic> toJson() {
    return {'userId': userId};
  }
}

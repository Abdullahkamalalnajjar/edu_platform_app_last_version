import '../../../data/services/auth_service.dart';
import '../../../data/services/token_service.dart';
import '../../../data/services/assistant_service.dart';
import '../../../data/services/google_signin_service.dart';

class GoogleLoginResult {
  final bool success;
  final String? message;
  final String? role;
  final String? userName;
  final int? userId; // Int ID
  final int? teacherId; // Teacher ID
  final String? userGuid; // GUID from Identity
  final bool isProfileComplete;
  final bool isDisabled;
  final List<String> roles;

  GoogleLoginResult({
    required this.success,
    this.message,
    this.role,
    this.userName,
    this.userId,
    this.teacherId,
    this.userGuid,
    this.isProfileComplete = false,
    this.isDisabled = false,
    this.roles = const [],
  });
}

class GoogleLoginUseCase {
  final GoogleSignInService _googleSignInService;
  final AuthService _authService;
  final TokenService _tokenService;
  final AssistantService _assistantService;

  GoogleLoginUseCase({
    GoogleSignInService? googleSignInService,
    AuthService? authService,
    TokenService? tokenService,
    AssistantService? assistantService,
  }) : _googleSignInService = googleSignInService ?? GoogleSignInService(),
       _authService = authService ?? AuthService(),
       _tokenService = tokenService ?? TokenService(),
       _assistantService = assistantService ?? AssistantService();

  Future<GoogleLoginResult> execute() async {
    try {
      // 1. Get Google ID Token
      final idToken = await _googleSignInService.signInWithGoogle();

      if (idToken == null) {
        return GoogleLoginResult(
          success: false,
          message: 'User canceled sign-in or configuration error.',
        );
      }

      print('Google ID Token: $idToken'); // Debug: Show ID Token

      // 2. Authenticate with Backend
      final response = await _authService.signInWithGoogle(idToken);

      if (response.succeeded && response.data != null) {
        final data = response.data!;

        print('UseCase Debug: Parsed Response Data:');
        print(' - Token: ${data.token.substring(0, 10)}...');
        print(' - UserId (int): ${data.userId}');
        print(' - ApplicationUserId (GUID): ${data.applicationUserId}');
        print(' - ID (Data.id): ${data.id}');
        print(' - Roles: ${data.roles}');
        print(' - IsProfileComplete: ${data.isProfileComplete}');

        // 3. Save Session Data
        await _tokenService.saveToken(data.token);
        await _tokenService.saveRefreshToken(data.refreshToken);
        if (data.userId != null) {
          await _tokenService.saveUserId(data.userId!);
        }
        await _tokenService.saveUserGuid(data.applicationUserId ?? data.id);

        await _tokenService.saveUserInfo(
          name: '${data.firstName} ${data.lastName}',
          email: data.email,
        );

        await _tokenService.saveExtendedUserInfo(
          photoUrl: data.photoUrl,
          phoneNumber: data.phoneNumber,
          facebookUrl: data.facebookUrl,
          telegramUrl: data.telegramUrl,
          whatsAppNumber: data.whatsAppNumber,
          youTubeChannelUrl: data.youTubeChannelUrl,
        );

        if (data.teacherId != null) {
          await _tokenService.saveTeacherId(data.teacherId!);
        } else if (data.roles.contains('Assistant')) {
          try {
            final assistantResp = await _assistantService.getAssistantByUserId(
              data.id,
            );
            if (assistantResp.succeeded && assistantResp.data != null) {
              await _tokenService.saveTeacherId(assistantResp.data!.teacherId);
            }
          } catch (e) {
            print('Error fetching assistant details: $e');
          }
        }

        // 4. Determine User Role for Navigation
        String? roleToSave;
        final roles = data.roles;
        if (roles.isNotEmpty) {
          if (roles.contains('Admin')) {
            roleToSave = 'Admin';
          } else if (roles.contains('Teacher')) {
            roleToSave = 'Teacher';
          } else if (roles.contains('Assistant')) {
            roleToSave = 'Assistant';
          } else if (roles.contains('Student')) {
            roleToSave = 'Student';
          } else if (roles.contains('Parent')) {
            roleToSave = 'Parent';
          }
          if (roleToSave != null) {
            await _tokenService.saveRole(roleToSave);
          }
        } else {
          // No roles found
          print('No roles found for user');
        }

        return GoogleLoginResult(
          success: true,
          role: roleToSave,
          userName: data.firstName,
          userId: data.userId,
          teacherId: data.teacherId,
          userGuid: data.id,
          isProfileComplete: data.isProfileComplete,
          isDisabled: data.isDisable, // Map from AuthResponse
          roles: roles,
        );
      } else {
        return GoogleLoginResult(success: false, message: response.message);
      }
    } catch (e) {
      return GoogleLoginResult(
        success: false,
        message: 'An error occurred during Google Login: $e',
      );
    }
  }
}

import 'package:flutter/material.dart';
import '../../data/services/token_service.dart';
import '../screens/auth/login_screen.dart';

/// A widget that checks if the user is authenticated before showing the child widget.
/// If not authenticated, redirects to login screen.
class AuthGuard extends StatefulWidget {
  final Widget child;
  final Widget? loadingWidget;

  const AuthGuard({super.key, required this.child, this.loadingWidget});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  final TokenService _tokenService = TokenService();
  bool _isChecking = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final token = await _tokenService.getToken();

    if (mounted) {
      setState(() {
        _isAuthenticated = token != null && token.isNotEmpty;
        _isChecking = false;
      });

      if (!_isAuthenticated) {
        // Redirect to login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return widget.loadingWidget ??
          const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAuthenticated) {
      return widget.child;
    }

    // Show loading while redirecting
    return widget.loadingWidget ??
        const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Mixin to add auth check functionality to any StatefulWidget
mixin AuthCheckMixin<T extends StatefulWidget> on State<T> {
  final TokenService _authTokenService = TokenService();

  /// Check if user is authenticated, redirect to login if not
  Future<bool> checkAuth() async {
    final token = await _authTokenService.getToken();

    if (token == null || token.isEmpty) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      return false;
    }

    return true;
  }

  /// Get current user role
  Future<String?> getCurrentRole() async {
    return await _authTokenService.getRole();
  }

  /// Get current user ID
  Future<String?> getCurrentUserId() async {
    return await _authTokenService.getUserGuid();
  }
}

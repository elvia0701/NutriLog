abstract interface class AuthService {
  bool get hasSession;

  String? get currentUserEmail;

  Stream<bool> get authStateChanges;

  Future<void> signIn({required String email, required String password});

  Future<SignUpResult> signUp({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class SignUpResult {
  final bool requiresEmailConfirmation;

  const SignUpResult({required this.requiresEmailConfirmation});
}

class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => message;
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

enum AuthOperation { signIn, signUp, signOut }

class SupabaseAuthService implements AuthService {
  final SupabaseClient _client;

  SupabaseAuthService(this._client);

  @override
  bool get hasSession => _client.auth.currentSession != null;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  Stream<bool> get authStateChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      _debugPrintAuthException(error, AuthOperation.signIn);
      throw mapSupabaseAuthError(
        message: error.message,
        statusCode: error.statusCode,
        code: error.code,
        operation: AuthOperation.signIn,
      );
    } catch (error) {
      _debugPrintNonAuthError(error, AuthOperation.signIn);
      throw mapUnexpectedAuthError(error, AuthOperation.signIn);
    }
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      return SignUpResult(requiresEmailConfirmation: response.session == null);
    } on AuthException catch (error) {
      _debugPrintAuthException(error, AuthOperation.signUp);
      throw mapSupabaseAuthError(
        message: error.message,
        statusCode: error.statusCode,
        code: error.code,
        operation: AuthOperation.signUp,
      );
    } catch (error) {
      _debugPrintNonAuthError(error, AuthOperation.signUp);
      throw mapUnexpectedAuthError(error, AuthOperation.signUp);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      _debugPrintAuthException(error, AuthOperation.signOut);
      throw mapSupabaseAuthError(
        message: error.message,
        statusCode: error.statusCode,
        code: error.code,
        operation: AuthOperation.signOut,
      );
    } catch (error) {
      _debugPrintNonAuthError(error, AuthOperation.signOut);
      throw mapUnexpectedAuthError(error, AuthOperation.signOut);
    }
  }
}

AuthFailure mapSupabaseAuthError({
  required String message,
  required Object? statusCode,
  required Object? code,
  required AuthOperation operation,
}) {
  final normalizedMessage = message.toLowerCase();
  final normalizedCode = code?.toString().toLowerCase() ?? '';
  final normalizedStatus = statusCode?.toString() ?? '';

  bool matchesCode(String value) => normalizedCode == value;
  bool messageContains(String value) => normalizedMessage.contains(value);

  if (matchesCode('invalid_credentials') ||
      messageContains('invalid login credentials') ||
      messageContains('invalid credentials')) {
    return const AuthFailure('Email 或密碼不正確，請重新輸入。');
  }
  if (matchesCode('email_not_confirmed') ||
      messageContains('email not confirmed')) {
    return const AuthFailure('此 Email 尚未完成驗證，請先至信箱完成驗證後再登入。');
  }
  if (matchesCode('user_already_exists') ||
      matchesCode('email_exists') ||
      messageContains('already registered') ||
      messageContains('already exists')) {
    return const AuthFailure('此 Email 已經註冊，請直接登入。');
  }
  if (matchesCode('weak_password') ||
      (messageContains('password') &&
          (messageContains('least') || messageContains('weak')))) {
    return const AuthFailure('密碼不符合此專案的安全要求，請增加密碼長度或複雜度。');
  }
  if (matchesCode('signup_disabled') ||
      matchesCode('email_provider_disabled') ||
      messageContains('signups not allowed') ||
      messageContains('signup is disabled')) {
    return const AuthFailure('目前暫停開放新帳號註冊，請聯絡管理者。');
  }
  if (matchesCode('over_email_send_rate_limit') ||
      (normalizedStatus == '429' && operation == AuthOperation.signUp) ||
      messageContains('email rate limit')) {
    return const AuthFailure('驗證信寄送次數過多，請稍候一段時間後再試。');
  }
  if (matchesCode('over_request_rate_limit') ||
      messageContains('too many requests')) {
    return const AuthFailure('操作次數過多，請稍候幾分鐘後再試。');
  }
  if (matchesCode('email_address_invalid')) {
    return const AuthFailure('此 Email 無法用於註冊，請確認地址後再試。');
  }
  if (matchesCode('email_address_not_authorized')) {
    return const AuthFailure('目前的寄信設定無法寄送驗證信到此 Email，請聯絡管理者設定自訂 SMTP。');
  }
  if (matchesCode('captcha_failed')) {
    return const AuthFailure('安全驗證未完成，請聯絡管理者確認 CAPTCHA 設定。');
  }
  if (matchesCode('validation_failed')) {
    return const AuthFailure('註冊資料格式不符合要求，請確認 Email 與密碼後再試。');
  }
  if (matchesCode('invalid_api_key') ||
      messageContains('invalid api key') ||
      messageContains('no api key found')) {
    return const AuthFailure('Supabase 專案 URL 與 anon key 不相符，請重新檢查啟動設定。');
  }
  if (messageContains('invalid path specified in request url')) {
    return const AuthFailure(
      'SUPABASE_URL 不是專案根網址，請移除 /rest/v1、/auth/v1 或其他路徑。',
    );
  }
  if (_looksLikeNetworkError(normalizedMessage, normalizedCode)) {
    return const AuthFailure('無法連線到 Supabase，請檢查網路與專案設定後再試。');
  }

  return switch (operation) {
    AuthOperation.signUp => const AuthFailure('註冊暫時無法完成，請稍後再試。'),
    AuthOperation.signIn => const AuthFailure('登入暫時無法完成，請稍後再試。'),
    AuthOperation.signOut => const AuthFailure('登出暫時無法完成，請稍後再試。'),
  };
}

AuthFailure mapUnexpectedAuthError(Object error, AuthOperation operation) {
  final message = error.toString().toLowerCase();
  if (_looksLikeNetworkError(message, '')) {
    return const AuthFailure('無法連線到 Supabase，請檢查網路與專案設定後再試。');
  }

  return switch (operation) {
    AuthOperation.signUp => const AuthFailure('註冊暫時無法完成，請稍後再試。'),
    AuthOperation.signIn => const AuthFailure('登入暫時無法完成，請稍後再試。'),
    AuthOperation.signOut => const AuthFailure('登出暫時無法完成，請稍後再試。'),
  };
}

bool _looksLikeNetworkError(String message, String code) {
  return code == 'network_error' ||
      code == 'request_timeout' ||
      message.contains('failed to fetch') ||
      message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('connection refused') ||
      message.contains('connection reset') ||
      message.contains('clientexception') ||
      message.contains('xmlhttprequest error');
}

void _debugPrintAuthException(AuthException error, AuthOperation operation) {
  if (!kDebugMode) return;
  debugPrint(
    'Supabase AuthException during ${operation.name}: '
    'message=${error.message}; '
    'statusCode=${error.statusCode}; '
    'code=${error.code}',
  );
}

void _debugPrintNonAuthError(Object error, AuthOperation operation) {
  if (!kDebugMode) return;
  debugPrint(
    'Supabase auth request failed during ${operation.name}: '
    'type=${error.runtimeType}',
  );
}

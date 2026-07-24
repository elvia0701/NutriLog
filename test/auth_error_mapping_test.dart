import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilog/auth/supabase_auth_service.dart';
import 'package:nutrilog/config/supabase_config.dart';

void main() {
  group('Supabase Auth error mapping', () {
    test(
      'maps registration errors to specific Traditional Chinese messages',
      () {
        final cases = <({String code, Object? status, String expected})>[
          (
            code: 'user_already_exists',
            status: 422,
            expected: '此 Email 已經註冊，請直接登入。',
          ),
          (
            code: 'weak_password',
            status: 422,
            expected: '密碼不符合此專案的安全要求，請增加密碼長度或複雜度。',
          ),
          (
            code: 'signup_disabled',
            status: 400,
            expected: '目前暫停開放新帳號註冊，請聯絡管理者。',
          ),
          (
            code: 'over_email_send_rate_limit',
            status: 429,
            expected: '驗證信寄送次數過多，請稍候一段時間後再試。',
          ),
          (
            code: 'invalid_api_key',
            status: 401,
            expected: 'Supabase 專案 URL 與 anon key 不相符，請重新檢查啟動設定。',
          ),
          (
            code: 'email_address_not_authorized',
            status: 500,
            expected: '目前的寄信設定無法寄送驗證信到此 Email，請聯絡管理者設定自訂 SMTP。',
          ),
          (
            code: 'captcha_failed',
            status: 400,
            expected: '安全驗證未完成，請聯絡管理者確認 CAPTCHA 設定。',
          ),
          (
            code: '',
            status: 404,
            expected: 'SUPABASE_URL 不是專案根網址，請移除 /rest/v1、/auth/v1 或其他路徑。',
          ),
        ];

        for (final item in cases) {
          final failure = mapSupabaseAuthError(
            message: item.status == 404
                ? 'Invalid path specified in request URL'
                : 'server message',
            statusCode: item.status,
            code: item.code,
            operation: AuthOperation.signUp,
          );
          expect(failure.message, item.expected, reason: item.code);
        }
      },
    );

    test('maps login and network errors separately', () {
      expect(
        mapSupabaseAuthError(
          message: 'Invalid login credentials',
          statusCode: 400,
          code: 'invalid_credentials',
          operation: AuthOperation.signIn,
        ).message,
        'Email 或密碼不正確，請重新輸入。',
      );
      expect(
        mapSupabaseAuthError(
          message: 'Email not confirmed',
          statusCode: 400,
          code: 'email_not_confirmed',
          operation: AuthOperation.signIn,
        ).message,
        '此 Email 尚未完成驗證，請先至信箱完成驗證後再登入。',
      );
      expect(
        mapSupabaseAuthError(
          message: 'Failed to fetch',
          statusCode: null,
          code: null,
          operation: AuthOperation.signIn,
        ).message,
        '無法連線到 Supabase，請檢查網路與專案設定後再試。',
      );
      expect(
        mapSupabaseAuthError(
          message: 'Unexpected server response',
          statusCode: 500,
          code: 'unexpected_failure',
          operation: AuthOperation.signIn,
        ).message,
        '登入暫時無法完成，請稍後再試。',
      );
    });

    test('maps non-Auth network errors without exposing details', () {
      final failure = mapUnexpectedAuthError(
        Exception('ClientException: XMLHttpRequest error'),
        AuthOperation.signUp,
      );
      expect(failure.message, '無法連線到 Supabase，請檢查網路與專案設定後再試。');
      expect(failure.message, isNot(contains('ClientException')));
    });
  });

  group('Supabase configuration validation', () {
    test('accepts hosted URL with publishable key', () {
      const config = SupabaseConfig(
        url: 'https://abcdefghijklmnopqrst.supabase.co',
        anonKey: 'sb_publishable_abcdefghijklmnopqrstuvwxyz',
      );
      expect(config.validationError, isNull);
    });

    test('rejects placeholders and mismatched key formats', () {
      const placeholder = SupabaseConfig(
        url: 'https://YOUR_PROJECT.supabase.co',
        anonKey: 'YOUR_ANON_KEY',
      );
      expect(placeholder.validationError, contains('SUPABASE_URL'));

      const invalidKey = SupabaseConfig(
        url: 'https://abcdefghijklmnopqrst.supabase.co',
        anonKey: 'not-a-supabase-key',
      );
      expect(invalidKey.validationError, contains('SUPABASE_ANON_KEY'));
    });

    test('rejects a Supabase URL containing an API path', () {
      const config = SupabaseConfig(
        url: 'https://abcdefghijklmnopqrst.supabase.co/rest/v1',
        anonKey: 'sb_publishable_abcdefghijklmnopqrstuvwxyz',
      );
      expect(config.validationError, contains('專案根網址'));
    });

    test('rejects a legacy service role JWT', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode('{"role":"service_role","ref":"project"}'),
      );
      final config = SupabaseConfig(
        url: 'https://abcdefghijklmnopqrst.supabase.co',
        anonKey: '$header.$payload.abcdefghijklmnopqrst',
      );
      expect(config.validationError, contains('SUPABASE_ANON_KEY'));
    });
  });
}

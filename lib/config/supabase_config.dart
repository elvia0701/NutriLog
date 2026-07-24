import 'dart:convert';

import 'package:flutter/foundation.dart';

class SupabaseConfig {
  final String url;
  final String anonKey;

  const SupabaseConfig({required this.url, required this.anonKey});

  factory SupabaseConfig.fromEnvironment() {
    return const SupabaseConfig(
      url: String.fromEnvironment('SUPABASE_URL'),
      anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }

  String? get validationError {
    if (url.trim().isEmpty || anonKey.trim().isEmpty) {
      return '缺少 Supabase 設定。請透過 --dart-define 提供 '
          'SUPABASE_URL 與 SUPABASE_ANON_KEY。';
    }

    final uri = Uri.tryParse(url.trim());
    final isLocalHost = uri?.host == 'localhost' || uri?.host == '127.0.0.1';
    final isHostedProject = uri?.host.endsWith('.supabase.co') ?? false;
    final validScheme =
        uri?.scheme == 'https' || (isLocalHost && uri?.scheme == 'http');
    if (uri == null ||
        !uri.hasAuthority ||
        !validScheme ||
        (!isHostedProject && !isLocalHost) ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        url.contains('YOUR_PROJECT')) {
      return 'SUPABASE_URL 格式不正確。請從 Supabase Dashboard 複製 '
          'Project URL 的專案根網址，不要加入 /rest/v1、/auth/v1 '
          '或其他路徑。';
    }

    final key = anonKey.trim();
    final isPublishableKey =
        key.startsWith('sb_publishable_') && key.length > 20;
    final jwtParts = key.split('.');
    final isLegacyAnonKey =
        jwtParts.length == 3 && jwtParts.every((part) => part.length >= 10);
    final isServiceRoleKey =
        key.startsWith('sb_secret_') ||
        (isLegacyAnonKey && _legacyKeyRole(jwtParts[1]) == 'service_role');
    if ((!isPublishableKey && !isLegacyAnonKey) ||
        isServiceRoleKey ||
        key.contains('YOUR_ANON_KEY')) {
      return 'SUPABASE_ANON_KEY 格式不正確。請使用此專案的 anon 或 '
          'publishable key，請勿使用 service role key。';
    }

    return null;
  }

  String? _legacyKeyRole(String payload) {
    try {
      final normalized = base64Url.normalize(payload);
      final json = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      return json is Map<String, dynamic> ? json['role'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  void debugPrintSummary() {
    if (!kDebugMode) return;
    final uri = Uri.tryParse(url.trim());
    final keyType = anonKey.trim().startsWith('sb_publishable_')
        ? 'publishable'
        : 'legacy-anon';
    debugPrint(
      'Supabase config: host=${uri?.host ?? 'invalid'}, '
      'keyType=$keyType, keyPresent=${anonKey.trim().isNotEmpty}',
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfigException implements Exception {
  const SupabaseConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SupabaseService {
  const SupabaseService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const _urlDefine = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKeyDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static String get url => _configValue('SUPABASE_URL', _urlDefine);
  static String get publishableKey =>
      _configValue('SUPABASE_ANON_KEY', _publishableKeyDefine);

  static bool get hasEnvConfig => url.isNotEmpty && publishableKey.isNotEmpty;
  static String get configSource {
    final hasDartDefine =
        _urlDefine.trim().isNotEmpty && _publishableKeyDefine.trim().isNotEmpty;
    if (hasDartDefine) return 'dart-define';
    if (hasEnvConfig) return 'env';
    return 'missing';
  }

  static Future<void> initializeFromEnv() async {
    if (!hasEnvConfig) {
      throw const SupabaseConfigException(
        'Supabase is not configured. Pass SUPABASE_URL and SUPABASE_ANON_KEY with --dart-define or add them to local .env.',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      debug: kDebugMode,
    );
  }

  SupabaseClient get client {
    final injected = _client;
    if (injected != null) return injected;
    try {
      return Supabase.instance.client;
    } on Object {
      throw const SupabaseConfigException(
        'Supabase has not been initialized. Call SupabaseService.initializeFromEnv() before using Supabase.',
      );
    }
  }

  bool get isConfigured {
    try {
      client;
      return true;
    } on Object {
      return false;
    }
  }

  GoTrueClient get auth => client.auth;
  FunctionsClient get functions => client.functions;
}

String _configValue(String key, String dartDefineValue) {
  final define = dartDefineValue.trim();
  if (define.isNotEmpty) return define;
  return dotenv.env[key]?.trim() ?? '';
}

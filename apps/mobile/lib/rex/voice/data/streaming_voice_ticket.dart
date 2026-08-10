import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:clarity/rex/voice/data/voice_transport_diagnostics.dart';
import 'package:clarity/rex/voice/data/voice_websocket.dart';

/// Fetch a short-lived single-use ticket over HTTPS, then use it on the
/// WebSocket URL. Prefer this over Authorization headers on the socket —
/// some mobile runtimes drop custom WS headers, so the stream never reaches
/// uvicorn and voice silently falls back to REST.
Future<String> fetchVoiceStreamTicket(
  Uri wsUri,
  Map<String, String>? headers, {
  http.Client? httpClient,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final client = httpClient ?? http.Client();
  final ownsClient = httpClient == null;
  final diagnostics = VoiceTransportDiagnostics.instance;
  try {
    final httpScheme = switch (wsUri.scheme) {
      'wss' => 'https',
      'ws' => 'http',
      _ => wsUri.scheme,
    };
    final ticketUri = wsUri.replace(
      scheme: httpScheme,
      path: '${wsUri.path}/ticket',
      query: '',
    );
    diagnostics.setTicketResult('requesting');
    debugPrint('rex_voice_stream ticket_request $ticketUri');
    final response = await client
        .post(ticketUri, headers: headers ?? const {})
        .timeout(timeout);
    debugPrint('rex_voice_stream ticket_status ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      diagnostics
        ..setTicketResult('http_${response.statusCode}')
        ..setConnectionError(
          'ticket_http_${response.statusCode}',
          code: 'ticket',
        );
      throw const StreamingVoiceApiException(
        'Could not open Assistant voice stream. Check your connection and try again.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      diagnostics.setTicketResult('invalid_body');
      throw const StreamingVoiceApiException(
        'Could not open Assistant voice stream. Check your connection and try again.',
      );
    }
    final ticket = (decoded['ticket'] as String?)?.trim() ?? '';
    if (ticket.isEmpty) {
      diagnostics.setTicketResult('empty_ticket');
      throw const StreamingVoiceApiException(
        'Could not open Assistant voice stream. Check your connection and try again.',
      );
    }
    diagnostics.setTicketResult('ok');
    return ticket;
  } on StreamingVoiceApiException {
    if (diagnostics.ticketResult == 'requesting' ||
        diagnostics.ticketResult == 'none') {
      diagnostics.setTicketResult('failed');
    }
    rethrow;
  } on Object catch (error) {
    diagnostics
      ..setTicketResult('exception')
      ..setConnectionError(error, code: 'ticket');
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  } finally {
    if (ownsClient) {
      client.close();
    }
  }
}

Uri voiceStreamUriWithTicket(Uri wsUri, String ticket) {
  return wsUri.replace(
    queryParameters: {...wsUri.queryParameters, 'ticket': ticket},
  );
}

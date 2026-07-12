import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:clarity/rex/voice/data/voice_websocket.dart';

class WebVoiceWebSocket implements VoiceWebSocket {
  WebVoiceWebSocket._(this._socket, this._controller);

  final html.WebSocket _socket;
  final StreamController<dynamic> _controller;

  static Future<WebVoiceWebSocket> connect(Uri uri) async {
    final socket = html.WebSocket(uri.toString());
    socket.binaryType = 'arraybuffer';

    final controller = StreamController<dynamic>.broadcast();
    final openCompleter = Completer<void>();
    var completed = false;

    void completeError(Object error) {
      if (completed) {
        return;
      }
      completed = true;
      if (!openCompleter.isCompleted) {
        openCompleter.completeError(error);
      }
    }

    socket.onOpen.listen((_) {
      if (completed) {
        return;
      }
      completed = true;
      openCompleter.complete();
    });

    socket.onMessage.listen((event) {
      final data = event.data;
      if (data is String) {
        controller.add(data);
      } else if (data is ByteBuffer) {
        controller.add(Uint8List.view(data));
      }
    });

    socket.onError.listen((_) {
      completeError(
        const StreamingVoiceApiException(
          'Could not open Assistant voice stream. Check your connection and try again.',
        ),
      );
      unawaited(controller.close());
    });

    socket.onClose.listen((_) {
      if (!openCompleter.isCompleted) {
        completeError(
          const StreamingVoiceApiException(
            'Could not open Assistant voice stream. Check your connection and try again.',
          ),
        );
      }
      unawaited(controller.close());
    });

    await openCompleter.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        socket.close();
        throw const StreamingVoiceApiException(
          'Could not open Assistant voice stream. Check your connection and try again.',
        );
      },
    );

    return WebVoiceWebSocket._(socket, controller);
  }

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void add(dynamic data) {
    if (_socket.readyState != html.WebSocket.OPEN) {
      return;
    }
    if (data is String) {
      _socket.sendString(data);
      return;
    }
    if (data is Uint8List) {
      _socket.sendTypedData(data);
      return;
    }
    if (data is List<int>) {
      _socket.sendTypedData(Uint8List.fromList(data));
    }
  }

  @override
  Future<void> close() async {
    if (_socket.readyState == html.WebSocket.CLOSED ||
        _socket.readyState == html.WebSocket.CLOSING) {
      await _controller.close();
      return;
    }
    _socket.close();
    await _controller.close();
  }
}

/// Browser WebSockets cannot set custom headers. Fetch a short-lived ticket
/// over HTTPS (Authorization header), then connect with `ticket` only —
/// never put the Supabase JWT in the WebSocket query string.
Future<VoiceWebSocket> connectVoiceWebSocket(
  Uri uri, {
  Map<String, String>? headers,
}) async {
  try {
    final ticket = await _fetchVoiceStreamTicket(uri, headers);
    final ticketUri = uri.replace(
      queryParameters: {...uri.queryParameters, 'ticket': ticket},
    );
    return await WebVoiceWebSocket.connect(ticketUri);
  } on StreamingVoiceApiException {
    rethrow;
  } on Object {
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  }
}

Future<String> _fetchVoiceStreamTicket(
  Uri wsUri,
  Map<String, String>? headers,
) async {
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
  final response = await http
      .post(ticketUri, headers: headers ?? const {})
      .timeout(const Duration(seconds: 8));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  }
  final ticket = (decoded['ticket'] as String?)?.trim() ?? '';
  if (ticket.isEmpty) {
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  }
  return ticket;
}

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

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
    _socket.close();
    await _controller.close();
  }
}

/// Browser WebSockets cannot set custom headers on the upgrade request.
/// Pass the Supabase JWT via `access_token` query param (rex-api accepts this
/// when the Authorization header is absent).
Uri _webSocketUriWithAuth(Uri uri, Map<String, String>? headers) {
  final authorization = headers?['Authorization']?.trim();
  if (authorization == null || authorization.isEmpty) {
    return uri;
  }

  const bearerPrefix = 'Bearer ';
  final token = authorization.startsWith(bearerPrefix)
      ? authorization.substring(bearerPrefix.length).trim()
      : authorization;

  if (token.isEmpty) {
    return uri;
  }

  return uri.replace(
    queryParameters: {...uri.queryParameters, 'access_token': token},
  );
}

Future<VoiceWebSocket> connectVoiceWebSocket(
  Uri uri, {
  Map<String, String>? headers,
}) async {
  try {
    return await WebVoiceWebSocket.connect(
      _webSocketUriWithAuth(uri, headers),
    );
  } on StreamingVoiceApiException {
    rethrow;
  } on Object {
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  }
}

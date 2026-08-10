import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:clarity/rex/voice/data/streaming_voice_ticket.dart';
import 'package:clarity/rex/voice/data/voice_websocket.dart';

class WebVoiceWebSocket implements VoiceWebSocket {
  WebVoiceWebSocket._(this._socket, this._controller);

  final web.WebSocket _socket;
  final StreamController<dynamic> _controller;

  static Future<WebVoiceWebSocket> connect(Uri uri) async {
    final socket = web.WebSocket(uri.toString());
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

    web.EventStreamProviders.openEvent.forTarget(socket).listen((_) {
      if (completed) {
        return;
      }
      completed = true;
      openCompleter.complete();
    });

    web.EventStreamProviders.messageEvent.forTarget(socket).listen((event) {
      final data = event.data;
      if (data.isA<JSString>()) {
        controller.add((data as JSString).toDart);
      } else if (data.isA<JSArrayBuffer>()) {
        controller.add(Uint8List.view((data as JSArrayBuffer).toDart));
      }
    });

    web.EventStreamProviders.errorEvent.forTarget(socket).listen((_) {
      completeError(
        const StreamingVoiceApiException(
          'Could not open Assistant voice stream. Check your connection and try again.',
        ),
      );
      unawaited(controller.close());
    });

    web.EventStreamProviders.closeEvent.forTarget(socket).listen((_) {
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
    if (_socket.readyState != web.WebSocket.OPEN) {
      return;
    }
    if (data is String) {
      _socket.send(data.toJS);
      return;
    }
    if (data is Uint8List) {
      _socket.send(data.toJS);
      return;
    }
    if (data is List<int>) {
      _socket.send(Uint8List.fromList(data).toJS);
    }
  }

  @override
  Future<void> close() async {
    if (_socket.readyState == web.WebSocket.CLOSED ||
        _socket.readyState == web.WebSocket.CLOSING) {
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
    final ticket = await fetchVoiceStreamTicket(uri, headers);
    return await WebVoiceWebSocket.connect(
      voiceStreamUriWithTicket(uri, ticket),
    );
  } on StreamingVoiceApiException {
    rethrow;
  } on Object {
    throw const StreamingVoiceApiException(
      'Could not open Assistant voice stream. Check your connection and try again.',
    );
  }
}

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Browser PCM capture for Flutter web at `/app/`.
///
/// The `record` package loads its AudioWorklet with a relative path that can
/// fail under a subpath deployment. This engine resolves the worklet through
/// [Uri.base] and reuses one AudioContext per page.
class WebPcmMicrophoneEngine {
  WebPcmMicrophoneEngine._();

  static final WebPcmMicrophoneEngine instance = WebPcmMicrophoneEngine._();

  web.AudioContext? _context;
  web.MediaStream? _mediaStream;
  web.MediaStreamAudioSourceNode? _source;
  web.AudioWorkletNode? _workletNode;
  StreamController<Uint8List>? _chunkController;
  Future<void>? _bootstrapping;
  var _workletReady = false;

  Future<WebPcmCaptureSession> startCapture({
    int sampleRate = 16000,
    int numChannels = 1,
    int streamBufferSize = 2048,
  }) async {
    await stopCapture();
    await _ensureBootstrapped();

    final context = _context!;
    final mediaDevices = web.window.navigator.mediaDevices;

    _mediaStream = await mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: {true}.toJSBox))
        .toDart;

    _chunkController = StreamController<Uint8List>.broadcast();
    _source = context.createMediaStreamSource(_mediaStream!);
    _workletNode = web.AudioWorkletNode(
      context,
      'recorder.worklet',
      web.AudioWorkletNodeOptions(
        parameterData: {
          'numChannels'.toJS: numChannels.toJS,
          'sampleRate'.toJS: sampleRate.toJS,
          'streamBufferSize'.toJS: streamBufferSize.toJS,
        }.jsify()! as JSObject,
      ),
    );

    _workletNode!.port.onmessage =
        ((web.MessageEvent event) => _onWorkletMessage(event)).toJS;
    _source!.connect(_workletNode!)?.connect(context.destination);

    return WebPcmCaptureSession(stream: _chunkController!.stream);
  }

  Future<void> stopCapture() async {
    final controller = _chunkController;
    _chunkController = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }

    _source?.disconnect();
    _source = null;
    _workletNode?.disconnect();
    _workletNode = null;

    final mediaStream = _mediaStream;
    _mediaStream = null;
    if (mediaStream != null) {
      for (final track in mediaStream.getAudioTracks().toDart) {
        track.stop();
      }
    }
  }

  Future<void> _ensureBootstrapped() async {
    final context = _context;
    if (_workletReady && context != null && context.state != 'closed') {
      return;
    }

    _bootstrapping ??= _bootstrap();
    try {
      await _bootstrapping;
    } finally {
      _bootstrapping = null;
    }
  }

  Future<void> _bootstrap() async {
    await _closeContext();
    _context = web.AudioContext();
    final urls = [
      Uri.base.resolve('js/record.worklet.js').toString(),
      Uri.base.resolve(
        'assets/packages/record_web/assets/js/record.worklet.js',
      ).toString(),
    ];
    Object? lastError;
    for (final url in urls) {
      try {
        await _context!.audioWorklet.addModule(url).toDart;
        _workletReady = true;
        return;
      } on Object catch (error) {
        lastError = error;
      }
    }
    await _closeContext();
    throw StateError(
      'Could not load the browser microphone worklet: $lastError',
    );
  }

  Future<void> _closeContext() async {
    _workletReady = false;
    final context = _context;
    _context = null;
    if (context == null || context.state == 'closed') {
      return;
    }
    try {
      await context.close().toDart;
    } on Object {
      // Best-effort cleanup only.
    }
  }

  void _onWorkletMessage(web.MessageEvent event) {
    final output = (event.data as JSInt16Array?)?.toDart;
    if (output == null || output.isEmpty) {
      return;
    }
    final controller = _chunkController;
    if (controller == null || controller.isClosed) {
      return;
    }
    controller.add(output.buffer.asUint8List());
  }
}

final class WebPcmCaptureSession {
  WebPcmCaptureSession({required this.stream});

  final Stream<Uint8List> stream;
}

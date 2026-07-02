import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:clarity/rex/voice/data/voice_pcm16.dart';
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
  web.GainNode? _silentSink;
  StreamController<Uint8List>? _chunkController;
  Future<void>? _bootstrapping;
  var _workletReady = false;
  double _contextSampleRate = 48000;

  Future<WebPcmCaptureSession> startCapture({
    int sampleRate = 16000,
    int numChannels = 1,
    int streamBufferSize = 2048,
  }) async {
    await stopCapture();

    final mediaDevices = web.window.navigator.mediaDevices;
    _mediaStream = await mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(
            audio: {
              'echoCancellation': true,
              'noiseSuppression': false,
              'autoGainControl': true,
            }.jsify()!,
          ),
        )
        .toDart;

    final inputSampleRate = _readInputSampleRate(_mediaStream!);
    await _ensureBootstrapped(inputSampleRate: inputSampleRate);

    final context = _context!;
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
    // Keep the graph alive without routing mic audio to speakers/headphones.
    // Direct `destination` routing can switch Bluetooth headsets into HFP mode
    // and disconnect them when the mic track stops.
    _silentSink = context.createGain();
    _silentSink!.gain.value = 0;
    _source!.connect(_workletNode!);
    _workletNode!.connect(_silentSink!);
    _silentSink!.connect(context.destination);
    await _resumeContext(context);

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
    _silentSink?.disconnect();
    _silentSink = null;

    final mediaStream = _mediaStream;
    _mediaStream = null;
    if (mediaStream != null) {
      for (final track in mediaStream.getAudioTracks().toDart) {
        track.enabled = false;
        track.stop();
      }
    }
  }

  Future<void> _ensureBootstrapped({required double inputSampleRate}) async {
    final context = _context;
    if (_workletReady &&
        context != null &&
        context.state != 'closed' &&
        _contextSampleRate == inputSampleRate) {
      return;
    }

    _bootstrapping ??= _bootstrap(inputSampleRate: inputSampleRate);
    try {
      await _bootstrapping;
    } finally {
      _bootstrapping = null;
    }
  }

  Future<void> _bootstrap({required double inputSampleRate}) async {
    await _closeContext();
    _contextSampleRate = inputSampleRate;
    _context = web.AudioContext(
      web.AudioContextOptions(sampleRate: inputSampleRate),
    );
    await _resumeContext(_context!);
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
        await _resumeContext(_context!);
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

  double _readInputSampleRate(web.MediaStream mediaStream) {
    final tracks = mediaStream.getAudioTracks().toDart;
    if (tracks.isEmpty) {
      return 48000;
    }
    final rate = tracks.first.getSettings().sampleRate;
    return rate > 0 ? rate.toDouble() : 48000;
  }

  Future<void> _resumeContext(web.AudioContext context) async {
    if (context.state == 'closed') {
      return;
    }
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
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
    final bytes = boostPcm16Chunk(Uint8List.sublistView(output));
    controller.add(bytes);
  }

  Future<void> resumeIfSuspended() async {
    final context = _context;
    if (context == null) {
      return;
    }
    await _resumeContext(context);
  }
}

final class WebPcmCaptureSession {
  WebPcmCaptureSession({required this.stream});

  final Stream<Uint8List> stream;
}

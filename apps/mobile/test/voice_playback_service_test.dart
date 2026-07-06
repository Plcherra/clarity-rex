import 'package:clarity/rex/voice/data/audio_playback_service.dart';
import 'package:clarity/rex/voice/data/streaming_audio_playback_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'streaming playback queue uses accepted chunks as playback authority',
    () async {
      final playback = _ControlledPlaybackService();
      final queue = StreamingAudioPlaybackQueue(playback);
      var drainCount = 0;

      final callbacks = StreamingAudioPlaybackCallbacks(
        onChunkStarted: (_) {},
        onQueueDrained: () => drainCount++,
        onError: (_) {},
      );

      queue.beginResponse();
      queue.enqueue(
        const StreamingAudioChunk(
          audioBase64: 'accepted-audio',
          contentType: 'audio/mpeg',
          text: 'chunk',
        ),
        callbacks: callbacks,
      );
      expect(queue.hasAcceptedChunks, isTrue);

      queue.finishResponse(callbacks: callbacks);
      expect(drainCount, 0);

      playback.completeCurrent();
      await queue.waitUntilIdle();

      expect(drainCount, 1);
      expect(playback.playedAudio, ['accepted-audio']);
    },
  );

  test(
    'streaming playback queue plays chunks sequentially and drains',
    () async {
      final playback = _ControlledPlaybackService();
      final queue = StreamingAudioPlaybackQueue(playback);
      final startedChunks = <String>[];
      final errors = <String>[];
      var drainCount = 0;

      final callbacks = StreamingAudioPlaybackCallbacks(
        onChunkStarted: (chunk) => startedChunks.add(chunk.text),
        onQueueDrained: () => drainCount++,
        onError: errors.add,
      );

      queue.beginResponse();
      queue.enqueue(
        const StreamingAudioChunk(
          audioBase64: 'first-audio',
          contentType: 'audio/mpeg',
          text: 'first',
        ),
        callbacks: callbacks,
      );
      queue.enqueue(
        const StreamingAudioChunk(
          audioBase64: 'second-audio',
          contentType: 'audio/mpeg',
          text: 'second',
        ),
        callbacks: callbacks,
      );
      queue.finishResponse(callbacks: callbacks);

      expect(startedChunks, ['first']);
      expect(playback.playedAudio, ['first-audio']);
      expect(queue.isPlaying, isTrue);
      expect(drainCount, 0);

      playback.completeCurrent();
      await Future<void>.delayed(Duration.zero);

      expect(startedChunks, ['first', 'second']);
      expect(playback.playedAudio, ['first-audio', 'second-audio']);
      expect(queue.isPlaying, isTrue);

      playback.completeCurrent();
      await queue.waitUntilIdle();

      expect(queue.isIdle, isTrue);
      expect(drainCount, 1);
      expect(errors, isEmpty);
    },
  );

  test(
    'streaming playback queue cancels active playback and late chunks',
    () async {
      final playback = _ControlledPlaybackService();
      final queue = StreamingAudioPlaybackQueue(playback);
      final startedChunks = <String>[];
      var drainCount = 0;

      final callbacks = StreamingAudioPlaybackCallbacks(
        onChunkStarted: (chunk) => startedChunks.add(chunk.text),
        onQueueDrained: () => drainCount++,
        onError: (_) {},
      );

      queue.beginResponse();
      queue.enqueue(
        const StreamingAudioChunk(
          audioBase64: 'first-audio',
          contentType: 'audio/mpeg',
          text: 'first',
        ),
        callbacks: callbacks,
      );

      await queue.cancel();
      queue.enqueue(
        const StreamingAudioChunk(
          audioBase64: 'late-audio',
          contentType: 'audio/mpeg',
          text: 'late',
        ),
        callbacks: callbacks,
      );
      queue.finishResponse(callbacks: callbacks);

      expect(playback.stopCount, 1);
      expect(startedChunks, ['first']);
      expect(playback.playedAudio, ['first-audio']);
      expect(queue.isIdle, isTrue);
      expect(drainCount, 1);
    },
  );
}

class _ControlledPlaybackService implements AudioPlaybackService {
  final playedAudio = <String>[];
  AudioPlaybackCompleteCallback? _onComplete;
  var stopCount = 0;

  @override
  Future<void> playBase64Audio(
    String audioBase64, {
    required String contentType,
    required AudioPlaybackCompleteCallback onComplete,
    required AudioPlaybackErrorCallback onError,
    bool continueSession = false,
  }) async {
    playedAudio.add(audioBase64);
    _onComplete = onComplete;
  }

  void completeCurrent() {
    final onComplete = _onComplete;
    _onComplete = null;
    onComplete?.call();
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    stopCount++;
    _onComplete = null;
  }
}

String formatVoiceElapsed(Duration duration) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds < 60) {
    return '${totalSeconds}s';
  }

  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (seconds == 0) {
    return '${minutes}m';
  }
  return '${minutes}m ${seconds}s';
}

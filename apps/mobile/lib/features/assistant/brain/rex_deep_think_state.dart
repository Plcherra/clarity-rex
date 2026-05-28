import 'package:flutter_riverpod/flutter_riverpod.dart';

const rexDeepThinkLabel = 'Deep Think';
const rexDeepThinkTooltip =
    'Ask Rex to use a deeper reasoning path for this message.';

final rexDeepThinkEnabledProvider =
    NotifierProvider<RexDeepThinkController, bool>(
      RexDeepThinkController.new,
    );

class RexDeepThinkController extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    state = enabled;
  }

  void reset() {
    state = false;
  }
}

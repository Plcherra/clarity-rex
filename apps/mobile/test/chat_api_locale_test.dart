import 'package:clarity/rex/chat/data/chat_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChatApi attaches locale from resolveLocale callback', () {
    final api = ChatApi(resolveLocale: () => 'es');
    final payload = api.attachLocaleForTesting(<String, dynamic>{'message': 'Hi'});

    expect(payload['locale'], 'es');
  });

  test('ChatApi omits locale when resolveLocale is null', () {
    final api = ChatApi();
    final payload = api.attachLocaleForTesting(<String, dynamic>{'message': 'Hi'});

    expect(payload.containsKey('locale'), isFalse);
  });
}

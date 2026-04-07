import 'package:zerk_play/core/emby/emby_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EmbyClient builds Uris', () {
    final client = EmbyClient(
      serverUrl: Uri.parse('https://play.zerk.cloud'),
      clientName: 'Test',
      deviceName: 'Test',
      deviceId: 'device-id',
      appVersion: '0.0.0',
    );

    final uri = client.buildUri(
      '/Users/Me/Items',
      queryParameters: {'a': '1'},
    );

    expect(uri.toString(), 'https://play.zerk.cloud/Users/Me/Items?a=1');
  });
}

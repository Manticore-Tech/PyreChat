import 'package:flutter_test/flutter_test.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';

void main() {
  test('normalizes an explicitly supplied API origin', () {
    final api = PyreApi(origin: '  https://example.test/  ');
    expect(api.origin, 'https://example.test');
  });

  test('rejects an empty API origin', () {
    expect(() => PyreApi(origin: '   '), throwsArgumentError);
  });
}

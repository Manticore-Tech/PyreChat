import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'manual GUI snapshot harness is excluded from the normal regression suite',
    (tester) async {},
    skip: true,
  );
}

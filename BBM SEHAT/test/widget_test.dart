import 'package:flutter_test/flutter_test.dart';

import 'package:bbm_sehat/main.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BbmSehatApp());
    await tester.pump();

    expect(find.text('BBM Sehat'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:compositor/main.dart';

void main() {
  testWidgets('Compositor app shows empty editor shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CompositorApp());
    await tester.pump();

    expect(find.text('No document open'), findsOneWidget);
  });
}
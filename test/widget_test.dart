import 'package:flutter_test/flutter_test.dart';

import 'package:overtime/main.dart';

void main() {
  testWidgets('App launches with bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const JiaLeMeApp());
    expect(find.text('加了么'), findsWidgets);
    expect(find.text('首页'), findsOneWidget);
  });
}

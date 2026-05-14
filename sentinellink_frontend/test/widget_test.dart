import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sentinellink_frontend/main.dart';

void main() {
  testWidgets('SentinelLink app boots on login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SentinelLinkApp());

    expect(find.text('SentinelLink - Login'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}

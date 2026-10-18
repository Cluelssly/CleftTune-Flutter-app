import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homepage/landing_page.dart';

void main() {
  testWidgets(
    'landing content remains visible after resizing to narrow width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(home: LandingPage(onContinue: () {})),
      );
      await tester.pump(const Duration(seconds: 2));

      await tester.binding.setSurfaceSize(const Size(590, 850));
      await tester.pump();

      expect(find.text('AI VOICE SUPPORT'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

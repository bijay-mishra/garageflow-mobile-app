import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garageflow_mobile/core/theme.dart';
import 'package:garageflow_mobile/widgets/gradient_header.dart';

void main() {
  /// The exact shape that broke: an accented card inside a ListView, where the
  /// height is unbounded. The old `Row(crossAxisAlignment: stretch)` demanded
  /// infinite height here and the card rendered as blank space — which is what
  /// made the Appearance screen, the job list and the deliveries list look
  /// empty rather than broken.
  Widget inList({Color? accent}) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ListView(
        children: [
          AppCard(
            accent: accent,
            child: const Text('card body'),
          ),
        ],
      ),
    ),
  );

  testWidgets('an accented card lays out inside a ListView', (tester) async {
    await tester.pumpWidget(inList(accent: AppTheme.cyan));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('card body'), findsOneWidget);

    // It has real height, rather than collapsing to nothing.
    final size = tester.getSize(find.text('card body'));
    expect(size.height, greaterThan(0));
  });

  testWidgets('a plain card still lays out', (tester) async {
    await tester.pumpWidget(inList());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('card body'), findsOneWidget);
  });

  testWidgets('the accent does not sit on top of the content', (tester) async {
    await tester.pumpWidget(inList(accent: AppTheme.rose));
    await tester.pump();

    final card = tester.getRect(find.byType(AppCard));
    final text = tester.getRect(find.text('card body'));

    // The text starts past the 4pt bar plus the card's own padding, so the
    // colour never runs under the first character.
    expect(text.left, greaterThan(card.left + 4));
  });
}

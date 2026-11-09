import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/progress_bar_pill.dart';

/// Size of the coloured fill inside a 100px-wide bordered pill.
Future<Size> _fillSize(WidgetTester tester, {required double height}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 100,
          child: ProgressBarPill(progress: 0.5, height: height),
        ),
      ),
    ),
  );
  return tester.getSize(
    find.byWidgetPredicate((w) => w is ColoredBox && w.color == AppColors.moss),
  );
}

void main() {
  // The Home XP pill (6px) and Today's Goal bar (8px) used to draw no fill at
  // all: the border was inset twice, leaving zero or negative height.
  for (final height in [6.0, 8.0, 12.0]) {
    testWidgets('a ${height.toInt()}px pill draws its fill', (tester) async {
      final size = await _fillSize(tester, height: height);
      final inner = 100 - AppBorder.thin * 2;
      expect(size.height, height - AppBorder.thin * 2);
      expect(size.width, closeTo(inner / 2, 0.01));
    });
  }
}

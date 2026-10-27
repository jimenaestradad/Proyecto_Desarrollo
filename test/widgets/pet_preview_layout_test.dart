import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/accessory_catalog.dart';
import 'package:nori/widgets/accessory_art.dart';

/// Customization's preview used to build Nori + accessory by hand; it now
/// uses [NoriAccessoryPreview]. In a panel wide enough that width isn't the
/// limit, both must put the image and every accessory in the same place.
Widget oldComposition(double petHeight, AccessoryItem item) => SizedBox(
  height: petHeight,
  child: Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.topCenter,
    children: [
      Image.asset(
        'assets/images/nori_front.png',
        height: petHeight,
        fit: BoxFit.contain,
      ),
      positionedAccessoryArt(item: item, referenceSize: petHeight),
    ],
  ),
);

Future<(Rect, Rect?)> measure(WidgetTester tester, Widget preview) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: Stack(alignment: Alignment.center, children: [preview]),
        ),
      ),
    ),
  );
  final image = tester.getRect(find.byType(Image).first);
  final art = find.byType(AccessoryArt);
  return (image, art.evaluate().isEmpty ? null : tester.getRect(art.first));
}

void main() {
  for (final item in kAccessoryCatalog) {
    testWidgets('${item.id}: same layout as the hand-built preview', (
      tester,
    ) async {
      const petHeight = 216.0; // 0.72 of a 300px panel, as Customization uses
      final before = await measure(tester, oldComposition(petHeight, item));
      final after = await measure(
        tester,
        NoriAccessoryPreview(height: petHeight, item: item),
      );
      expect(after.$1, before.$1, reason: 'Nori image moved');
      expect(after.$2, before.$2, reason: 'accessory moved or resized');
    });
  }
}

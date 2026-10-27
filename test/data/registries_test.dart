import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/color_registry.dart';
import 'package:nori/data/icon_registry.dart';

void main() {
  test('every registered icon and color round-trips through its key', () {
    for (final entry in IconRegistry.byKey.entries) {
      expect(IconRegistry.keyFor(IconRegistry.iconFor(entry.key)), entry.key);
    }
    for (final entry in ColorRegistry.byKey.entries) {
      expect(
        ColorRegistry.keyFor(ColorRegistry.colorFor(entry.key)),
        entry.key,
      );
    }
  });

  test('habit and bucket-list icons live in the one registry', () {
    expect(IconRegistry.iconFor('water_drop'), Icons.water_drop);
    expect(IconRegistry.iconFor('flight_takeoff'), Icons.flight_takeoff);
    expect(IconRegistry.tryKeyFor(Icons.celebration), 'celebration');
  });

  test('reading an unknown or missing key falls back instead of throwing', () {
    expect(IconRegistry.iconFor('nope'), IconRegistry.defaultIcon);
    expect(IconRegistry.iconFor(null), IconRegistry.defaultIcon);
    expect(ColorRegistry.colorFor('nope'), ColorRegistry.defaultColor);
    expect(ColorRegistry.colorFor(null), ColorRegistry.defaultColor);
    expect(
      IconRegistry.byKey[IconRegistry.defaultKey],
      IconRegistry.defaultIcon,
    );
    expect(
      ColorRegistry.byKey[ColorRegistry.defaultKey],
      ColorRegistry.defaultColor,
    );
  });

  test(
    'writing an unregistered value is strict, with a non-throwing option',
    () {
      expect(IconRegistry.tryKeyFor(Icons.wifi), isNull);
      expect(() => IconRegistry.keyFor(Icons.wifi), throwsArgumentError);
      expect(ColorRegistry.tryKeyFor(const Color(0xFF123456)), isNull);
      expect(
        () => ColorRegistry.keyFor(const Color(0xFF123456)),
        throwsArgumentError,
      );
    },
  );
}

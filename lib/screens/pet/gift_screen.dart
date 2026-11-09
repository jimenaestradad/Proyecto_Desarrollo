import 'package:flutter/material.dart';
import 'package:nori/data/accessory_catalog.dart';
import 'package:nori/widgets/accessory_art.dart';
import 'package:nori/widgets/celebration_card.dart';

/// Celebrates the one-time accessory gift for a first completed habit, using
/// the shared [CelebrationScreen] shell. Use [showGiftCelebration] to present it.
class GiftScreen extends StatelessWidget {
  const GiftScreen({super.key, required this.accessory, required this.petName});

  final AccessoryItem accessory;
  final String petName;

  @override
  Widget build(BuildContext context) {
    return CelebrationScreen(
      kicker: 'FIRST HABIT DONE!',
      badge: Center(child: AccessoryArt(item: accessory, headWidth: 100)),
      title: 'A gift for $petName!',
      message: '${accessory.name} is yours for completing your first habit.',
      actionLabel: 'Try it on',
    );
  }
}

/// Shows the gift for [accessoryId]; does nothing if the catalog no longer
/// has it. Completes with true when the person taps "Try it on", so the
/// caller can open Customize.
Future<bool> showGiftCelebration(
  BuildContext context, {
  required String accessoryId,
  required String petName,
}) {
  final accessory = accessoryById(accessoryId);
  if (accessory == null) return Future.value(false);
  return showCelebrationRoute<bool>(
    context,
    (_) => GiftScreen(accessory: accessory, petName: petName),
  ).then((tryItOn) => tryItOn == true);
}

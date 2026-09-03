/// A user's consumable pet-care supplies and owned/equipped cosmetics —
/// backs the Shop's Food & Care and Basic Accessories categories.
class Inventory {
  const Inventory({
    required this.snacks,
    required this.soap,
    required this.toys,
    required this.ownedAccessoryIds,
    this.equippedAccessoryId,
  });

  /// Uses available for Feed / Groom / Play respectively.
  final int snacks;
  final int soap;
  final int toys;

  final Set<String> ownedAccessoryIds;
  final String? equippedAccessoryId;

  Inventory copyWith({
    int? snacks,
    int? soap,
    int? toys,
    Set<String>? ownedAccessoryIds,
    Object? equippedAccessoryId = _unset,
  }) {
    return Inventory(
      snacks: snacks ?? this.snacks,
      soap: soap ?? this.soap,
      toys: toys ?? this.toys,
      ownedAccessoryIds: ownedAccessoryIds ?? this.ownedAccessoryIds,
      equippedAccessoryId: identical(equippedAccessoryId, _unset)
          ? this.equippedAccessoryId
          : equippedAccessoryId as String?,
    );
  }
}

/// Sentinel so `copyWith(equippedAccessoryId: null)` can distinguish
/// "unequip" from "not passed" — a plain nullable default can't tell those
/// apart.
const Object _unset = Object();

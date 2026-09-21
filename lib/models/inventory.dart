/// A user's consumable pet-care supplies and owned/equipped cosmetics —
/// backs the Shop's Food & Care and Basic Accessories categories.
class Inventory {
  const Inventory({
    required this.careItemCounts,
    required this.ownedAccessoryIds,
    this.equippedAccessoryId,
  });

  /// Uses left per care item id (see `care_item_catalog.dart`) — an id
  /// absent from the map means zero, same as an id mapped to 0. Was three
  /// flat `snacks`/`soap`/`toys` counters before care items grew a second
  /// tier per stat and needed picking one to use rather than one generic
  /// counter per vital.
  final Map<String, int> careItemCounts;

  final Set<String> ownedAccessoryIds;
  final String? equippedAccessoryId;

  int countOf(String careItemId) => careItemCounts[careItemId] ?? 0;

  Inventory copyWith({
    Map<String, int>? careItemCounts,
    Set<String>? ownedAccessoryIds,
    Object? equippedAccessoryId = _unset,
  }) {
    return Inventory(
      careItemCounts: careItemCounts ?? this.careItemCounts,
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

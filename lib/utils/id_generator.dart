import 'dart:math';

final _random = Random();

/// A locally-unique id for a newly-created item. `microsecondsSinceEpoch`
/// alone isn't quite enough to rule out a same-tick collision (two rapid taps
/// could land in the same microsecond), hence the random suffix.
///
/// The suffix's range is a plain decimal literal, not `1 << 32` — under
/// Flutter Web's compiler that shift doesn't evaluate to 2^32 the way it does
/// on the VM, and `Random.nextInt` throws `RangeError` on the resulting
/// value, silently breaking every "Add" action that calls this on web.
String generateId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(2000000000)}';

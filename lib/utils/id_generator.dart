import 'dart:math';

final _random = Random();

/// Locally unique timestamp-plus-random id; the suffix avoids same-tick collisions.
/// Use a decimal random bound because `1 << 32` differs under Flutter Web.
String generateId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(2000000000)}';

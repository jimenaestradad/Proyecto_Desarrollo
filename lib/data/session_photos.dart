import 'package:flutter/foundation.dart';

/// Photos picked on this device and kept in memory only. They stand in for
/// Firebase Storage uploads, so they vanish when the app restarts or the
/// account signs out.
class SessionPhotos {
  SessionPhotos._();

  /// The signed-in user's profile picture, shown wherever their avatar is.
  static final avatar = ValueNotifier<Uint8List?>(null);

  static final _proofs = <String, Uint8List>{};

  /// The proof photo attached to the post with [postId], if any.
  static Uint8List? proofFor(String postId) => _proofs[postId];

  static void setProof(String postId, Uint8List bytes) =>
      _proofs[postId] = bytes;

  static void clear() {
    avatar.value = null;
    _proofs.clear();
  }
}

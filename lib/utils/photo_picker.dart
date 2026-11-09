import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Lets the user pick a photo and returns its bytes, or null if they cancel
/// or the picker fails. On phones they choose camera or gallery; the browser
/// only has a file chooser. The bytes are only ever kept in memory
/// ([SessionPhotos]).
Future<Uint8List?> pickPhoto(BuildContext context) async {
  var source = ImageSource.gallery;
  if (!kIsWeb) {
    final chosen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return null;
    source = chosen;
  }
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  } catch (_) {
    return null;
  }
}

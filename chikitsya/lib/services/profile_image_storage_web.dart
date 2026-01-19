import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class StoredProfileImage {
  final String? localPath;
  final String? base64Data;

  const StoredProfileImage({this.localPath, this.base64Data});

  bool get isEmpty => localPath == null && base64Data == null;
}

Future<StoredProfileImage?> persistPickedProfileImage(PlatformFile file) async {
  // Web: persist as base64 in preferences (small images recommended).
  final bytes = file.bytes;
  if (bytes == null) return null;
  return StoredProfileImage(base64Data: base64Encode(bytes));
}

ImageProvider? imageProviderFromStoredProfileImage({
  required String? localPath,
  required String? base64Data,
}) {
  if (base64Data == null || base64Data.isEmpty) return null;

  try {
    final bytes = base64Decode(base64Data);
    return MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

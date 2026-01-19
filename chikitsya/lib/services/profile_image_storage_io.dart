import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class StoredProfileImage {
  final String? localPath;
  final String? base64Data;

  const StoredProfileImage({this.localPath, this.base64Data});

  bool get isEmpty => localPath == null && base64Data == null;
}

Future<StoredProfileImage?> persistPickedProfileImage(PlatformFile file) async {
  // Mobile/desktop: prefer persisting to app documents directory.
  final directory = await getApplicationDocumentsDirectory();
  final ext = (file.extension?.trim().isNotEmpty ?? false)
      ? file.extension!
      : 'jpg';
  final outPath = '${directory.path}/profile_avatar.$ext';

  if (file.path != null) {
    await File(file.path!).copy(outPath);
    return StoredProfileImage(localPath: outPath);
  }

  final Uint8List? bytes = file.bytes;
  if (bytes != null) {
    await File(outPath).writeAsBytes(bytes, flush: true);
    return StoredProfileImage(localPath: outPath);
  }

  return null;
}

ImageProvider? imageProviderFromStoredProfileImage({
  required String? localPath,
  required String? base64Data,
}) {
  if (localPath != null && localPath.isNotEmpty) {
    final file = File(localPath);
    if (file.existsSync()) {
      return FileImage(file);
    }
  }

  if (base64Data != null && base64Data.isNotEmpty) {
    // Shouldn't be used on IO implementation, but keep it safe.
    try {
      final bytes = base64Decode(base64Data);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  return null;
}

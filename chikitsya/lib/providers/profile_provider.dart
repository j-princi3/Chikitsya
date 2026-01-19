import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_image_storage.dart';

class ProfileProvider extends ChangeNotifier {
  static const _defaultName = 'User';

  String? _uid;
  String _name = _defaultName;
  String _phoneNumber = '';
  String? _imagePath;
  String? _imageBase64;

  bool _busy = false;
  String? _lastError;

  String get name => _name;
  String get phoneNumber => _phoneNumber;
  bool get busy => _busy;
  String? get lastError => _lastError;

  ImageProvider? get profileImage => imageProviderFromStoredProfileImage(
    localPath: _imagePath,
    base64Data: _imageBase64,
  );

  Future<void> load() async {
    await refreshFromAuth();
  }

  Future<void> refreshFromAuth({String? fallbackPhoneNumber}) async {
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;

    final prefs = await SharedPreferences.getInstance();

    final uidKey = _uid ?? 'anonymous';
    _name = prefs.getString('profile.name.$uidKey') ?? _defaultName;
    _imagePath = prefs.getString('profile.imagePath.$uidKey');
    _imageBase64 = prefs.getString('profile.imageBase64.$uidKey');

    final authPhone = user?.phoneNumber;
    _phoneNumber = (authPhone != null && authPhone.trim().isNotEmpty)
        ? authPhone.trim()
        : (prefs.getString('profile.phone.$uidKey') ??
                  (fallbackPhoneNumber ?? ''))
              .trim();

    notifyListeners();
  }

  Future<void> setName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    _name = trimmed;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final uidKey = _uid ?? 'anonymous';
    await prefs.setString('profile.name.$uidKey', _name);
  }

  Future<void> setPhoneNumber(String value) async {
    _phoneNumber = value.trim();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final uidKey = _uid ?? 'anonymous';
    await prefs.setString('profile.phone.$uidKey', _phoneNumber);
  }

  Future<void> pickAndSaveProfileImage() async {
    _setBusy(true);
    _lastError = null;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb, // web needs bytes
      );

      if (result == null || result.files.isEmpty) {
        _setBusy(false);
        return;
      }

      final stored = await persistPickedProfileImage(result.files.single);
      if (stored == null || stored.isEmpty) {
        throw Exception('Could not read selected image');
      }

      _imagePath = stored.localPath;
      _imageBase64 = stored.base64Data;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final uidKey = _uid ?? 'anonymous';
      if (_imagePath != null) {
        await prefs.setString('profile.imagePath.$uidKey', _imagePath!);
      } else {
        await prefs.remove('profile.imagePath.$uidKey');
      }

      if (_imageBase64 != null) {
        await prefs.setString('profile.imageBase64.$uidKey', _imageBase64!);
      } else {
        await prefs.remove('profile.imageBase64.$uidKey');
      }
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> clearForLogout() async {
    _uid = null;
    _phoneNumber = '';
    _name = _defaultName;
    _imagePath = null;
    _imageBase64 = null;
    _lastError = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}

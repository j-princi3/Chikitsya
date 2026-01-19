import 'package:flutter/material.dart';

class AdherenceProvider with ChangeNotifier {
  int taken = 0;
  int missed = 0;

  void record(bool success) {
    success ? taken++ : missed++;
    notifyListeners();
  }
}

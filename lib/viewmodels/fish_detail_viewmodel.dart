import 'package:flutter/material.dart';
import '../models/fish.dart';

typedef FishByIdFactory = Future<Fish?> Function(String id);

class FishDetailViewModel extends ChangeNotifier {
  final FishByIdFactory _getById;

  Fish? _fish;
  bool _isLoading = false;
  String? _error;

  Fish? get fish => _fish;
  bool get isLoading => _isLoading;
  String? get error => _error;

  FishDetailViewModel(this._getById);

  Future<void> loadFish(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _fish = await _getById(id);
      if (_fish == null) {
        _error = 'Fish not found';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

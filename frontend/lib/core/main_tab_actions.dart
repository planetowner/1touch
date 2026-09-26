import 'package:flutter/foundation.dart';

/// Broadcasts bottom-navigation selections to the persistent root screens.
///
/// The indexed shell keeps each branch alive, so route navigation alone does
/// not reset its scroll position. Root screens listen for their tab index and
/// explicitly return to their first feature.
class MainTabActionController extends ChangeNotifier {
  int? _tabIndex;
  int _serial = 0;

  int? get tabIndex => _tabIndex;
  int get serial => _serial;

  void select(int tabIndex) {
    _tabIndex = tabIndex;
    _serial += 1;
    notifyListeners();
  }
}

final mainTabActions = MainTabActionController();

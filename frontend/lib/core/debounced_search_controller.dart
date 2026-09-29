import 'dart:async';

import 'package:flutter/foundation.dart';

class DebouncedSearchController<T> extends ChangeNotifier {
  DebouncedSearchController({required Future<T> Function(String) search})
      : _search = search;

  final Future<T> Function(String) _search;
  Timer? _debounce;
  int _generation = 0;
  String query = '';
  T? result;
  Object? error;
  bool loading = false;

  void updateQuery(String value) {
    final next = value.trim();
    // 한글 조합과 커서 이동으로 요청이 몰리지 않게, 바뀐 검색어만 잠시 기다렸다 보내요.
    if (next == query) return;
    _debounce?.cancel();
    ++_generation;
    query = next;
    result = null;
    error = null;
    loading = query.isNotEmpty;
    notifyListeners();
    if (loading) {
      _debounce = Timer(const Duration(milliseconds: 250), search);
    }
  }

  Future<void> search() async {
    _debounce?.cancel();
    if (query.isEmpty) return;
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await _search(query);
      if (generation != _generation) return;
      result = value;
    } catch (exception) {
      if (generation != _generation) return;
      error = exception;
    }
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    // 닫힌 화면에는 진행 중이던 검색의 응답을 반영하지 않아요.
    ++_generation;
    _debounce?.cancel();
    super.dispose();
  }
}

// Subscriber and connections; which connection is selected.

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';

class AppStore extends ChangeNotifier {
  AppStore(this.repo);

  final Repository repo;

  Subscriber? subscriber;
  List<Connection> connections = const [];
  int _selected = 0;
  bool loading = false;
  bool failed = false;

  Connection? get connection => connections.isEmpty ? null : connections[_selected.clamp(0, connections.length - 1)];
  int get selectedIndex => _selected;

  Future<void> load() async {
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final r = await Future.wait([repo.subscriber(), repo.connections()]);
      subscriber = r[0] as Subscriber;
      connections = r[1] as List<Connection>;
    } catch (_) {
      failed = true;
    }
    loading = false;
    notifyListeners();
  }

  final Map<String, Future<Warranty>> _warranty = {};

  /// Equipment warranty for a connection (fetched once per VC).
  Future<Warranty> warrantyOf(String vc) => _warranty.putIfAbsent(vc, () => repo.warranty(vc));

  /// Saves profile changes and shows them everywhere.
  Future<void> updateProfile(Subscriber s) async {
    subscriber = await repo.updateSubscriber(s);
    notifyListeners();
  }

  void select(int i) {
    if (i == _selected) return;
    _selected = i;
    notifyListeners();
  }

  void selectVc(String vc) {
    final i = connections.indexWhere((c) => c.vc == vc);
    if (i >= 0) select(i);
  }
}

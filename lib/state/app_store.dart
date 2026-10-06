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

  /// Pay Later: [days] more TV on [vc], counted from today when it has
  /// already switched off (which switches it back on). Returns the new
  /// switch-off date.
  DateTime extendSwitchOff(String vc, int days) {
    final i = connections.indexWhere((c) => c.vc == vc);
    final c = connections[i];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = c.daysLeft(now) > 0 ? DateTime(c.switchOffDate.year, c.switchOffDate.month, c.switchOffDate.day) : today;
    final off = from.add(Duration(days: days));
    connections = [...connections]
      ..[i] = Connection(
        vc: c.vc,
        label: c.label,
        type: c.type,
        status: c.status == ConnectionStatus.deactivated ? ConnectionStatus.active : c.status,
        monthlyRecharge: c.monthlyRecharge,
        balance: c.balance,
        switchOffDate: off,
        lockInUntil: c.lockInUntil,
        planName: c.planName,
        isHd: c.isHd,
      );
    notifyListeners();
    return off;
  }

  /// Ends a vacation now: the TV is switched back on.
  void endVacation(String vc) {
    final i = connections.indexWhere((c) => c.vc == vc);
    if (i < 0) return;
    final c = connections[i];
    connections = [...connections]
      ..[i] = Connection(
        vc: c.vc,
        label: c.label,
        type: c.type,
        status: ConnectionStatus.active,
        monthlyRecharge: c.monthlyRecharge,
        balance: c.balance,
        switchOffDate: c.switchOffDate,
        lockInUntil: c.lockInUntil,
        planName: c.planName,
        isHd: c.isHd,
      );
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

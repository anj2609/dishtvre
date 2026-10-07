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

  /// Reloads the TVs without the loading state, after a change made
  /// elsewhere (a new pack, an HD upgrade).
  Future<void> refresh() async {
    try {
      connections = await repo.connections();
      notifyListeners();
    } catch (_) {
      // Keep what's on screen; pull-to-refresh can try again.
    }
  }

  Connection? _find(String vc) => connections.where((c) => c.vc == vc).firstOrNull;

  /// Shows [c] everywhere right away and saves it.
  void _put(Connection c) {
    connections = [for (final x in connections) x.vc == c.vc ? c : x];
    notifyListeners();
    repo.saveConnection(c);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// A paid recharge of [amount]: the TV runs until [validTill], and one that
  /// had switched off comes back on.
  void recharge(String vc, {required double amount, required DateTime validTill}) {
    final c = _find(vc);
    if (c == null) return;
    _put(c.copyWith(
      status: c.status == ConnectionStatus.deactivated ? ConnectionStatus.active : c.status,
      balance: c.balance + amount,
      switchOffDate: validTill,
    ));
  }

  /// Pay Later: [days] more TV on [vc], counted from today when it has
  /// already switched off (which switches it back on). Returns the new
  /// switch-off date.
  DateTime extendSwitchOff(String vc, int days) {
    final c = _find(vc)!;
    final now = DateTime.now();
    final from = c.daysLeft(now) > 0 ? _day(c.switchOffDate) : _day(now);
    final off = from.add(Duration(days: days));
    _put(c.copyWith(
      status: c.status == ConnectionStatus.deactivated ? ConnectionStatus.active : c.status,
      switchOffDate: off,
    ));
    return off;
  }

  /// Books a pause from [from] until [resume] (or moves a booked one); the
  /// switch-off date moves out by the days paused.
  void bookVacation(String vc, {required DateTime from, required DateTime resume}) {
    final c = _find(vc);
    if (c == null) return;
    var off = _day(c.switchOffDate);
    if (c.vacationBooked) off = off.subtract(Duration(days: c.resumeOn!.difference(c.pauseFrom!).inDays));
    off = off.add(Duration(days: resume.difference(from).inDays));
    _put(c.copyWith(switchOffDate: off, pauseFrom: from, resumeOn: resume));
  }

  /// Cancels a booked pause; the switch-off date moves back.
  void cancelVacation(String vc) {
    final c = _find(vc);
    final from = c?.pauseFrom, resume = c?.resumeOn;
    if (c == null || from == null || resume == null) return;
    final days = resume.difference(from).inDays;
    _put(c.copyWith(switchOffDate: _day(c.switchOffDate).subtract(Duration(days: days)), clearVacation: true));
  }

  /// Ends a vacation now: the TV is switched back on.
  void endVacation(String vc) {
    final c = _find(vc);
    if (c == null) return;
    _put(c.copyWith(status: ConnectionStatus.active, clearVacation: true));
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

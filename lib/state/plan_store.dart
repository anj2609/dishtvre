// The plan being edited for one connection: its current items, the pending
// changes (a new base pack, items removed, top-ups added), packs to compare,
// the server quote and applying the change.

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repository.dart';

enum ApplyState { idle, quoting, ready, applying, done, failed }

class PlanStore extends ChangeNotifier {
  PlanStore(this.repo);

  final Repository repo;

  Connection? connection;
  List<PlanItem> items = const [];
  bool loadingItems = false;

  Future<void> open(Connection c) async {
    if (connection?.vc == c.vc && items.isNotEmpty) return;
    connection = c;
    _reset();
    loadingItems = true;
    notifyListeners();
    items = await repo.planItems(c.vc);
    loadingItems = false;
    notifyListeners();
  }

  void _reset() {
    items = const [];
    newBase = null;
    _removed.clear();
    _added.clear();
    compare.clear();
    packs = const [];
    _catalogs.clear();
    _channels.clear();
    quote = null;
    applyState = ApplyState.idle;
    orderId = null;
  }

  // ----------------------------------------------------------- current plan

  PlanItem? get basePack => items.where((i) => i.kind == ItemKind.basePack).firstOrNull;
  List<PlanItem> itemsOf(ItemKind k) => items.where((i) => i.kind == k).toList();
  double get currentTotal => connection?.monthlyRecharge ?? 0;

  // ---------------------------------------------------------- pending edits

  Pack? newBase;
  final Set<int> _removed = {};
  final Map<int, PlanItem> _added = {};

  bool isRemoved(PlanItem i) => _removed.contains(i.id);
  bool isAdded(PlanItem i) => _added.containsKey(i.id);
  List<PlanItem> get removed => items.where((i) => _removed.contains(i.id)).toList();
  List<PlanItem> get added => _added.values.toList();
  bool get hasChanges => newBase != null || _removed.isNotEmpty || _added.isNotEmpty;
  int get changeCount => (newBase != null ? 1 : 0) + _removed.length + _added.length;

  void toggleRemove(PlanItem i) {
    if (!i.removable) return;
    if (!_removed.remove(i.id)) _removed.add(i.id);
    _changed();
  }

  /// Adds a top-up. Only one recording plan can be on at a time, so adding
  /// one drops the other.
  void add(PlanItem i) {
    if (items.any((x) => x.id == i.id)) return;
    if (i.isRecordingPlan) {
      _added.removeWhere((_, x) => x.isRecordingPlan);
      for (final x in items.where((x) => x.isRecordingPlan)) {
        _removed.add(x.id);
      }
    }
    _added[i.id] = i;
    _changed();
  }

  void undoAdd(PlanItem i) {
    _added.remove(i.id);
    if (i.isRecordingPlan && !_added.values.any((x) => x.isRecordingPlan)) {
      _removed.removeWhere((id) => items.any((x) => x.id == id && x.isRecordingPlan));
    }
    _changed();
  }

  void choose(Pack? p) {
    newBase = (p == null || p.isCurrent || newBase?.id == p.id) ? null : p;
    _changed();
  }

  void discard() {
    newBase = null;
    _removed.clear();
    _added.clear();
    _changed();
  }

  /// What the plan will contain after the change.
  List<PlanItem> get finalItems => [
        if (newBase != null) newBase!.asItem() else ...items.where((i) => i.kind == ItemKind.basePack),
        ...items.where((i) => i.kind != ItemKind.basePack && !_removed.contains(i.id)),
        ..._added.values,
      ];

  /// Quick estimate before the server prices it: current bill, plus the
  /// pack switch and top-ups, minus removals (GST included, NCF as now).
  double get estimate {
    var t = currentTotal;
    if (newBase != null) t += newBase!.price - (basePack?.price ?? 0);
    t -= removed.fold(0.0, (a, i) => a + i.price);
    t += added.fold(0.0, (a, i) => a + i.price);
    return t < 0 ? 0 : t;
  }

  void _changed() {
    quote = null;
    if (applyState != ApplyState.applying) applyState = ApplyState.idle;
    notifyListeners();
  }

  // ------------------------------------------------------------------ packs

  List<Pack> packs = const [];
  bool loadingPacks = false;

  Future<void> loadPacks() async {
    if (packs.isNotEmpty || loadingPacks || connection == null) return;
    loadingPacks = true;
    notifyListeners();
    packs = await repo.packs(connection!.vc);
    loadingPacks = false;
    notifyListeners();
  }

  final Map<int, Future<List<Channel>>> _channels = {};
  Future<List<Channel>> channelsOf(Pack p) => _channels.putIfAbsent(p.id, () => repo.packChannels(p));
  Future<List<Channel>> currentChannels() {
    final b = basePack;
    if (b == null) return Future.value(const []);
    return _channels.putIfAbsent(-b.id, () => repo.itemChannels(b));
  }

  // ---------------------------------------------------------------- compare

  final List<Pack> compare = [];
  static const maxCompare = 2;

  bool isComparing(Pack p) => compare.contains(p);

  /// False when the list is already full.
  bool toggleCompare(Pack p) {
    if (compare.remove(p)) {
      notifyListeners();
      return true;
    }
    if (compare.length >= maxCompare) return false;
    compare.add(p);
    notifyListeners();
    return true;
  }

  // -------------------------------------------------------------- catalogs

  final Map<ItemKind, List<PlanItem>> _catalogs = {};
  final Set<ItemKind> _loadingCatalog = {};

  List<PlanItem>? catalog(ItemKind k) => _catalogs[k]?.where((i) => !items.any((x) => x.id == i.id)).toList();

  Future<void> loadCatalog(ItemKind k) async {
    if (_catalogs.containsKey(k) || !_loadingCatalog.add(k)) return;
    notifyListeners();
    _catalogs[k] = await repo.catalog(k);
    _loadingCatalog.remove(k);
    notifyListeners();
  }

  // ----------------------------------------------------------- quote, apply

  Quote? quote;
  ApplyState applyState = ApplyState.idle;
  String? orderId;

  /// Snapshot of the applied change for the success screen.
  ({Pack? base, List<PlanItem> added, List<PlanItem> removed, double previous, double next})? applied;

  Future<bool> review() async {
    if (!hasChanges) return false;
    applyState = ApplyState.quoting;
    notifyListeners();
    try {
      quote = await repo.quote(finalItems: finalItems);
      applyState = ApplyState.ready;
      notifyListeners();
      return true;
    } catch (_) {
      applyState = ApplyState.failed;
      notifyListeners();
      return false;
    }
  }

  Future<bool> apply() async {
    final q = quote;
    if (q == null) return false;
    applyState = ApplyState.applying;
    notifyListeners();
    try {
      orderId = await repo.apply(finalItems: finalItems);
      applied = (base: newBase, added: added, removed: removed, previous: currentTotal, next: q.total);
      applyState = ApplyState.done;
      notifyListeners();
      return true;
    } catch (_) {
      applyState = ApplyState.failed;
      notifyListeners();
      return false;
    }
  }

  /// After success: the plan starts fresh from the server next time.
  void finish() {
    final c = connection;
    connection = null;
    _reset();
    if (c != null) open(c);
  }
}

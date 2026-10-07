// What the app shows must match the account: each TV has its own plan, a
// change made in one screen (recharge, new pack, vacation) shows on every
// other one, and the bill shown before Review is the bill Review shows.

import 'package:dishtv_next/data/models.dart';
import 'package:dishtv_next/data/repository.dart';
import 'package:dishtv_next/state/app_store.dart';
import 'package:dishtv_next/state/plan_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _living = '01027734590';
const _bedroom = '01027734601';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

Future<(MockRepository, AppStore)> _app() async {
  final repo = MockRepository(latency: Duration.zero);
  final app = AppStore(repo);
  await app.load();
  return (repo, app);
}

Connection _tv(AppStore app, String vc) => app.connections.firstWhere((c) => c.vc == vc);

void main() {
  test('every TV has its own plan, and its monthly recharge is that plan\'s quote', () async {
    final (repo, app) = await _app();
    final bases = <String>{};
    for (final c in app.connections) {
      final items = await repo.planItems(c.vc);
      final base = items.firstWhere((i) => i.kind == ItemKind.basePack);
      expect(base.name, c.planName, reason: c.label);
      expect((await repo.quote(finalItems: items)).total, c.monthlyRecharge, reason: c.label);
      bases.add(base.name);
    }
    expect(bases, hasLength(app.connections.length));
  });

  test('Explore marks the TV\'s own pack as current', () async {
    final (repo, _) = await _app();
    final current = (await repo.packs(_bedroom)).where((p) => p.isCurrent).map((p) => p.name);
    expect(current, ['Hindi Family Saver']);
  });

  test('a recharge switches a stopped TV back on, and a refresh keeps it', () async {
    final (_, app) = await _app();
    final till = _day(DateTime.now()).add(const Duration(days: 31));
    app.recharge(_bedroom, amount: 404, validTill: till);
    await app.load();
    final c = _tv(app, _bedroom);
    expect(c.status, ConnectionStatus.active);
    expect(c.switchOffDate, till);
    expect(c.balance, 404);
  });

  test('booking a pause moves the switch-off date once; cancelling moves it back', () async {
    final (_, app) = await _app();
    app.recharge(_bedroom, amount: 404, validTill: _day(DateTime.now()).add(const Duration(days: 10)));
    final off = _tv(app, _bedroom).switchOffDate;
    final from = _day(DateTime.now()).add(const Duration(days: 1));

    app.bookVacation(_bedroom, from: from, resume: from.add(const Duration(days: 14)));
    expect(_tv(app, _bedroom).switchOffDate, off.add(const Duration(days: 14)));
    expect(_tv(app, _bedroom).vacationBooked, isTrue);

    // New dates replace the old ones instead of adding to them.
    app.bookVacation(_bedroom, from: from, resume: from.add(const Duration(days: 7)));
    expect(_tv(app, _bedroom).switchOffDate, off.add(const Duration(days: 7)));

    await app.load();
    expect(_tv(app, _bedroom).vacationBooked, isTrue, reason: 'kept after a refresh');

    app.cancelVacation(_bedroom);
    expect(_tv(app, _bedroom).switchOffDate, off);
    expect(_tv(app, _bedroom).vacationBooked, isFalse);
  });

  test('the new bill before Review is the Review quote, and applying it updates the TV', () async {
    final (repo, app) = await _app();
    final plan = PlanStore(repo);
    await plan.open(_tv(app, _living));
    await plan.loadPacks();
    plan.choose(plan.packs.firstWhere((p) => p.name == 'Family Lite Hindi'));
    await pumpEventQueue();

    expect(plan.pricing, isFalse);
    final review = await repo.quote(finalItems: plan.finalItems);
    expect(plan.newBill, review.total);
    expect(plan.newBill, greaterThan(0));

    expect(await plan.review(), isTrue);
    expect(await plan.apply(), isTrue);
    await app.refresh();
    final c = _tv(app, _living);
    expect(c.planName, 'Family Lite Hindi');
    expect(c.monthlyRecharge, review.total);
    final items = await repo.planItems(_living);
    expect(items.firstWhere((i) => i.kind == ItemKind.basePack).name, 'Family Lite Hindi');
  });

  test('the HD pack is added to the plan and turns the TV to HD', () async {
    final (repo, app) = await _app();
    final items = await repo.planItems(_living);
    final hd = await repo.hdUpgrade(_living);
    final next = (await repo.quote(finalItems: [...items, hd])).total;
    await repo.apply(vc: _living, finalItems: [...items, hd]);
    await app.refresh();
    expect(_tv(app, _living).isHd, isTrue);
    expect(_tv(app, _living).monthlyRecharge, next);
  });

  test('discarding clears every pending change', () async {
    final (repo, app) = await _app();
    final plan = PlanStore(repo);
    await plan.open(_tv(app, _living));
    plan.add(const PlanItem(id: 3201, name: 'Animal Planet', kind: ItemKind.alaCarte, price: 2.36));
    expect(plan.hasChanges, isTrue);
    plan.discard();
    expect(plan.hasChanges, isFalse);
    expect(plan.newBill, plan.currentTotal);
  });
}

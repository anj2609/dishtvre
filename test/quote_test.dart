// The sample data must agree with itself: quoting a connection's current
// items gives back its monthly recharge, so "more"/"less" on Review is right.

import 'package:dishtv_next/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('My TV monthly recharge matches the quote of its items', () async {
    final repo = MockRepository(latency: Duration.zero);
    final tv = (await repo.connections()).first;
    final items = await repo.planItems(tv.vc);
    final q = await repo.quote(finalItems: items);
    expect(q.total, tv.monthlyRecharge);
  });
}

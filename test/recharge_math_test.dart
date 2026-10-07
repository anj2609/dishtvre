// Recharge validity: the amount editor and the 1M–12M tiles must agree, and
// month-end dates must not spill into the month after.

import 'package:dishtv_next/ui/recharge/recharge_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 7);

  test('a whole number of months lasts exactly those calendar months', () {
    expect(rechargeTill(start, 747, 249), DateTime(2027, 1, 7)); // 3 months, like the 3M tile
    expect(rechargeTill(start, 249 * 12, 249), DateTime(2027, 10, 7));
  });

  test('other amounts last whole days, without floating-point loss', () {
    expect(rechargeTill(start, 500, 249).difference(start).inDays, 60); // 500 / 8.3 = 60.2
    expect(rechargeTill(start, 59, 249).difference(start).inDays, 7);
  });

  test('a month after 31 Jan is the end of February', () {
    expect(rechargeTill(DateTime(2027, 1, 31), 249, 249), DateTime(2027, 2, 28));
    expect(rechargeTill(DateTime(2028, 1, 31), 249, 249), DateTime(2028, 2, 29));
  });
}

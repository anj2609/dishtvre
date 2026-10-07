// Find my pack: the three picks must make sense against the answers given.

import 'package:dishtv_next/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('budget pick is the cheapest, picks speak your language, and every chosen genre is a reason', () async {
    final repo = MockRepository(latency: Duration.zero);
    final a = AiAnswers()
      ..languages.add('Hindi')
      ..genres.addAll(['Sports', 'Movies'])
      ..viewing = 'Mostly on the TV'
      ..budget = 250;
    final recs = await repo.recommend(a);
    expect(recs, hasLength(3));

    final budget = recs.where((r) => r.label == 'Budget pick');
    for (final b in budget) {
      expect(b.pack.price, lessThan(recs[0].pack.price));
      expect(b.pack.price, lessThan(recs[1].pack.price));
    }
    for (final r in recs) {
      expect(r.pack.languages.first, 'Hindi', reason: '${r.pack.name} is a ${r.pack.languages.first} pack');
      expect(r.reasons.first, allOf(contains('Sports'), contains('Movies')));
    }
  });
}

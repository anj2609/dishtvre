// Filters for Explore packs: sort, language, must-include genres and a
// price band. The apply button shows how many packs the choice leaves.

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../widgets/widgets.dart';

enum SortBy { recommended, priceLow, priceHigh, channels }

enum PriceBand { any, under250, mid, over400 }

const sortLabels = {
  SortBy.recommended: 'Recommended',
  SortBy.priceLow: 'Price: low to high',
  SortBy.priceHigh: 'Price: high to low',
  SortBy.channels: 'Most channels',
};

const priceLabels = {
  PriceBand.any: 'Any price',
  PriceBand.under250: 'Under ₹250',
  PriceBand.mid: '₹250 – ₹400',
  PriceBand.over400: 'Above ₹400',
};

@immutable
class PackFilter {
  const PackFilter({this.sort = SortBy.recommended, this.languages = const {}, this.genres = const {}, this.price = PriceBand.any});

  final SortBy sort;
  final Set<String> languages;
  final Set<String> genres;
  final PriceBand price;

  static const none = PackFilter();

  int get count => languages.length + genres.length + (price != PriceBand.any ? 1 : 0) + (sort != SortBy.recommended ? 1 : 0);

  PackFilter copyWith({SortBy? sort, Set<String>? languages, Set<String>? genres, PriceBand? price}) => PackFilter(
        sort: sort ?? this.sort,
        languages: languages ?? this.languages,
        genres: genres ?? this.genres,
        price: price ?? this.price,
      );

  bool matches(Pack p) {
    if (languages.isNotEmpty && !p.languages.any(languages.contains)) return false;
    if (genres.any((g) => (p.genreCounts[g] ?? 0) == 0)) return false;
    return switch (price) {
      PriceBand.any => true,
      PriceBand.under250 => p.price < 250,
      PriceBand.mid => p.price >= 250 && p.price <= 400,
      PriceBand.over400 => p.price > 400,
    };
  }

  List<Pack> apply(List<Pack> list) {
    final out = list.where(matches).toList();
    switch (sort) {
      case SortBy.priceLow:
        out.sort((a, b) => a.price.compareTo(b.price));
      case SortBy.priceHigh:
        out.sort((a, b) => b.price.compareTo(a.price));
      case SortBy.channels:
        out.sort((a, b) => b.channels.compareTo(a.channels));
      case SortBy.recommended:
        break;
    }
    return out;
  }
}

Future<PackFilter?> showFilters(BuildContext context,
    {required PackFilter current, required List<String> languages, required int Function(PackFilter) countFor}) {
  return showSheet<PackFilter>(
    context,
    title: 'Filters',
    builder: (ctx) => _FilterBody(initial: current, languages: languages, countFor: countFor),
  );
}

class _FilterBody extends StatefulWidget {
  const _FilterBody({required this.initial, required this.languages, required this.countFor});

  final PackFilter initial;
  final List<String> languages;
  final int Function(PackFilter) countFor;

  @override
  State<_FilterBody> createState() => _FilterBodyState();
}

class _FilterBodyState extends State<_FilterBody> {
  late PackFilter _d = widget.initial;
  static const _genres = ['Sports', 'Movies', 'Kids', 'News', 'Music', 'Infotainment'];

  Set<String> _flip(Set<String> s, String v) => s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  Widget _section(String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(top: S.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.label),
          const SizedBox(height: S.sm),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final n = widget.countFor(_d);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(S.page, 0, S.page, S.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _section('Sort by', [
              for (final e in sortLabels.entries) Pick(label: e.value, selected: _d.sort == e.key, onTap: () => setState(() => _d = _d.copyWith(sort: e.key))),
            ]),
            _section('Language', [
              for (final l in widget.languages)
                Pick(label: l, selected: _d.languages.contains(l), onTap: () => setState(() => _d = _d.copyWith(languages: _flip(_d.languages, l)))),
            ]),
            _section('Must include', [
              for (final g in _genres)
                Pick(label: g, selected: _d.genres.contains(g), onTap: () => setState(() => _d = _d.copyWith(genres: _flip(_d.genres, g)))),
            ]),
            _section('Monthly price', [
              for (final e in priceLabels.entries)
                Pick(label: e.value, selected: _d.price == e.key, onTap: () => setState(() => _d = _d.copyWith(price: e.key))),
            ]),
          ]),
        ),
      ),
      BottomBar(
        child: Row(children: [
          SizedBox(
            width: 120,
            child: SecondaryButton(label: 'Clear all', onTap: _d.count == 0 ? null : () => setState(() => _d = PackFilter.none)),
          ),
          const SizedBox(width: S.md),
          Expanded(
            child: PrimaryButton(
              label: n == 0 ? 'No packs match' : 'Show $n ${n == 1 ? 'pack' : 'packs'}',
              onTap: n == 0 ? null : () => Navigator.of(context).pop(_d),
            ),
          ),
        ]),
      ),
    ]);
  }
}

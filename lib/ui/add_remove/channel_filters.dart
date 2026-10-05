// Filters for Add / Remove: a two-pane sheet. Categories on the left
// (Genre, Languages, Quality, Broadcasters), their options on the right,
// Clear filters and Apply at the bottom.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../widgets/widgets.dart';

@immutable
class ChannelFilter {
  const ChannelFilter({this.genres = const {}, this.languages = const {}, this.broadcasters = const {}, this.hd = false});

  final Set<String> genres;
  final Set<String> languages;
  final Set<String> broadcasters;

  /// Quality: SD (false) or HD (true). Mirrors the SD / HD switch.
  final bool hd;

  /// Active filters, for the badge on the filter button (quality has its own switch).
  int get count => genres.length + languages.length + broadcasters.length;

  ChannelFilter copyWith({Set<String>? genres, Set<String>? languages, Set<String>? broadcasters, bool? hd}) => ChannelFilter(
        genres: genres ?? this.genres,
        languages: languages ?? this.languages,
        broadcasters: broadcasters ?? this.broadcasters,
        hd: hd ?? this.hd,
      );
}

enum _Pane { genre, languages, quality, broadcasters }

Future<ChannelFilter?> showChannelFilters(
  BuildContext context, {
  required ChannelFilter current,
  required List<String> genres,
  required List<String> languages,
  required List<String> broadcasters,
}) {
  return showSheet<ChannelFilter>(
    context,
    title: 'Filters',
    builder: (ctx) => _FilterSheet(current: current, genres: genres, languages: languages, broadcasters: broadcasters),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current, required this.genres, required this.languages, required this.broadcasters});

  final ChannelFilter current;
  final List<String> genres;
  final List<String> languages;
  final List<String> broadcasters;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ChannelFilter _d = widget.current;
  _Pane _pane = _Pane.genre;

  static String _title(_Pane p) => switch (p) {
        _Pane.genre => 'Genre',
        _Pane.languages => 'Languages',
        _Pane.quality => 'Quality',
        _Pane.broadcasters => 'Broadcasters',
      };

  Set<String> _flip(Set<String> s, String v) => s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  int _countOf(_Pane p) => switch (p) {
        _Pane.genre => _d.genres.length,
        _Pane.languages => _d.languages.length,
        _Pane.quality => 0,
        _Pane.broadcasters => _d.broadcasters.length,
      };

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // As tall as is comfortable; Flexible lets it shrink on short screens.
    final paneH = math.min(460.0, math.max(160.0, mq.size.height * 0.5));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(height: 1, color: C.line),
      Flexible(
        child: SizedBox(
          height: paneH,
          child: LayoutBuilder(builder: (context, box) {
            final leftW = (box.maxWidth * 0.36).clamp(104.0, 170.0);
            final leftStyle = wordSafe(context, _Pane.values.map(_title), T.label.copyWith(fontSize: 14), leftW - 30);
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Categories.
              SizedBox(
                width: leftW,
                child: ListView(padding: const EdgeInsets.symmetric(vertical: S.sm), children: [
                  for (final p in _Pane.values) _paneTab(p, leftStyle),
                ]),
              ),
              const VerticalDivider(width: 1, thickness: 1, color: C.line),
              // Options for the selected category.
              Expanded(child: _options()),
            ]);
          }),
        ),
      ),
      const Divider(height: 1, color: C.line),
      Padding(
        padding: EdgeInsets.fromLTRB(S.page, S.md, S.page, S.md + mq.padding.bottom),
        child: Row(children: [
          Expanded(child: SecondaryButton(label: 'Clear filters', onTap: () => setState(() => _d = ChannelFilter(hd: _d.hd)))),
          const SizedBox(width: S.md),
          Expanded(child: PrimaryButton(label: 'Apply', onTap: () => Navigator.of(context).pop(_d))),
        ]),
      ),
    ]);
  }

  Widget _paneTab(_Pane p, TextStyle style) {
    final on = p == _pane;
    final n = _countOf(p);
    return Semantics(
      container: true,
      button: true,
      selected: on,
      label: '${_title(p)}${n > 0 ? ', $n selected' : ''}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => setState(() => _pane = p),
          child: Container(
            padding: const EdgeInsets.fromLTRB(S.lg, 14, S.sm, 14),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: on ? C.brand : Colors.transparent, width: 3))),
            child: Row(children: [
              Expanded(child: Text(_title(p), style: style.copyWith(color: on ? C.ink : C.muted, fontWeight: on ? FontWeight.w800 : FontWeight.w600))),
              if (n > 0) Text('$n', style: T.label.copyWith(fontSize: 12, color: C.brand)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _options() {
    if (_pane == _Pane.quality) {
      return ListView(padding: EdgeInsets.zero, children: [
        _option('SD channels', checked: !_d.hd, radio: true, onTap: () => setState(() => _d = _d.copyWith(hd: false))),
        _option('HD channels', checked: _d.hd, radio: true, onTap: () => setState(() => _d = _d.copyWith(hd: true))),
      ]);
    }
    final (values, selected, update) = switch (_pane) {
      _Pane.genre => (widget.genres, _d.genres, (Set<String> s) => _d.copyWith(genres: s)),
      _Pane.languages => (widget.languages, _d.languages, (Set<String> s) => _d.copyWith(languages: s)),
      _ => (widget.broadcasters, _d.broadcasters, (Set<String> s) => _d.copyWith(broadcasters: s)),
    };
    return ListView(padding: EdgeInsets.zero, children: [
      for (final v in values) _option(v, checked: selected.contains(v), onTap: () => setState(() => _d = update(_flip(selected, v)))),
    ]);
  }

  // One option: a square checkbox (or a round radio for Quality) and its name.
  Widget _option(String label, {required bool checked, required VoidCallback onTap, bool radio = false}) {
    return Semantics(
      container: true,
      checked: checked,
      inMutuallyExclusiveGroup: radio,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(S.lg, 14, S.md, 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: checked ? C.brand : null,
                  shape: radio ? BoxShape.circle : BoxShape.rectangle,
                  border: Border.all(color: checked ? C.brand : C.lineStrong, width: 1.5),
                ),
                child: checked ? Icon(radio ? Icons.circle : Icons.check_rounded, size: radio ? 8 : 16, color: Colors.white) : null,
              ),
              const SizedBox(width: S.md),
              Expanded(child: Text(label, style: T.body.copyWith(color: C.ink))),
            ]),
          ),
        ),
      ),
    );
  }
}

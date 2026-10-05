// The app talks to data only through [Repository]. [MockRepository] serves
// realistic sample data with a short delay; a live implementation can map
// the DishTV APIs onto the same calls later without touching any screen.

import 'dart:math';

import 'models.dart';

abstract class Repository {
  Future<Subscriber> subscriber();
  Future<List<Connection>> connections();
  Future<Warranty> warranty(String vc);
  Future<Subscriber> updateSubscriber(Subscriber s);
  Future<List<PlanItem>> planItems(String vc);
  Future<List<Pack>> packs(String vc);
  Future<List<Channel>> packChannels(Pack pack);
  Future<List<Channel>> itemChannels(PlanItem item);
  Future<List<PlanItem>> catalog(ItemKind kind);
  Future<Quote> quote({required List<PlanItem> finalItems});
  Future<String> apply({required List<PlanItem> finalItems});

  // AI recommender.
  Future<AiOptions> aiOptions();
  Future<List<Recommendation>> recommend(AiAnswers answers);
}

class AiOptions {
  const AiOptions({required this.languages, required this.genres, required this.viewing, required this.budgets});
  final List<String> languages;
  final List<String> genres;
  final List<String> viewing;
  final List<int> budgets;
}

class AiAnswers {
  AiAnswers();
  final Set<String> languages = {};
  final Set<String> genres = {};
  String? viewing;
  bool hd = false;
  int? budget;
}

class MockRepository implements Repository {
  MockRepository({this.latency = const Duration(milliseconds: 450)});

  final Duration latency;
  Future<T> _later<T>(T Function() f) => Future.delayed(latency, f);

  static final _now = DateTime.now();

  @override
  Future<Subscriber> subscriber() => _later(() => _subscriber);

  Subscriber _subscriber = Subscriber(
    name: 'Kashyap Raina',
    smsId: 35663,
    mobile: '9876543210',
    email: 'kashyap.raina@example.com',
    address: const Address(
      house: 'House 24',
      street: 'Sector 18',
      landmark: 'Near City Centre Metro',
      city: 'Noida',
      pincode: '201301',
      state: 'Uttar Pradesh',
    ),
    memberSince: DateTime(2021, 11, 20),
  );

  @override
  Future<Subscriber> updateSubscriber(Subscriber s) => _later(() => _subscriber = s);

  @override
  Future<Warranty> warranty(String vc) => _later(() {
        // Each connection was installed on a different date; the box and dish
        // are covered for five years, the remote for one.
        final installed = switch ((int.tryParse(vc.isEmpty ? '' : vc.substring(vc.length - 1)) ?? 0) % 3) {
          0 => DateTime(2022, 8, 11),
          1 => DateTime(2023, 3, 2),
          _ => DateTime(2021, 11, 20),
        };
        DateTime plus(int years) => DateTime(installed.year + years, installed.month, installed.day);
        return Warranty(installedOn: installed, items: [
          WarrantyItem(part: 'Set-top box', model: 'HD-4410', until: plus(5)),
          WarrantyItem(part: 'Dish antenna & LNB', until: plus(5)),
          WarrantyItem(part: 'Remote control', until: plus(1)),
        ]);
      });

  @override
  Future<List<Connection>> connections() => _later(() => [
        Connection(
          vc: '01514457750',
          label: 'My TV',
          type: ConnectionType.parent,
          status: ConnectionStatus.active,
          monthlyRecharge: 1125, // = quote of its current items (packs + NCF + GST)
          balance: 113.27,
          switchOffDate: _now.add(const Duration(days: 4)),
          lockInUntil: _now.add(const Duration(days: 27)),
          planName: 'My Home Pack New NCF',
          isHd: true,
        ),
        Connection(
          vc: '01027734590',
          label: 'Living Room',
          type: ConnectionType.child,
          status: ConnectionStatus.vacation,
          monthlyRecharge: 329,
          balance: 18,
          switchOffDate: _now.add(const Duration(days: 17)),
          planName: 'Super Family Hindi',
          isHd: false,
        ),
        Connection(
          vc: '01027734601',
          label: 'Bedroom',
          type: ConnectionType.child,
          status: ConnectionStatus.deactivated,
          monthlyRecharge: 249,
          balance: 0,
          switchOffDate: _now.subtract(const Duration(days: 9)),
          planName: 'Hindi Family Saver',
          isHd: false,
        ),
      ]);

  @override
  Future<List<PlanItem>> planItems(String vc) => _later(() => _withLogos([
        const PlanItem(
            id: 9001, name: 'My Home Pack New NCF', kind: ItemKind.basePack, price: 579, channels: 249, hdChannels: 32, isHd: true, language: 'Hindi'),
        const PlanItem(id: 3101, name: 'Star Sports 1 Hindi', kind: ItemKind.alaCarte, price: 22.42, broadcaster: 'Disney Star', language: 'Hindi'),
        const PlanItem(
            id: 3102, name: 'Sony Ten 3 HD', kind: ItemKind.alaCarte, price: 20.06, broadcaster: 'Sony', language: 'Hindi', isHd: true, hdChannels: 1),
        const PlanItem(
            id: 3103,
            name: 'Colors Cineplex',
            kind: ItemKind.alaCarte,
            price: 11.80,
            broadcaster: 'Viacom18',
            language: 'Hindi',
            lockedReason: 'Lock-in until next month'),
        const PlanItem(
            id: 4101, name: 'Star Value Pack Hindi', kind: ItemKind.bouquet, price: 57.82, channels: 18, broadcaster: 'Disney Star', language: 'Hindi'),
        const PlanItem(id: 5102, name: 'Kids Add-on', kind: ItemKind.addOn, price: 34.22, channels: 6, broadcaster: 'DishTV'),
        const PlanItem(
            id: 5103,
            name: 'Watcho Exclusive',
            kind: ItemKind.addOn,
            group: 'OTT',
            price: 49,
            channels: 0,
            broadcaster: 'DishTV',
            logoUrl: '${_ottBase}watcho-exclusives.webp'),
        const PlanItem(
            id: 5104, name: 'Zee5 Premium', kind: ItemKind.addOn, group: 'OTT', price: 49, channels: 0, broadcaster: 'Zee', logoUrl: '${_ottBase}zee5.webp'),
        const PlanItem(id: 5101, name: 'Recording (1 month)', kind: ItemKind.addOn, group: 'Active Services', price: 29.50, channels: 0, broadcaster: 'DishTV'),
      ]));

  // ------------------------------------------------------------------ packs

  static const _tvSpecs = [
    (6101, 'Family Lite Hindi', 165.0, ['Hindi'], {'Entertainment': 34, 'Movies': 20, 'News': 46, 'Kids': 3, 'Music': 4, 'Sports': 2, 'Devotional': 18}, 72.0),
    (
      6102,
      'Hindi Family Saver',
      249.0,
      ['Hindi'],
      {'Entertainment': 38, 'Movies': 18, 'News': 30, 'Kids': 8, 'Music': 10, 'Sports': 3, 'Devotional': 12},
      42.0
    ),
    (
      6103,
      'Super Family Hindi',
      302.17,
      ['Hindi', 'English'],
      {'Entertainment': 48, 'Movies': 28, 'News': 36, 'Kids': 14, 'Music': 14, 'Sports': 10, 'Infotainment': 10},
      20.0
    ),
    (
      6104,
      'Sports Plus Hindi',
      389.0,
      ['Hindi', 'English'],
      {'Entertainment': 40, 'Movies': 22, 'News': 32, 'Kids': 9, 'Music': 10, 'Sports': 22, 'Infotainment': 8},
      55.0
    ),
    (
      6105,
      'Kids & Family English',
      279.0,
      ['English', 'Hindi'],
      {'Entertainment': 30, 'Movies': 16, 'News': 24, 'Kids': 19, 'Music': 8, 'Infotainment': 14},
      42.0
    ),
    (
      6106,
      'Marathi Family',
      229.0,
      ['Marathi', 'Hindi'],
      {'Entertainment': 32, 'Movies': 16, 'News': 28, 'Kids': 6, 'Music': 8, 'Sports': 3, 'Devotional': 10},
      42.0
    ),
    (
      6107,
      'Bangla Family',
      239.0,
      ['Bangla', 'Hindi'],
      {'Entertainment': 30, 'Movies': 18, 'News': 26, 'Kids': 6, 'Music': 8, 'Sports': 3, 'Devotional': 10},
      42.0
    ),
  ];

  static const _ottSpecs = [
    (
      7101,
      'Family + Watcho',
      399.0,
      ['Hindi'],
      {'Entertainment': 44, 'Movies': 24, 'News': 34, 'Kids': 12, 'Music': 12, 'Sports': 6},
      55.0,
      ['Watcho', 'Zee5']
    ),
    (
      7102,
      'Mega Hindi + SonyLIV',
      499.0,
      ['Hindi', 'English'],
      {'Entertainment': 52, 'Movies': 32, 'News': 38, 'Kids': 16, 'Music': 16, 'Sports': 18, 'Infotainment': 12},
      70.0,
      ['SonyLIV', 'Watcho']
    ),
    (
      7103,
      'Entertainment + JioHotstar',
      449.0,
      ['Hindi', 'English'],
      {'Entertainment': 50, 'Movies': 26, 'News': 30, 'Kids': 10, 'Music': 12, 'Sports': 10},
      55.0,
      ['JioHotstar']
    ),
  ];

  Pack _pack(int id, String name, double price, List<String> langs, Map<String, int> genres, double ncf, {List<String> ott = const [], required bool hd}) {
    final total = genres.values.fold(0, (a, b) => a + b);
    return Pack(
      id: hd ? id + 500 : id,
      name: hd ? '$name HD' : name,
      type: ott.isEmpty ? PackType.tv : PackType.ottTv,
      isHd: hd,
      price: hd ? price + 80 : price,
      channels: total,
      hdChannels: hd ? (total * 0.18).round() : (total * 0.02).round(),
      languages: langs,
      ottApps: ott,
      ottLogoUrls: {
        for (final o in ott)
          if (_ottLogos[o] != null) o: _ottLogos[o]!
      },
      ncf: ncf,
      genreCounts: genres,
      lockIn: id == 6104,
      ruleMessage: id == 6106 ? 'Add at least one Marathi regional channel with this pack.' : null,
    );
  }

  static const _ottBase = 'https://www.dishtv.in/content/dam/dishtv-aem-web-platform/mogiio/images/dishsmartottapps/';
  static const _ottLogos = {
    'Watcho': '${_ottBase}watcho-exclusives.webp',
    'Zee5': '${_ottBase}zee5.webp',
    'SonyLIV': '${_ottBase}sonyliv.webp',
    'JioHotstar': '${_ottBase}jiohotstar.webp',
  };

  List<Pack> _allPacks() => [
        for (final hd in const [false, true]) ...[
          for (final s in _tvSpecs) _pack(s.$1, s.$2, s.$3, s.$4, s.$5, s.$6, hd: hd),
          for (final s in _ottSpecs) _pack(s.$1, s.$2, s.$3, s.$4, s.$5, s.$6, ott: s.$7, hd: hd),
        ],
      ];

  @override
  Future<List<Pack>> packs(String vc) => _later(_allPacks);

  static const _pool = {
    'Entertainment': [
      'Star Plus',
      'Colors',
      'Sony TV',
      'Zee TV',
      '&TV',
      'Star Bharat',
      'Sony SAB',
      'Colors Rishtey',
      'Dangal',
      'Big Magic',
      'Zee Anmol',
      'Sony Pal',
      'Star Utsav',
      'Shemaroo TV',
      'Zee Marathi',
      'Star Pravah',
      'Colors Marathi',
      'Sony Marathi',
      'Zee Yuva',
      'Colors Bangla',
      'Zee Bangla',
      'Star Jalsha',
      'Sun Bangla',
      'Sun TV',
      'Gemini TV',
      'Asianet',
      'Colors Kannada',
      'Zee Kannada',
      'Star Maa',
      'Zee Tamil',
      'Zee Telugu',
      'Colors Tamil',
      'Udaya TV',
      'Surya TV',
      'Zee Keralam',
      'Sony Aath',
      'DD National',
      'DD Bharati',
      'Enterr10',
      'Atrangii',
      'Manoranjan TV',
      'Colors Gujarati',
      'Zee Punjabi',
      'Star Suvarna',
      'Vijay TV',
      'Mazhavil Manorama',
      'Zee Sarthak',
      'Colors Odia',
      'Tarang TV',
      'Zee Ganga',
      'Dangal 2',
      'Nazara',
      'Sun Neo',
      'Colors Infinity',
      'Zee Cafe',
      'Comedy Central',
      'Zing',
      'Big Ganga',
    ],
    'Movies': [
      'Star Gold',
      'Sony Max',
      'Zee Cinema',
      '&Pictures',
      'Colors Cineplex',
      'Star Movies',
      'Movies Now',
      'Zee Anmol Cinema',
      'Sony Max 2',
      'Star Gold 2',
      'Star Gold Select',
      'Zee Action',
      'Zee Classic',
      'Sony Wah',
      'B4U Movies',
      'Zee Bollywood',
      'UTV Movies',
      'UTV Action',
      'Sony Pix',
      'Romedy Now',
      '&flix',
      'Zee Talkies',
      'Jalsha Movies',
      'Zee Bangla Cinema',
      'KTV',
      'Gemini Movies',
      'Star Maa Movies',
      'Asianet Movies',
      'Udaya Movies',
      'Zee Cinemalu',
      'Colors Cineplex Superhits',
      'Dhinchaak',
      'Shemaroo MarathiBana',
      'Sony Max 1',
      'Bhojpuri Cinema',
      'Zee Picchar',
      'Enterr10 Movies',
    ],
    'News': [
      'Aaj Tak',
      'ABP News',
      'India TV',
      'NDTV India',
      'Zee News',
      'Times Now',
      'Republic TV',
      'CNN-News18',
      'CNBC Awaaz',
      'News18 India',
      'Republic Bharat',
      'TV9 Bharatvarsh',
      'News24',
      'DD News',
      'India Today',
      'NDTV 24x7',
      'WION',
      'Mirror Now',
      'CNBC TV18',
      'ET Now',
      'Zoom',
      'Zee Business',
      'Times Now Navbharat',
      'Good News Today',
      'News Nation',
      'India News',
      'ABP Majha',
      'Zee 24 Taas',
      'TV9 Marathi',
      'ABP Ananda',
      'Zee 24 Ghanta',
      'Puthiya Thalaimurai',
      'Sun News',
      'TV9 Telugu',
      'NTV',
      'Asianet News',
      'Manorama News',
      'TV9 Kannada',
      'Public TV',
      'News18 Lokmat',
      'News18 Bangla',
      'ABP Asmita',
      'TV9 Gujarati',
      'DD Sahyadri',
      'BBC World News',
      'Al Jazeera',
      'CNN International',
    ],
    'Kids': [
      'Cartoon Network',
      'Pogo',
      'Nick',
      'Disney Channel',
      'Sony Yay',
      'Discovery Kids',
      'Hungama',
      'Nick Jr',
      'Super Hungama',
      'Disney Junior',
      'Sonic',
      'Chintu TV',
      'Kushi TV',
      'Chutti TV',
      'Gubbare',
      'ETV Bal Bharat',
      'Kochu TV',
      'Baby TV',
      'Nick Junior',
    ],
    'Music': [
      'MTV',
      '9XM',
      'B4U Music',
      'Mastiii',
      'Music India',
      'MTV Beats',
      '9X Jhakaas',
      'Sangeet Bangla',
      'Sun Music',
      'Gemini Music',
      'Udaya Music',
      'Raj Musix',
      'E24',
      'Sony Mix',
      '9X Tashan',
      'Sangeet Marathi',
      'PTC Music',
      '9XO',
      'B4U Kadak',
    ],
    'Sports': [
      'Star Sports 1',
      'Star Sports 2',
      'Star Sports 2 Hindi',
      'Star Sports Khel',
      'Star Sports 2 Tamil',
      'Star Sports 2 Telugu',
      'Sony Ten 1',
      'Sony Ten 2',
      'Sony Ten 3',
      'Sports18',
      'DD Sports',
      'Star Sports 1 Hindi',
      'Star Sports 3',
      'Star Sports Select 1',
      'Star Sports Select 2',
      'Star Sports First',
      'Eurosport',
      'Star Sports 1 Tamil',
      'Star Sports 1 Telugu',
      'Star Sports 1 Kannada',
      'Star Sports 2 Kannada',
      'Sony Sports Ten 5',
    ],
    'Infotainment': [
      'Discovery',
      'National Geographic',
      'History TV18',
      'Animal Planet',
      'TLC',
      'Sony BBC Earth',
      'Nat Geo Wild',
      'Discovery Science',
      'Discovery Turbo',
      'Fox Life',
      'Investigation Discovery',
      'Epic',
      'Food Food',
      'Zee Zest',
      'Discovery Tamil',
      'Living Foodz',
    ],
    'Devotional': [
      'Aastha',
      'Sanskar',
      'Shubh TV',
      'Aastha Bhajan',
      'Divya',
      'Satsang',
      'Paras',
      'Sadhna',
      'Arihant',
      'Jinvani',
      'Katyayani',
      'Shraddha MH One',
      'Peace of Mind',
      'God TV',
      'Vedic',
      'Shalom',
      'Sai Leela',
      'Lord Buddha TV',
      'SVBC',
    ],
  };

  /// Public channel logos on dishtv.in, named by channel slug (same
  /// convention the current app uses).
  static const _logoBase = 'https://www.dishtv.in/content/dam/dishtv-aem-web-platform/mogiio/images/channels/';
  static const _logoSlugs = {
    'National Geographic': 'national-geographic-channel',
    'Sony TV': 'sony-entertainment-television',
    'Sports18': 'sports18-1',
  };

  static String _logo(String name) {
    final n = name.replaceAll(RegExp(r'\s+HD$'), '').trim();
    final slug = _logoSlugs[n] ?? n.replaceAll('&', 'and').replaceAll(RegExp(r'[+./]'), '').replaceAll(RegExp(r'\s+'), '-').toLowerCase();
    return '$_logoBase$slug.webp';
  }

  /// Language of regional channels; everything else takes the pack's language.
  static const _regional = {
    'Marathi': ['Marathi', 'Star Pravah', 'Zee Yuva', 'ABP Majha', 'Zee 24 Taas', 'News18 Lokmat', 'DD Sahyadri', 'Zee Talkies', 'Shemaroo MarathiBana'],
    'Bangla': ['Bangla', 'Star Jalsha', 'Jalsha Movies', 'ABP Ananda', 'Zee 24 Ghanta', 'Sangeet Bangla', 'Enterr10 Bangla'],
    'Tamil': ['Tamil', 'Sun TV', 'Vijay TV', 'KTV', 'Puthiya Thalaimurai', 'Sun News', 'Sun Music', 'Chutti TV', 'Raj Musix'],
    'Telugu': ['Telugu', 'Gemini', 'Star Maa', 'Zee Cinemalu', 'TV9 Telugu', 'NTV', 'Kushi TV', 'ETV Bal Bharat', 'SVBC'],
    'Kannada': ['Kannada', 'Udaya', 'Star Suvarna', 'TV9 Kannada', 'Public TV', 'Chintu TV', 'Raj Musix Kannada'],
    'Malayalam': ['Asianet', 'Surya TV', 'Zee Keralam', 'Mazhavil Manorama', 'Flowers', 'Manorama News', 'Kochu TV'],
    'Gujarati': ['Gujarati', 'ABP Asmita', 'TV9 Gujarati'],
    'Punjabi': ['Punjabi'],
    'Odia': ['Odia', 'Zee Sarthak', 'Tarang TV'],
    'Bhojpuri': ['Bhojpuri', 'Big Ganga', 'Zee Ganga'],
    'English': [
      'Star Movies',
      'Sony Pix',
      'Romedy Now',
      'MN+',
      'Movies Now',
      '&flix',
      'Times Now',
      'India Today',
      'NDTV 24x7',
      'WION',
      'Mirror Now',
      'CNBC TV18',
      'ET Now',
      'NDTV Profit',
      'BBC World News',
      'Al Jazeera',
      'CNN International',
      'DW',
      'CNN-News18',
      'Zee Cafe',
      'Comedy Central',
      'Colors Infinity',
      'Nick Jr',
      'Disney Junior'
    ],
  };

  static String? _languageOf(String name) {
    for (final e in _regional.entries) {
      if (e.value.any((v) => name == v || name.startsWith('$v ') || name.endsWith(' $v'))) return e.key;
    }
    return null;
  }

  /// Bouquets and add-ons show their flagship channel's logo.
  static const _flagship = {
    'Star Value Pack Hindi': 'Star Plus',
    'Sony Happy India Smart': 'Sony TV',
    'Zee Family Pack Hindi': 'Zee TV',
    'Colors Wala Hindi Plus': 'Colors',
    'Sun Telugu Basic': 'Gemini TV',
    'Discovery Kids & Family': 'Discovery Kids',
    'Sports Add-on': 'Star Sports 1',
    'Kids Add-on': 'Cartoon Network',
    'Regional Marathi Add-on': 'Star Pravah',
    'Devotional Add-on': 'Aastha',
  };

  static List<PlanItem> _withLogos(List<PlanItem> items) => [
        for (final i in items)
          if (i.kind == ItemKind.alaCarte) i.withLogo(_logo(i.name)) else if (_flagship[i.name] != null) i.withLogo(_logo(_flagship[i.name]!)) else i,
      ];

  List<Channel> _channelsFor(Map<String, int> genres, {required bool hd, String language = 'Hindi', int seed = 0}) {
    final out = <Channel>[];
    for (final e in genres.entries) {
      final names = _pool[e.key] ?? const ['Channel'];
      for (var i = 0; i < e.value; i++) {
        final n = names[(i + seed) % names.length];
        out.add(Channel(
          name: i < names.length ? n : '$n ${i ~/ names.length + 1}',
          genre: e.key,
          language: _languageOf(n) ?? language,
          isHd: hd && i < 3,
          logoUrl: _logo(n),
        ));
      }
    }
    return out;
  }

  @override
  Future<List<Channel>> packChannels(Pack pack) =>
      _later(() => _channelsFor(pack.genreCounts, hd: pack.isHd, language: pack.languages.first, seed: pack.id % 500));

  @override
  Future<List<Channel>> itemChannels(PlanItem item) => _later(() {
        if (item.kind == ItemKind.basePack) {
          return _channelsFor(
            const {'Entertainment': 48, 'Movies': 30, 'News': 44, 'Kids': 14, 'Music': 14, 'Sports': 9, 'Infotainment': 12, 'Devotional': 14},
            hd: item.isHd,
          );
        }
        if (item.kind == ItemKind.bouquet) {
          return _channelsFor(const {'Entertainment': 6, 'Movies': 5, 'Sports': 4, 'Kids': 3}, hd: false);
        }
        return [Channel(name: item.name, genre: 'Entertainment', language: item.language, isHd: item.isHd, logoUrl: _logo(item.name))];
      });

  // --------------------------------------------------------------- catalogs

  @override
  Future<List<PlanItem>> catalog(ItemKind kind) => _later(() => switch (kind) {
        ItemKind.alaCarte => _withLogos(_alaCarte),
        ItemKind.bouquet => _withLogos(_bouquets),
        ItemKind.addOn => _withLogos(_addOns),
        ItemKind.basePack => const <PlanItem>[],
      });

  static const _alaCarte = [
    PlanItem(id: 3201, name: 'Animal Planet', kind: ItemKind.alaCarte, genre: 'Infotainment', price: 2.36, broadcaster: 'Discovery', language: 'English'),
    PlanItem(id: 3202, name: 'Asianet Movies', kind: ItemKind.alaCarte, genre: 'Movies', price: 22.42, broadcaster: 'Disney Star', language: 'Malayalam'),
    PlanItem(id: 3203, name: 'BBC World News', kind: ItemKind.alaCarte, genre: 'News', price: 1.77, broadcaster: 'BBC', language: 'English'),
    PlanItem(id: 3204, name: 'Cartoon Network', kind: ItemKind.alaCarte, genre: 'Kids', price: 5.90, broadcaster: 'Warner Bros', language: 'Hindi'),
    PlanItem(id: 3205, name: 'Chintu TV', kind: ItemKind.alaCarte, genre: 'Kids', price: 7.08, broadcaster: 'Sun TV', language: 'Kannada'),
    PlanItem(id: 3206, name: 'Big Magic', kind: ItemKind.alaCarte, genre: 'Entertainment', price: 1.18, broadcaster: 'Zee', language: 'Hindi'),
    PlanItem(id: 3207, name: '&Pictures', kind: ItemKind.alaCarte, genre: 'Movies', price: 20.06, broadcaster: 'Zee', language: 'Hindi'),
    PlanItem(
        id: 3208,
        name: 'Zee Cinema HD',
        kind: ItemKind.alaCarte,
        genre: 'Movies',
        price: 22.42,
        broadcaster: 'Zee',
        language: 'Hindi',
        isHd: true,
        hdChannels: 1),
    PlanItem(id: 3209, name: 'Discovery Kids', kind: ItemKind.alaCarte, genre: 'Kids', price: 5.90, broadcaster: 'Discovery', language: 'Hindi'),
    PlanItem(id: 3210, name: 'Nick Jr', kind: ItemKind.alaCarte, genre: 'Kids', price: 2.36, broadcaster: 'Viacom18', language: 'English'),
    PlanItem(
        id: 3211,
        name: 'Star Movies HD',
        kind: ItemKind.alaCarte,
        genre: 'Movies',
        price: 22.42,
        broadcaster: 'Disney Star',
        language: 'English',
        isHd: true,
        hdChannels: 1),
    PlanItem(id: 3212, name: 'Sony Max', kind: ItemKind.alaCarte, genre: 'Movies', price: 15.34, broadcaster: 'Sony', language: 'Hindi'),
    PlanItem(
        id: 3213,
        name: 'Sony Ten 1 HD',
        kind: ItemKind.alaCarte,
        genre: 'Sports',
        price: 22.42,
        broadcaster: 'Sony',
        language: 'English',
        isHd: true,
        hdChannels: 1),
    PlanItem(id: 3214, name: 'MTV Beats', kind: ItemKind.alaCarte, genre: 'Music', price: 1.18, broadcaster: 'Viacom18', language: 'Hindi'),
    PlanItem(id: 3215, name: 'Colors Marathi', kind: ItemKind.alaCarte, genre: 'Entertainment', price: 11.80, broadcaster: 'Viacom18', language: 'Marathi'),
    PlanItem(id: 3216, name: 'Star Jalsha', kind: ItemKind.alaCarte, genre: 'Entertainment', price: 22.42, broadcaster: 'Disney Star', language: 'Bangla'),
    PlanItem(id: 3217, name: 'Aastha Bhajan', kind: ItemKind.alaCarte, genre: 'Devotional', price: 1.18, broadcaster: 'Aastha', language: 'Hindi'),
    PlanItem(
        id: 3218,
        name: 'History TV18 HD',
        kind: ItemKind.alaCarte,
        genre: 'Infotainment',
        price: 5.90,
        broadcaster: 'A+E Networks',
        language: 'English',
        isHd: true,
        hdChannels: 1),
    PlanItem(id: 3219, name: 'Sun TV', kind: ItemKind.alaCarte, genre: 'Entertainment', price: 22.42, broadcaster: 'Sun TV', language: 'Tamil'),
    PlanItem(id: 3220, name: 'Gemini TV', kind: ItemKind.alaCarte, genre: 'Entertainment', price: 22.42, broadcaster: 'Sun TV', language: 'Telugu'),
    // Popular channels, with why they're trending near you.
    PlanItem(
        id: 3221,
        name: 'Colors',
        kind: ItemKind.alaCarte,
        genre: 'Entertainment',
        price: 18.88,
        broadcaster: 'Viacom18',
        language: 'Hindi',
        trend: '#1 nearby'),
    PlanItem(
        id: 3222,
        name: 'Discovery',
        kind: ItemKind.alaCarte,
        genre: 'Infotainment',
        price: 4.72,
        broadcaster: 'Discovery',
        language: 'English',
        trend: 'New shows'),
    PlanItem(
        id: 3223, name: 'Zee TV', kind: ItemKind.alaCarte, genre: 'Entertainment', price: 22.42, broadcaster: 'Zee', language: 'Hindi', trend: 'Most added'),
    PlanItem(id: 3224, name: 'Star Utsav', kind: ItemKind.alaCarte, genre: 'Entertainment', price: 1.18, broadcaster: 'Disney Star', language: 'Hindi'),
    PlanItem(id: 3225, name: 'Zoom', kind: ItemKind.alaCarte, genre: 'Music', price: 1.18, broadcaster: 'Times Network', language: 'Hindi'),
    PlanItem(
        id: 3226,
        name: 'Star Sports 2',
        kind: ItemKind.alaCarte,
        genre: 'Sports',
        price: 22.42,
        broadcaster: 'Disney Star',
        language: 'English',
        trend: 'Top rated'),
    PlanItem(id: 3227, name: 'Sony Ten 2', kind: ItemKind.alaCarte, genre: 'Sports', price: 22.42, broadcaster: 'Sony', language: 'English'),
    PlanItem(id: 3228, name: 'DD Sports', kind: ItemKind.alaCarte, genre: 'Sports', price: 0.59, broadcaster: 'Prasar Bharati', language: 'Hindi'),
    PlanItem(
        id: 3229,
        name: 'Colors HD',
        kind: ItemKind.alaCarte,
        genre: 'Entertainment',
        price: 22.42,
        broadcaster: 'Viacom18',
        language: 'Hindi',
        isHd: true,
        hdChannels: 1,
        trend: '#1 nearby'),
    PlanItem(
        id: 3230,
        name: 'Zee TV HD',
        kind: ItemKind.alaCarte,
        genre: 'Entertainment',
        price: 22.42,
        broadcaster: 'Zee',
        language: 'Hindi',
        isHd: true,
        hdChannels: 1,
        trend: 'Most added'),
    PlanItem(
        id: 3231,
        name: 'Sony SAB HD',
        kind: ItemKind.alaCarte,
        genre: 'Entertainment',
        price: 22.42,
        broadcaster: 'Sony',
        language: 'Hindi',
        isHd: true,
        hdChannels: 1),
    PlanItem(
        id: 3232,
        name: 'Star Sports 1 HD',
        kind: ItemKind.alaCarte,
        genre: 'Sports',
        price: 22.42,
        broadcaster: 'Disney Star',
        language: 'English',
        isHd: true,
        hdChannels: 1,
        trend: 'Top rated'),
    PlanItem(
        id: 3233,
        name: 'National Geographic HD',
        kind: ItemKind.alaCarte,
        genre: 'Infotainment',
        price: 4.72,
        broadcaster: 'Disney Star',
        language: 'English',
        isHd: true,
        hdChannels: 1,
        trend: 'New shows'),
  ];

  static const _bouquets = [
    PlanItem(id: 4201, name: 'Star Value Pack Hindi', kind: ItemKind.bouquet, price: 57.82, channels: 18, broadcaster: 'Disney Star', language: 'Hindi'),
    PlanItem(id: 4202, name: 'Sony Happy India Smart', kind: ItemKind.bouquet, price: 53.10, channels: 14, broadcaster: 'Sony', language: 'Hindi'),
    PlanItem(id: 4203, name: 'Zee Family Pack Hindi', kind: ItemKind.bouquet, price: 46.02, channels: 16, broadcaster: 'Zee', language: 'Hindi'),
    PlanItem(id: 4204, name: 'Colors Wala Hindi Plus', kind: ItemKind.bouquet, price: 29.50, channels: 12, broadcaster: 'Viacom18', language: 'Hindi'),
    PlanItem(id: 4205, name: 'Sun Telugu Basic', kind: ItemKind.bouquet, price: 35.40, channels: 9, broadcaster: 'Sun TV', language: 'Telugu'),
    PlanItem(
        id: 4206,
        name: 'Discovery Kids & Family',
        kind: ItemKind.bouquet,
        price: 17.70,
        channels: 7,
        broadcaster: 'Discovery',
        language: 'English',
        hdChannels: 2),
  ];

  static const _addOns = [
    PlanItem(id: 5201, name: 'Recording (1 month)', kind: ItemKind.addOn, price: 29.50, channels: 0, broadcaster: 'DishTV'),
    PlanItem(id: 5202, name: 'Recording (12 months)', kind: ItemKind.addOn, price: 199.42, channels: 0, broadcaster: 'DishTV'),
    PlanItem(id: 5203, name: 'Sports Add-on', kind: ItemKind.addOn, price: 69.62, channels: 8, broadcaster: 'DishTV', hdChannels: 2),
    PlanItem(id: 5204, name: 'Kids Add-on', kind: ItemKind.addOn, price: 34.22, channels: 6, broadcaster: 'DishTV'),
    PlanItem(id: 5205, name: 'Regional Marathi Add-on', kind: ItemKind.addOn, price: 41.30, channels: 9, broadcaster: 'DishTV', language: 'Marathi'),
    PlanItem(id: 5206, name: 'Devotional Add-on', kind: ItemKind.addOn, price: 11.80, channels: 7, broadcaster: 'DishTV'),
  ];

  // ----------------------------------------------------------- price, apply

  /// NCF: ₹130 + GST for the first 200 SD channels, ₹20 for each further 25
  /// (an HD channel counts as two).
  static double ncfFor(int sdEquivalent) {
    if (sdEquivalent <= 0) return 0;
    final extra = max(0, sdEquivalent - 200);
    return 130 + (extra / 25).ceil() * 20;
  }

  @override
  Future<Quote> quote({required List<PlanItem> finalItems}) => _later(() {
        final packCost = finalItems.fold(0.0, (a, i) => a + i.priceExTax);
        final sdEq = finalItems.fold(0, (a, i) => a + (i.channels - i.hdChannels) + i.hdChannels * 2);
        final ncf = ncfFor(sdEq);
        final gst = (packCost + ncf) * 0.18;
        return Quote(packCost: packCost, ncf: ncf, gst: gst);
      });

  @override
  Future<String> apply({required List<PlanItem> finalItems}) => _later(() {
        final n = DateTime.now().millisecondsSinceEpoch % 100000000;
        return 'DT${n.toString().padLeft(8, '0')}';
      });

  // ---------------------------------------------------------------------- AI

  @override
  Future<AiOptions> aiOptions() => _later(() => const AiOptions(
        languages: ['Hindi', 'English', 'Marathi', 'Bangla', 'Tamil', 'Telugu', 'Kannada', 'Malayalam', 'Gujarati', 'Punjabi'],
        genres: ['Entertainment', 'Movies', 'Sports', 'News', 'Kids', 'Music', 'Infotainment', 'Devotional'],
        viewing: ['Mostly on the TV', 'TV and mobile', 'Mostly on mobile'],
        budgets: [250, 350, 500, 750],
      ));

  @override
  Future<List<Recommendation>> recommend(AiAnswers a) => _later(() {
        final wantOtt = a.viewing != null && a.viewing != 'Mostly on the TV';
        final pool = _allPacks().where((p) => p.isHd == a.hd).toList();
        int score(Pack p) {
          var s = 50;
          s += p.languages.where(a.languages.contains).length * 12;
          for (final g in a.genres) {
            s += min(10, (p.genreCounts[g] ?? 0) ~/ 2);
          }
          if (wantOtt && p.ottApps.isNotEmpty) s += 12;
          if (a.budget != null && p.price > a.budget!) s -= 25;
          return s.clamp(40, 98);
        }

        final ranked = pool.toList()..sort((x, y) => score(y).compareTo(score(x)));
        final best = ranked.first;
        final popular = ranked.firstWhere((p) => p != best && p.channels >= best.channels - 20, orElse: () => ranked[1]);
        final budget = (ranked.where((p) => p != best && p != popular).toList()..sort((x, y) => x.price.compareTo(y.price))).first;
        List<String> why(Pack p) => [
              if (p.languages.any(a.languages.contains)) 'Has your languages: ${p.languages.where(a.languages.contains).join(' | ')}',
              for (final g in a.genres.take(2))
                if ((p.genreCounts[g] ?? 0) > 0) '${p.genreCounts[g]} $g channels',
              if (p.ottApps.isNotEmpty) 'Includes ${p.ottApps.join(' & ')}',
              if (a.budget != null && p.price <= a.budget!) 'Within your ${'₹'}${a.budget} budget',
            ];
        return [
          Recommendation(pack: best, label: 'Best match', matchScore: score(best), reasons: why(best)),
          Recommendation(pack: popular, label: 'Most popular', matchScore: score(popular), reasons: why(popular)),
          Recommendation(pack: budget, label: 'Budget pick', matchScore: score(budget), reasons: why(budget)),
        ];
      });
}

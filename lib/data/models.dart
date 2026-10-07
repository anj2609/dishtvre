// Domain models. Shaped after the DishTV subscriber APIs
// (SubscriberCompleteInfo, GetAllVCListOnSingleRMNBySMSID, DPOZoneWiseCWEB,
// ChannelsByPackageIDCWEB, the top-up catalogs and the optimised-pack quote)
// so a live repository can map responses onto them one-to-one.

import 'package:flutter/foundation.dart';

enum ConnectionStatus { active, vacation, deactivated }

enum ConnectionType { parent, child, individual }

/// A postal address, kept in parts so it can be edited field by field.
@immutable
class Address {
  const Address({this.house = '', this.street = '', this.landmark = '', this.city = '', this.pincode = '', this.state = ''});

  final String house;
  final String street;
  final String landmark;
  final String city;
  final String pincode;
  final String state;

  bool get isEmpty => [house, street, landmark, city, pincode, state].every((x) => x.trim().isEmpty);

  /// "House 24, Sector 18, Near City Centre Metro, Noida, Uttar Pradesh 201301"
  String get oneLine {
    final parts = [house, street, landmark, city, state].map((x) => x.trim()).where((x) => x.isNotEmpty).join(', ');
    return pincode.trim().isEmpty ? parts : '$parts ${pincode.trim()}';
  }
}

@immutable
class Subscriber {
  const Subscriber({
    required this.name,
    required this.smsId,
    required this.mobile,
    this.email = '',
    this.address = const Address(),
    this.role = 'Primary account holder',
    this.memberSince,
    this.photo,
  });

  final String name;
  final int smsId;

  /// Ten digits, without +91.
  final String mobile;
  final String email;
  final Address address;
  final String role;

  /// When the account was opened.
  final DateTime? memberSince;

  /// Profile photo (a square PNG), or null to show initials.
  final Uint8List? photo;

  String get firstName => name.split(' ').first;
  String get initials => name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

  /// "98765 43210"
  String get mobilePretty => mobile.length == 10 ? '${mobile.substring(0, 5)} ${mobile.substring(5)}' : mobile;

  /// [photo] replaces the photo when given; [removePhoto] clears it.
  Subscriber copyWith({String? name, String? mobile, String? email, Address? address, Uint8List? photo, bool removePhoto = false}) => Subscriber(
        name: name ?? this.name,
        smsId: smsId,
        mobile: mobile ?? this.mobile,
        email: email ?? this.email,
        address: address ?? this.address,
        role: role,
        memberSince: memberSince,
        photo: removePhoto ? null : (photo ?? this.photo),
      );
}

/// One covered part of a connection's equipment.
@immutable
class WarrantyItem {
  const WarrantyItem({required this.part, this.model, required this.until});
  final String part;
  final String? model;
  final DateTime until;

  bool activeOn(DateTime now) => !until.isBefore(DateTime(now.year, now.month, now.day));
}

/// Warranty on a connection's equipment.
@immutable
class Warranty {
  const Warranty({required this.installedOn, required this.items, this.kind = 'Manufacturer warranty'});
  final DateTime installedOn;
  final List<WarrantyItem> items;
  final String kind;
}

@immutable
class Connection {
  const Connection({
    required this.vc,
    required this.label,
    required this.type,
    required this.status,
    required this.monthlyRecharge,
    required this.balance,
    required this.switchOffDate,
    this.lockInUntil,
    required this.planName,
    required this.isHd,
    this.pauseFrom,
    this.resumeOn,
  });

  final String vc;
  final String label;
  final ConnectionType type;
  final ConnectionStatus status;
  final double monthlyRecharge;
  final double balance;
  final DateTime switchOffDate;
  final DateTime? lockInUntil;
  final String planName;
  final bool isHd;

  /// Vacation Mode: the day the pause starts and the day the TV switches
  /// back on. Set while a pause is booked or running.
  final DateTime? pauseFrom;
  final DateTime? resumeOn;

  bool get isMultiTv => type != ConnectionType.individual;

  /// A pause is booked for later (the TV is still on until [pauseFrom]).
  bool get vacationBooked => pauseFrom != null && status != ConnectionStatus.vacation;

  /// [clearVacation] drops [pauseFrom] and [resumeOn].
  Connection copyWith({
    ConnectionStatus? status,
    double? monthlyRecharge,
    double? balance,
    DateTime? switchOffDate,
    String? planName,
    bool? isHd,
    DateTime? pauseFrom,
    DateTime? resumeOn,
    bool clearVacation = false,
  }) =>
      Connection(
        vc: vc,
        label: label,
        type: type,
        status: status ?? this.status,
        monthlyRecharge: monthlyRecharge ?? this.monthlyRecharge,
        balance: balance ?? this.balance,
        switchOffDate: switchOffDate ?? this.switchOffDate,
        lockInUntil: lockInUntil,
        planName: planName ?? this.planName,
        isHd: isHd ?? this.isHd,
        pauseFrom: clearVacation ? null : (pauseFrom ?? this.pauseFrom),
        resumeOn: clearVacation ? null : (resumeOn ?? this.resumeOn),
      );

  /// Whole days until service stops (negative once it has stopped).
  int daysLeft(DateTime now) => DateTime(switchOffDate.year, switchOffDate.month, switchOffDate.day).difference(DateTime(now.year, now.month, now.day)).inDays;

  String get vcPretty => vc.length == 11 ? '${vc.substring(0, 4)} ${vc.substring(4, 8)} ${vc.substring(8)}' : vc;
}

enum ItemKind { basePack, alaCarte, bouquet, addOn }

/// Something on (or addable to) a connection's plan.
@immutable
class PlanItem {
  const PlanItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.price,
    this.channels = 1,
    this.hdChannels = 0,
    this.broadcaster = '',
    this.language = '',
    this.isHd = false,
    this.lockedReason,
    this.logoUrl,
    this.genre = '',
    this.group,
    this.trend,
  });

  final int id;
  final String name;
  final ItemKind kind;

  /// Monthly price incl. GST.
  final double price;
  final int channels;
  final int hdChannels;
  final String broadcaster;
  final String language;
  final bool isHd;

  /// Why it can't be removed (lock-in, mandatory, part of the base pack).
  final String? lockedReason;

  /// Logo for single channels (the API's channelImagePath).
  final String? logoUrl;

  /// Genre of a single channel (Entertainment, Movies, Sports…).
  final String genre;

  /// Display group when it differs from [kind], e.g. "OTT" or
  /// "Active Services" for add-ons that are apps or services.
  final String? group;

  /// Why it's trending near you, e.g. "#1 nearby" or "Most added".
  final String? trend;

  PlanItem withLogo(String? url) => PlanItem(
        id: id,
        name: name,
        kind: kind,
        price: price,
        channels: channels,
        hdChannels: hdChannels,
        broadcaster: broadcaster,
        language: language,
        isHd: isHd,
        lockedReason: lockedReason,
        logoUrl: url,
        genre: genre,
        group: group,
        trend: trend,
      );

  double get priceExTax => double.parse((price / 1.18).toStringAsFixed(2));
  bool get removable => kind != ItemKind.basePack && lockedReason == null;
  bool get isRecordingPlan => RegExp(r'\brecording\b', caseSensitive: false).hasMatch(name);

  @override
  bool operator ==(Object other) => other is PlanItem && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

enum PackType { tv, ottTv }

/// A base pack the subscriber can switch to.
@immutable
class Pack {
  const Pack({
    required this.id,
    required this.name,
    required this.type,
    required this.isHd,
    required this.price,
    required this.channels,
    required this.hdChannels,
    required this.languages,
    this.ottApps = const [],
    this.ncf = 0,
    this.isCurrent = false,
    this.lockIn = false,
    this.ruleMessage,
    this.genreCounts = const {},
    this.ottLogoUrls = const {},
  });

  final int id;
  final String name;
  final PackType type;
  final bool isHd;

  /// Monthly price incl. GST, before NCF.
  final double price;
  final int channels;
  final int hdChannels;
  final List<String> languages;
  final List<String> ottApps;
  final double ncf;
  final bool isCurrent;
  final bool lockIn;
  final String? ruleMessage;

  /// Channels per genre (Sports, Kids, Movies, News…).
  final Map<String, int> genreCounts;

  /// Logo for each OTT app in [ottApps], by app name.
  final Map<String, String> ottLogoUrls;

  double get priceExTax => double.parse((price / 1.18).toStringAsFixed(2));
  double get gst => price - priceExTax;

  PlanItem asItem() => PlanItem(
        id: id,
        name: name,
        kind: ItemKind.basePack,
        price: price,
        channels: channels,
        hdChannels: hdChannels,
        isHd: isHd,
        language: languages.join(' | '),
      );

  @override
  bool operator ==(Object other) => other is Pack && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

@immutable
class Channel {
  const Channel({required this.name, required this.genre, this.language = '', this.isHd = false, this.logoUrl});
  final String name;
  final String genre;
  final String language;
  final bool isHd;

  /// Channel logo (the API's channelImagePath).
  final String? logoUrl;

  String get key => name.toLowerCase().replaceAll(RegExp(r'\s+hd$'), '').trim();
}

/// Server price for a change.
@immutable
class Quote {
  const Quote({required this.packCost, required this.ncf, required this.gst, this.discount = 0});
  final double packCost;
  final double ncf;
  final double gst;
  final double discount;
  double get total => (packCost - discount + ncf + gst).ceilToDouble();
}

/// One recommended pack from the AI recommender.
@immutable
class Recommendation {
  const Recommendation({required this.pack, required this.label, required this.matchScore, required this.reasons});
  final Pack pack;

  /// "Best match", "Most popular", "Budget pick".
  final String label;
  final int matchScore;
  final List<String> reasons;
}

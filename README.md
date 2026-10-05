# DishTV Next

A redesign of the DishTV subscriber app (Flutter), currently running on
sample data shaped like the DishTV APIs.

**Screens**
- **Home:** TV cards, quick actions and the side menu.
- **All services:** Packs & OTT, Recharge & Offers, and Account & Support.
- **Change pack:** Explore packs, compare, pack details and channel changes.
- **Find my pack (AI):** a few questions, then suggested packs.
- **Add / Remove:** add channels, bouquets and add-ons, or remove items from your plan, with filters.
- **Your plan, Review and Success.**
- **Profile:** contact details, your TVs, warranty, and Edit Profile with photo capture and cropping.

## Run it

Requirements:
- Flutter 3.27 or later (tested on 3.27.3 and 3.35.5)
- JDK 17 or later
- Android SDK

```sh
flutter pub get
flutter run                 # on a connected phone or emulator
flutter test                # walks every screen at several sizes and text scales
```

To build an APK: `flutter build apk --release`. The output is
`build/app/outputs/flutter-apk/app-release.apk`.

## Code map

- `lib/app/theme.dart`: colours, type, spacing and the flat, sharp-cornered style.
- `lib/data/`: the models, and `Repository` with `MockRepository` (the sample data).
  To connect the real DishTV APIs, implement `Repository` and pass it in `lib/main.dart`.
- `lib/state/`: `AppStore` (subscriber and TVs) and `PlanStore` (pack and plan changes).
- `lib/ui/`: one folder per area (home, change_pack, explore, add_remove, top_ups, checkout, ai, widgets).

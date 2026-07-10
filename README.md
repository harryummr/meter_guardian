# Meter Guardian

Offline, multi-meter electricity tracker for Pakistani households/shops, built to keep
you ahead of the 200-unit (and 300/500-unit) tariff slabs.

## What's fully implemented and working

- **Multi-meter support** — unlimited meters, each fully independent (own bill, own
  readings, own averages, own history).
- **Hive local storage** — everything stays on-device, hand-written TypeAdapters
  (no `build_runner` step required to get started).
- **Smart OCR reading detection** (`lib/services/ocr_service.dart`):
  - Scores every number detected on the meter photo, boosting anything sitting next
    to a "kWh"/"Units" label.
  - Remembers each meter's confirmed reading location + digit count after the first
    successful confirmation (`OcrRegionMemory`), and weights future scans of that
    same meter toward that region — this gets better the more you use it.
  - Bill photos are parsed for Present Reading, Previous Reading, and dates using
    label-proximity matching, with a same-digit-count fallback if labels aren't found.
  - Both bill and meter scans support **Camera and Gallery** via a single bottom sheet
    (`lib/widgets/image_source_sheet.dart`).
  - Every OCR result is shown with a confidence indicator, an editable text field,
    and tappable alternative numbers — nothing is silently trusted.
- **Full calculation engine** (`calculation_service.dart`): units used, elapsed days,
  average/day, remaining units and estimated days left for every configured slab
  target, plus PK alert thresholds (150/180/190/195/199/200).
- **Dashboard, Add Meter, Upload Bill, Scan Reading, Meter Detail (Overview/History/
  Graph tabs), Settings** — all real, wired-up screens, not mockups.
- **Charts** via `fl_chart` (units per cycle, average trend).
- **PDF and Excel export** per meter, shared via the system share sheet.
- **Local notifications**: daily/weekly reminders, and automatic threshold alerts
  fired the moment a new reading crosses 150/180/190/195/199/200 units.
- **Material 3 light + dark themes**, toggleable from the home screen.

## What you should still test/harden before shipping

Being direct about this rather than pretending it's all bullet-proof:

1. **OCR accuracy on real meter displays.** Digital LCD meters, analog dial meters,
   and smart meters all look very different. The scoring in `_extractNumericCandidates`
   is a solid heuristic starting point (kWh proximity + digit-length + remembered
   region), but you'll want to test it against real photos from your actual meters
   and tune the weights/thresholds.
2. **Date parsing in `scanBill`** assumes DD/MM/YYYY (standard for PK bills) — sanity
   check against a real DISCO bill (LESCO/GEPCO/FESCO/etc.) since formats vary slightly.
3. **Exact-alarm permission on Android 12+**: `SCHEDULE_EXACT_ALARM` may need the user
   to flip a system setting on some OEM skins (Xiaomi/Oppo especially) for the
   daily/weekly reminder to fire reliably.
4. **`meter_provider.dart`'s `setMeterStart`** does a small lookup dance to find the
   right bill — fine for normal use, but if you start managing hundreds of meters
   you'd want to index bills by ID directly rather than scanning.

## Getting it running

The full native Android project is now included in this zip (gradle files, manifest,
MainActivity, launcher icons) — you do **not** need to run `flutter create .` anymore.

**On Codemagic:** just push this whole folder to GitHub and start a build. The default
"Flutter App" workflow will find `android/` already set up and build straight away.
If you'd added a custom `codemagic.yaml` before with a `flutter create` step, delete
that file from the repo (or replace it with the one included here) — it's no longer needed
and can actually cause conflicts now that the android folder already exists.

**On a laptop:**
```bash
flutter pub get
flutter build apk --release
```
APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

No API keys, no cloud services, no accounts — everything (OCR, storage, exports,
notifications) runs entirely on the device.

import 'dart:io';
import 'dart:math' as math;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../models/ocr_region_memory.dart';
import 'hive_service.dart';

enum ScanType { billPhoto, meterPhoto }

/// One numeric string found on the image, with everything we know about
/// where it sat and how trustworthy it looks as *the* consumption reading.
class OcrCandidate {
  final String rawText;
  final double value;
  final int digitCount;

  /// Bounding box normalized to 0.0-1.0 relative to image dimensions.
  final double left, top, right, bottom;

  final bool nearKwhLabel;
  final bool nearExcludedLabel;
  final bool insideLearnedRegion;

  double score;

  OcrCandidate({
    required this.rawText,
    required this.value,
    required this.digitCount,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.nearKwhLabel,
    required this.nearExcludedLabel,
    required this.insideLearnedRegion,
    this.score = 0.0,
  });

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

/// Full result of a scan, ready for the review/confirmation screen.
class OcrScanResult {
  final OcrCandidate? best;
  final List<OcrCandidate> candidates;
  final int imageWidth;
  final int imageHeight;

  OcrScanResult({
    required this.best,
    required this.candidates,
    required this.imageWidth,
    required this.imageHeight,
  });

  bool get isConfident => best != null && best!.score >= 0.72;
}

/// Handles OCR for bill photos and meter-display photos, biased toward
/// finding the actual consumption (kWh) reading rather than any arbitrary
/// number printed on the bill or meter faceplate.
///
/// Strategy:
///  1. Prefer digits sitting next to a "kWh" label — the standard printed
///     convention on Pakistani DISCO bills and digital meter displays
///     (LESCO, MEPCO, FESCO, IESCO, etc).
///  2. If no "kWh" label is detected, fall back to heuristics: plausible
///     digit-length (3-7 digits), distance from excluded bill-noise labels
///     (account no, tariff code, phase, Rs, etc), and center-of-frame bias.
///  3. Learn from user confirmations: once a reading is confirmed for a
///     given meter, remember the normalized region + digit count in
///     [OcrRegionMemory] so future scans of that same meter are matched
///     with much higher confidence.
///  4. Support both camera and gallery capture, and lightweight live-frame
///     scanning for a real-time viewfinder overlay.
class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  void dispose() => _recognizer.close();

  // ---------------------------------------------------------------------
  // Capture — camera and gallery both always offered by the calling UI.
  // ---------------------------------------------------------------------

  Future<File?> pickFromCamera({bool preferRearCamera = true}) async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice:
          preferRearCamera ? CameraDevice.rear : CameraDevice.front,
      imageQuality: 92,
      maxWidth: 2400,
    );
    return shot == null ? null : File(shot.path);
  }

  Future<File?> pickFromGallery() async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2400,
    );
    return shot == null ? null : File(shot.path);
  }

  // ---------------------------------------------------------------------
  // Live-frame scanning (for the real-time viewfinder overlay)
  // ---------------------------------------------------------------------

  /// Runs recognition on a single throttled camera-preview frame (call this
  /// roughly every 400-600ms from the CameraController image stream, not on
  /// every frame). Reuses the exact same scoring path as a still capture so
  /// the live overlay box matches what final capture will produce.
  Future<OcrScanResult> scanLiveFrame(
    InputImage frame, {
    required String meterId,
    required ScanType scanType,
    required int imageWidth,
    required int imageHeight,
  }) async {
    final recognized = await _recognizer.processImage(frame);
    return _rank(
      recognized,
      meterId: meterId,
      scanType: scanType,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  // ---------------------------------------------------------------------
  // Still-photo scanning
  // ---------------------------------------------------------------------

  Future<OcrScanResult> scanMeterPhoto(File image, {required String meterId}) async {
    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);
    final width = decoded?.width ?? 1;
    final height = decoded?.height ?? 1;

    final input = InputImage.fromFile(image);
    final recognized = await _recognizer.processImage(input);

    return _rank(
      recognized,
      meterId: meterId,
      scanType: ScanType.meterPhoto,
      imageWidth: width,
      imageHeight: height,
    );
  }

  Future<OcrScanResult> scanBillPhoto(File image, {required String meterId}) async {
    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);
    final width = decoded?.width ?? 1;
    final height = decoded?.height ?? 1;

    final input = InputImage.fromFile(image);
    final recognized = await _recognizer.processImage(input);

    return _rank(
      recognized,
      meterId: meterId,
      scanType: ScanType.billPhoto,
      imageWidth: width,
      imageHeight: height,
    );
  }

  // ---------------------------------------------------------------------
  // Learning — call after the user confirms (or manually corrects) a value
  // ---------------------------------------------------------------------

  /// Persists the confirmed reading's region + digit-count signature for
  /// this meter/scanType so the next scan is matched faster and with
  /// higher confidence. Blends with any prior memory (moving average)
  /// rather than overwriting outright, to smooth out minor framing drift.
  Future<void> learnFromConfirmation({
    required String meterId,
    required ScanType scanType,
    required OcrCandidate confirmed,
  }) async {
    final scanTypeKey = scanType == ScanType.billPhoto ? 'bill' : 'meter_photo';
    final existing = HiveService.instance.getOcrRegionMemory(meterId, scanTypeKey);

    if (existing != null) {
      existing
        ..left = (existing.left + confirmed.left) / 2
        ..top = (existing.top + confirmed.top) / 2
        ..right = (existing.right + confirmed.right) / 2
        ..bottom = (existing.bottom + confirmed.bottom) / 2
        ..digitCount = confirmed.digitCount
        ..updatedAt = DateTime.now()
        ..confirmCount = existing.confirmCount + 1;
      await existing.save();
    } else {
      final memory = OcrRegionMemory(
        id: '${meterId}_$scanTypeKey',
        meterId: meterId,
        scanType: scanTypeKey,
        left: confirmed.left,
        top: confirmed.top,
        right: confirmed.right,
        bottom: confirmed.bottom,
        digitCount: confirmed.digitCount,
        updatedAt: DateTime.now(),
      );
      await HiveService.instance.saveOcrRegionMemory(memory);
    }
  }

  // ---------------------------------------------------------------------
  // Internal: extraction + scoring
  // ---------------------------------------------------------------------

  static const _billExcludedLabels = [
    'rs', 'pmt', 'ref', 'meter no', 'account', 'consumer no',
    'phase', 'load', 'sanctioned', 'tariff code', 'gst', 'npt',
  ];

  OcrScanResult _rank(
    RecognizedText recognized, {
    required String meterId,
    required ScanType scanType,
    required int imageWidth,
    required int imageHeight,
  }) {
    final scanTypeKey = scanType == ScanType.billPhoto ? 'bill' : 'meter_photo';
    final memory = HiveService.instance.getOcrRegionMemory(meterId, scanTypeKey);
    final excludedLabels = scanType == ScanType.billPhoto ? _billExcludedLabels : const <String>[];

    final kwhBoxesPx = <_PxRect>[];
    final excludedBoxesPx = <_PxRect>[];
    final numericPx = <MapEntry<String, _PxRect>>[];

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final text = element.text.trim();
          final r = element.boundingBox;
          final px = _PxRect(
            r.left.toDouble(), r.top.toDouble(), r.right.toDouble(), r.bottom.toDouble(),
          );
          final lower = text.toLowerCase().replaceAll('.', '');

          if (RegExp(r'kwh|kw h|k wh').hasMatch(lower)) {
            kwhBoxesPx.add(px);
            continue;
          }
          if (excludedLabels.any((l) => lower.contains(l))) {
            excludedBoxesPx.add(px);
            continue;
          }

          final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
          if (digitsOnly.length >= 3 &&
              digitsOnly.length <= 7 &&
              RegExp(r'^[0-9]+\.?[0-9]*$').hasMatch(text)) {
            numericPx.add(MapEntry(text, px));
          }
        }
      }
    }

    final candidates = <OcrCandidate>[];

    for (final entry in numericPx) {
      final text = entry.key;
      final px = entry.value;
      final value = double.tryParse(text);
      if (value == null) continue;

      final digitCount = text.replaceAll(RegExp(r'[^0-9]'), '').length;
      final nearKwh = kwhBoxesPx.any((k) => _isNear(px, k, imageWidth, imageHeight));
      final nearExcluded = excludedBoxesPx.any((e) => _isNear(px, e, imageWidth, imageHeight));

      final left = px.left / imageWidth;
      final top = px.top / imageHeight;
      final right = px.right / imageWidth;
      final bottom = px.bottom / imageHeight;

      final insideMemory = memory != null && _overlapsMemory(left, top, right, bottom, memory);

      final candidate = OcrCandidate(
        rawText: text,
        value: value,
        digitCount: digitCount,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
        nearKwhLabel: nearKwh,
        nearExcludedLabel: nearExcluded,
        insideLearnedRegion: insideMemory,
      );

      candidate.score = _score(
        candidate: candidate,
        memory: memory,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );

      candidates.add(candidate);
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    return OcrScanResult(
      best: candidates.isNotEmpty ? candidates.first : null,
      candidates: candidates,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  /// Combines every signal into one 0.0-1.0 confidence score.
  ///
  ///  - kWh label adjacency: dominant signal — this is the actual printed
  ///    convention for consumption on the bill/meter.
  ///  - learned region overlap: near-dominant once we have history for this
  ///    specific meter, since it accounts for consistent camera framing.
  ///  - digit-count match against the last confirmed reading: readings on
  ///    the same meter almost always keep the same digit count cycle to
  ///    cycle.
  ///  - center-of-frame bonus: mild tiebreaker only for the cold-start case
  ///    (no kWh label found, no learned history yet).
  ///  - excluded-label proximity: strong penalty (account no, tariff code,
  ///    Rs amounts, etc).
  double _score({
    required OcrCandidate candidate,
    required OcrRegionMemory? memory,
    required int imageWidth,
    required int imageHeight,
  }) {
    double s = 0.15;

    if (candidate.nearKwhLabel) s += 0.45;
    if (candidate.insideLearnedRegion) s += 0.30;
    if (memory != null && memory.digitCount == candidate.digitCount) s += 0.12;
    if (candidate.nearExcludedLabel) s -= 0.5;

    if (!candidate.nearKwhLabel && memory == null) {
      final dx = candidate.centerX - 0.5;
      final dy = candidate.centerY - 0.5;
      final dist = math.sqrt(dx * dx + dy * dy);
      s += 0.15 * (1 - math.min(dist * 2, 1));
    }

    return s.clamp(0.0, 1.0);
  }

  bool _overlapsMemory(
    double left, double top, double right, double bottom, OcrRegionMemory m,
  ) {
    const pad = 0.08;
    final ml = m.left - pad, mt = m.top - pad, mr = m.right + pad, mb = m.bottom + pad;
    return left < mr && right > ml && top < mb && bottom > mt;
  }

  bool _isNear(_PxRect a, _PxRect b, int imageWidth, int imageHeight) {
    // "Near" = within ~12% of image width horizontally and ~6% of image
    // height vertically — tuned for a kWh label sitting either just right
    // of, or just under, the digit block on common meter/bill layouts.
    final maxDx = imageWidth * 0.12;
    final maxDy = imageHeight * 0.06;
    final dx = (a.centerX - b.centerX).abs();
    final dy = (a.centerY - b.centerY).abs();
    return dx <= maxDx && dy <= maxDy;
  }
}

class _PxRect {
  final double left, top, right, bottom;
  const _PxRect(this.left, this.top, this.right, this.bottom);
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}

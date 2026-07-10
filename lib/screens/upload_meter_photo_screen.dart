import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/meter_provider.dart';
import '../services/ocr_service.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/ocr_candidate_picker.dart';
import 'home_screen.dart';

class UploadMeterPhotoScreen extends StatefulWidget {
  final String meterId;
  final String billId;
  const UploadMeterPhotoScreen({super.key, required this.meterId, required this.billId});

  @override
  State<UploadMeterPhotoScreen> createState() => _UploadMeterPhotoScreenState();
}

class _UploadMeterPhotoScreenState extends State<UploadMeterPhotoScreen> {
  final _ocr = OcrService();
  File? _image;
  bool _scanning = false;
  MeterReadingScanResult? _scanResult;
  OcrCandidate? _selectedCandidate;

  DateTime? _startDate;
  TimeOfDay? _startTime;

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  Future<void> _captureAndScan() async {
    final file = await pickImageWithSourceSheet(context);
    if (file == null) return;

    setState(() {
      _image = file;
      _scanning = true;
      _scanResult = null;
      _selectedCandidate = null;
    });

    final result = await _ocr.scanMeterReading(file, meterId: widget.meterId);

    setState(() {
      _scanning = false;
      _scanResult = result;
      _selectedCandidate = result.best;
    });
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _startDate = date;
      _startTime = time;
    });
  }

  DateTime? get _combinedStart {
    if (_startDate == null || _startTime == null) return null;
    return DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
  }

  bool get _canSave => _selectedCandidate != null && _combinedStart != null;

  Future<void> _save() async {
    final provider = context.read<MeterProvider>();
    final meter = provider.meters.firstWhere((m) => m.meter.id == widget.meterId).meter;

    // Remember this confirmed region so future scans of the same meter are smarter.
    await _ocr.rememberConfirmedRegion(
      meterId: widget.meterId,
      scanType: ScanType.meterPhoto,
      confirmedCandidate: _selectedCandidate!,
    );

    await provider.setMeterStart(widget.billId, _combinedStart!);
    await provider.updateCurrentReading(
      meter: meter,
      billId: widget.billId,
      newReading: _selectedCandidate!.value,
    );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Meter Reading')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_image == null)
            _captureCard()
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_image!, height: 220, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 12),
          if (_image != null)
            TextButton.icon(
              onPressed: _captureAndScan,
              icon: const Icon(Icons.refresh),
              label: const Text('Retake / choose another photo'),
            ),
          if (_scanning) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('Reading the meter display…')),
          ],
          if (_scanResult != null && !_scanning) ...[
            const SizedBox(height: 16),
            OcrCandidatePicker(
              scanResult: _scanResult!,
              onSelectionChanged: (c) => setState(() => _selectedCandidate = c),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'When did you start using this meter after the bill reading?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickStartDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _combinedStart != null
                    ? DateFormat('dd MMM yyyy, hh:mm a').format(_combinedStart!)
                    : 'Choose start date & time',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Confirm & Save'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _captureCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _captureAndScan,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.electric_meter_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Tap to photograph the meter display'),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/meter_provider.dart';
import '../services/ocr_service.dart';
import '../widgets/image_source_sheet.dart';
import 'upload_meter_photo_screen.dart';

class UploadBillScreen extends StatefulWidget {
  final String meterId;
  const UploadBillScreen({super.key, required this.meterId});

  @override
  State<UploadBillScreen> createState() => _UploadBillScreenState();
}

class _UploadBillScreenState extends State<UploadBillScreen> {
  final _ocr = OcrService();
  File? _image;
  bool _scanning = false;
  BillOcrResult? _result;

  final _presentCtrl = TextEditingController();
  final _previousCtrl = TextEditingController();
  final _monthCtrl = TextEditingController();
  DateTime? _issueDate;
  DateTime? _dueDate;

  @override
  void dispose() {
    _ocr.dispose();
    _presentCtrl.dispose();
    _previousCtrl.dispose();
    _monthCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureAndScan() async {
    final file = await pickImageWithSourceSheet(context);
    if (file == null) return;

    setState(() {
      _image = file;
      _scanning = true;
    });

    final result = await _ocr.scanBill(file);

    setState(() {
      _scanning = false;
      _result = result;
      _presentCtrl.text = result.presentReading?.toStringAsFixed(0) ?? '';
      _previousCtrl.text = result.previousReading?.toStringAsFixed(0) ?? '';
      _monthCtrl.text = result.billingMonthGuess ?? '';
      _issueDate = result.issueDate;
      _dueDate = result.dueDate;
    });
  }

  Future<void> _pickDate({required bool isIssue}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isIssue ? _issueDate : _dueDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isIssue) {
        _issueDate = picked;
        if (_monthCtrl.text.isEmpty) {
          _monthCtrl.text = DateFormat('MMMM yyyy').format(picked);
        }
      } else {
        _dueDate = picked;
      }
    });
  }

  bool get _canSave =>
      _presentCtrl.text.trim().isNotEmpty &&
      _previousCtrl.text.trim().isNotEmpty &&
      _issueDate != null &&
      _monthCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    final present = double.tryParse(_presentCtrl.text.trim());
    final previous = double.tryParse(_previousCtrl.text.trim());
    if (present == null || previous == null || _issueDate == null) return;

    final record = await context.read<MeterProvider>().addBillRecord(
          meterId: widget.meterId,
          billingMonth: _monthCtrl.text.trim(),
          presentReading: present,
          previousReading: previous,
          issueDate: _issueDate!,
          dueDate: _dueDate,
          billImagePath: _image?.path,
        );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UploadMeterPhotoScreen(meterId: widget.meterId, billId: record.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Bill')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_image == null)
            _captureCard()
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_image!, height: 200, width: double.infinity, fit: BoxFit.cover),
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
            const Center(child: Text('Reading the bill…')),
          ],
          if (_result != null && !_scanning) ...[
            const SizedBox(height: 8),
            Text(
              _result!.overallConfidence >= 0.6
                  ? 'Detected the bill details — please double-check below.'
                  : 'Couldn\'t read everything clearly — please fill in / correct the fields below.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _presentCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Present Reading (on bill)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _previousCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Previous Reading (on bill)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _monthCtrl,
              decoration: const InputDecoration(labelText: 'Billing Month'),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Issue Date'),
              subtitle: Text(_issueDate != null
                  ? DateFormat('dd MMM yyyy').format(_issueDate!)
                  : 'Not set'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDate(isIssue: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Due Date (optional)'),
              subtitle: Text(
                  _dueDate != null ? DateFormat('dd MMM yyyy').format(_dueDate!) : 'Not set'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _pickDate(isIssue: false),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _canSave ? _save : null,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Save Bill & Continue'),
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
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Tap to photograph or select your bill'),
          ],
        ),
      ),
    );
  }
}

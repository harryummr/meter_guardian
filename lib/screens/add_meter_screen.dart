import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/meter_provider.dart';
import 'upload_bill_screen.dart';

class AddMeterScreen extends StatefulWidget {
  const AddMeterScreen({super.key});

  @override
  State<AddMeterScreen> createState() => _AddMeterScreenState();
}

class _AddMeterScreenState extends State<AddMeterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final meter = await context.read<MeterProvider>().addMeter(
          name: _nameCtrl.text.trim(),
          meterNumber: _numberCtrl.text.trim().isEmpty ? null : _numberCtrl.text.trim(),
          location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    // Straight into "upload your first bill" so the meter isn't left empty.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => UploadBillScreen(meterId: meter.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Meter')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Meter Name *',
                hintText: 'e.g. Home Meter, Shop Meter',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberCtrl,
              decoration: const InputDecoration(labelText: 'Meter Number (optional)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: 'Location (optional)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Meter'),
            ),
          ],
        ),
      ),
    );
  }
}

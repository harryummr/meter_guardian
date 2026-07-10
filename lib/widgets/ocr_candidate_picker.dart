import 'package:flutter/material.dart';
import '../services/ocr_service.dart';

/// Shows the OCR's best-guess reading (editable) plus any alternative numbers
/// it spotted in the image, so the user can correct a wrong guess in one tap
/// instead of retyping the whole value.
class OcrCandidatePicker extends StatefulWidget {
  final MeterReadingScanResult scanResult;
  final ValueChanged<OcrCandidate?> onSelectionChanged;

  const OcrCandidatePicker({
    super.key,
    required this.scanResult,
    required this.onSelectionChanged,
  });

  @override
  State<OcrCandidatePicker> createState() => _OcrCandidatePickerState();
}

class _OcrCandidatePickerState extends State<OcrCandidatePicker> {
  late TextEditingController _controller;
  OcrCandidate? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.scanResult.best;
    _controller = TextEditingController(text: _selected?.value.toStringAsFixed(0) ?? '');
  }

  void _pick(OcrCandidate c) {
    setState(() {
      _selected = c;
      _controller.text = c.value.toStringAsFixed(0);
    });
    widget.onSelectionChanged(c);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.scanResult;

    if (result.best == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Couldn\'t confidently detect a reading. Please enter it manually.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Reading'),
            onChanged: (_) => widget.onSelectionChanged(null),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              result.isConfident ? Icons.check_circle : Icons.help_outline,
              color: result.isConfident ? Colors.green : Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                result.usedRememberedRegion
                    ? 'Matched this meter\'s remembered display region'
                    : (result.best!.nearKwhLabel
                        ? 'Detected next to a kWh label'
                        : 'Best guess based on digit pattern'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(labelText: 'Confirmed reading'),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null && _selected != null) {
              widget.onSelectionChanged(_manualOverride(parsed));
            } else {
              widget.onSelectionChanged(null);
            }
          },
        ),
        if (result.alternatives.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Other numbers detected — tap if the guess is wrong:',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.alternatives.map((c) {
              return ActionChip(
                label: Text(c.rawText),
                onPressed: () => _pick(c),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  OcrCandidate _manualOverride(double value) {
    final base = _selected!;
    return OcrCandidate(
      rawText: value.toStringAsFixed(0),
      value: value,
      digitCount: value.toStringAsFixed(0).length,
      left: base.left,
      top: base.top,
      right: base.right,
      bottom: base.bottom,
      nearKwhLabel: base.nearKwhLabel,
      matchesRememberedRegion: base.matchesRememberedRegion,
      confidence: base.confidence,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/bill_record.dart';
import '../providers/meter_provider.dart';
import '../services/calculation_service.dart';
import '../services/export_service.dart';
import '../widgets/status_badge.dart';
import 'graph_screen.dart';
import 'upload_bill_screen.dart';
import 'upload_meter_photo_screen.dart';

class MeterDetailScreen extends StatefulWidget {
  final String meterId;
  const MeterDetailScreen({super.key, required this.meterId});

  @override
  State<MeterDetailScreen> createState() => _MeterDetailScreenState();
}

class _MeterDetailScreenState extends State<MeterDetailScreen> {
  bool _exporting = false;

  Future<void> _export(bool asPdf) async {
    setState(() => _exporting = true);
    final provider = context.read<MeterProvider>();
    final data = provider.meters.firstWhere((m) => m.meter.id == widget.meterId);
    final bills = provider.historyFor(widget.meterId);

    final file = asPdf
        ? await ExportService.exportMeterHistoryToPdf(data.meter, bills)
        : await ExportService.exportMeterHistoryToExcel(data.meter, bills);

    setState(() => _exporting = false);
    if (!mounted) return;
    await Share.shareXFiles([XFile(file.path)], text: '${data.meter.name} — usage history');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MeterProvider>();
    final data = provider.meters.firstWhere((m) => m.meter.id == widget.meterId);
    final meter = data.meter;
    final bill = data.activeBill;
    final calc = data.calculation;
    final history = provider.historyFor(widget.meterId);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(meter.name),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'pdf') _export(true);
                if (v == 'excel') _export(false);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
                PopupMenuItem(value: 'excel', child: Text('Export as Excel')),
              ],
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'History'),
            Tab(text: 'Graph'),
          ]),
        ),
        body: _exporting
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _overviewTab(context, meter.id, bill, calc, meter.slabTargets),
                  _historyTab(context, history, meter.slabTargets),
                  GraphScreen(meterId: meter.id),
                ],
              ),
        floatingActionButton: bill == null
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UploadBillScreen(meterId: meter.id)),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Upload Bill'),
              )
            : FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UploadMeterPhotoScreen(meterId: meter.id, billId: bill.id),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Scan Reading'),
              ),
      ),
    );
  }

  Widget _overviewTab(
    BuildContext context,
    String meterId,
    BillRecord? bill,
    MeterCalculation calc,
    List<int> targets,
  ) {
    if (bill == null) {
      return const Center(child: Text('No bill uploaded yet.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Status', style: Theme.of(context).textTheme.titleMedium),
            StatusBadge(status: calc.status),
          ],
        ),
        const SizedBox(height: 16),
        _row('Billing Month', bill.billingMonth),
        _row('Bill Reading (Present)', bill.presentReading.toStringAsFixed(0)),
        _row('Bill Reading (Previous)', bill.previousReading.toStringAsFixed(0)),
        _row('Current Meter Reading', bill.currentReading?.toStringAsFixed(0) ?? 'Not scanned yet'),
        _row('Units Used', calc.unitsUsed?.toStringAsFixed(1) ?? '—'),
        _row('Average Units/Day', calc.averagePerDay?.toStringAsFixed(2) ?? '—'),
        _row('Elapsed Days', calc.elapsedDays?.toStringAsFixed(1) ?? '—'),
        const SizedBox(height: 20),
        Text('Predictions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...targets.map((t) {
          final remaining = calc.remainingUnitsByTarget[t];
          final days = calc.estimatedDaysLeftByTarget[t];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              remaining == null
                  ? 'Not enough data yet for the $t-unit target.'
                  : remaining <= 0
                      ? 'Already at or past $t units.'
                      : 'You can safely use this meter for approximately '
                          '${days?.toStringAsFixed(1) ?? '—'} more days before reaching $t units '
                          '(${remaining.toStringAsFixed(1)} units remaining).',
            ),
          );
        }),
      ],
    );
  }

  Widget _historyTab(BuildContext context, List<BillRecord> history, List<int> targets) {
    if (history.isEmpty) {
      return const Center(child: Text('No bill history yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final b = history[i];
        final calc = CalculationService.calculate(b, targets: targets);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(b.billingMonth, style: const TextStyle(fontWeight: FontWeight.bold)),
                    StatusBadge(status: calc.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Bill Reading: ${b.presentReading.toStringAsFixed(0)}'),
                Text('Current Reading: ${b.currentReading?.toStringAsFixed(0) ?? '—'}'),
                Text('Units Used: ${calc.unitsUsed?.toStringAsFixed(1) ?? '—'}'),
                Text('Average/Day: ${calc.averagePerDay?.toStringAsFixed(2) ?? '—'}'),
                Text('Issue Date: ${DateFormat('dd MMM yyyy').format(b.issueDate)}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

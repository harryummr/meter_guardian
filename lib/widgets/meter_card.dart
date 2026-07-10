import 'package:flutter/material.dart';
import '../providers/meter_provider.dart';
import 'status_badge.dart';

class MeterCard extends StatelessWidget {
  final MeterWithData data;
  final VoidCallback onTap;

  const MeterCard({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meter = data.meter;
    final bill = data.activeBill;
    final calc = data.calculation;
    final primaryTarget = meter.slabTargets.isNotEmpty ? meter.slabTargets.first : 200;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meter.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  StatusBadge(status: calc.status),
                ],
              ),
              if (meter.location != null && meter.location!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(meter.location!,
                      style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                ),
              const SizedBox(height: 14),
              if (bill == null)
                Text(
                  'No bill uploaded yet — tap to add one',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                )
              else ...[
                Row(
                  children: [
                    _statTile(context, 'Bill Reading', bill.presentReading.toStringAsFixed(0)),
                    _statTile(context, 'Current Reading',
                        bill.currentReading?.toStringAsFixed(0) ?? '—'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statTile(context, 'Units Used', calc.unitsUsed?.toStringAsFixed(1) ?? '—'),
                    _statTile(context, 'Avg/Day', calc.averagePerDay?.toStringAsFixed(2) ?? '—'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statTile(
                      context,
                      'Left until $primaryTarget',
                      calc.remainingUnitsByTarget[primaryTarget]?.toStringAsFixed(1) ?? '—',
                    ),
                    _statTile(
                      context,
                      'Est. Days Left',
                      calc.estimatedDaysLeftByTarget[primaryTarget] != null
                          ? calc.estimatedDaysLeftByTarget[primaryTarget]!.toStringAsFixed(1)
                          : '—',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

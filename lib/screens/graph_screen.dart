import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../providers/meter_provider.dart';
import '../services/calculation_service.dart';

class GraphScreen extends StatelessWidget {
  final String meterId;
  const GraphScreen({super.key, required this.meterId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MeterProvider>();
    final meterData = provider.meters.firstWhere((m) => m.meter.id == meterId);
    final history = provider.historyFor(meterId).reversed.toList(); // oldest -> newest

    if (history.isEmpty) {
      return const Center(child: Text('Not enough data yet for charts.'));
    }

    final unitSpots = <FlSpot>[];
    final avgSpots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      final calc = CalculationService.calculate(history[i], targets: meterData.meter.slabTargets);
      unitSpots.add(FlSpot(i.toDouble(), calc.unitsUsed ?? 0));
      avgSpots.add(FlSpot(i.toDouble(), calc.averagePerDay ?? 0));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Units Used Per Billing Cycle', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              barGroups: [
                for (int i = 0; i < unitSpots.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: unitSpots[i].y,
                      color: Theme.of(context).colorScheme.primary,
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ]),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= history.length) return const SizedBox.shrink();
                      final label = history[idx].billingMonth;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label.length > 6 ? label.substring(0, 6) : label,
                          style: const TextStyle(fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text('Average Units / Day Trend', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: avgSpots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.secondary,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= history.length) return const SizedBox.shrink();
                      final label = history[idx].billingMonth;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label.length > 6 ? label.substring(0, 6) : label,
                          style: const TextStyle(fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
            ),
          ),
        ),
      ],
    );
  }
}

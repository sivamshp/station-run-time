// Flutter app: Station Runtime Calculator (24hr format)
// Save as lib/main.dart in a new Flutter project (Flutter 3.0+ with sound null-safety)
// This app implements the functionality of the provided Python script:
// - Input multiple ON/OFF intervals per unit (Unit1..Unit4)
// - Handles overnight intervals (OFF earlier than ON -> treat as next day)
// - Shows per-unit total runtime, total combined (sum of units), and merged station runtime

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const StationRuntimeApp());
}

class StationRuntimeApp extends StatelessWidget {
  const StationRuntimeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Station Runtime Calculator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StationHomePage(),
    );
  }
}

class StationHomePage extends StatefulWidget {
  const StationHomePage({Key? key}) : super(key: key);

  @override
  State<StationHomePage> createState() => _StationHomePageState();
}

class _StationHomePageState extends State<StationHomePage> {
  final List<String> fixedUnits = ['Unit1', 'Unit2', 'Unit3', 'Unit4'];

  // For each unit store a list of intervals (pair of TimeOfDay)
  final Map<String, List<Interval>> unitsData = {};

  @override
  void initState() {
    super.initState();
    for (final u in fixedUnits) {
      unitsData[u] = <Interval>[];
    }
  }

  void addInterval(String unit) async {
    final TimeOfDay? on = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (on == null) return; // canceled

    final TimeOfDay? off = await showTimePicker(
      context: context,
      initialTime: on,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (off == null) return; // canceled

    setState(() {
      unitsData[unit]!.add(Interval(on, off));
    });
  }

  void removeInterval(String unit, int index) {
    setState(() {
      unitsData[unit]!.removeAt(index);
    });
  }

  Duration _durationForInterval(Interval iv) {
    final now = DateTime.now();
    DateTime onDT = DateTime(now.year, now.month, now.day, iv.on.hour, iv.on.minute);
    DateTime offDT = DateTime(now.year, now.month, now.day, iv.off.hour, iv.off.minute);
    if (offDT.isBefore(onDT) || offDT.isAtSameMomentAs(onDT)) {
      // treat as next day
      offDT = offDT.add(const Duration(days: 1));
    }
    return offDT.difference(onDT);
  }

  double minutesToDecimalHours(double minutes) => minutes / 60.0;

  String formatDurationMinutes(double minutes) {
    final int hours = minutes ~/ 60;
    final int mins = minutes.toInt() % 60;
    final double decHours = minutes / 60.0;
    return "${decHours.toStringAsFixed(2)} hours ($hours hour(s) and $mins minute(s))";
  }

  Map<String, double> calculatePerUnitMinutes() {
    final Map<String, double> results = {};
    for (final unit in fixedUnits) {
      final list = unitsData[unit]!;
      double total = 0;
      for (final iv in list) {
        total += _durationForInterval(iv).inMinutes.toDouble();
      }
      results[unit] = total;
    }
    return results;
  }

  double calculateTotalCombinedMinutes(Map<String, double> perUnit) {
    double sum = 0;
    perUnit.values.forEach((v) => sum += v);
    return sum;
  }

  // Merge intervals from all units and compute merged runtime minutes
  double calculateStationRuntimeMinutes() {
    final now = DateTime.now();
    final List<_DateInterval> all = [];
    for (final list in unitsData.values) {
      for (final iv in list) {
        DateTime onDT = DateTime(now.year, now.month, now.day, iv.on.hour, iv.on.minute);
        DateTime offDT = DateTime(now.year, now.month, now.day, iv.off.hour, iv.off.minute);
        if (offDT.isBefore(onDT) || offDT.isAtSameMomentAs(onDT)) {
          offDT = offDT.add(const Duration(days: 1));
        }
        all.add(_DateInterval(onDT, offDT));
      }
    }

    if (all.isEmpty) return 0;

    all.sort((a, b) => a.start.compareTo(b.start));

    final List<_DateInterval> merged = [];
    merged.add(all.first);

    for (var i = 1; i < all.length; i++) {
      final current = all[i];
      final last = merged.last;
      if (!current.start.isAfter(last.end)) {
        // overlap
        final newEnd = current.end.isAfter(last.end) ? current.end : last.end;
        merged[merged.length - 1] = _DateInterval(last.start, newEnd);
      } else {
        merged.add(current);
      }
    }

    double totalMinutes = 0;
    for (final m in merged) {
      totalMinutes += m.end.difference(m.start).inMinutes.toDouble();
    }
    return totalMinutes;
  }

  String timeOfDayToString(TimeOfDay t) {
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    return DateFormat.Hm().format(dt); // 24-hour format
  }

  void clearAll() {
    setState(() {
      for (final k in fixedUnits) unitsData[k] = <Interval>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    final perUnitMins = calculatePerUnitMinutes();
    final totalCombined = calculateTotalCombinedMinutes(perUnitMins);
    final stationMinutes = calculateStationRuntimeMinutes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Runtime Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear all intervals',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear all intervals?'),
                  content: const Text('This will remove all entered ON/OFF intervals.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(
                        onPressed: () {
                          clearAll();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear')),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter ON/OFF times for each unit (24-hour format):', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: fixedUnits.length,
                itemBuilder: (context, idx) {
                  final unit = fixedUnits[idx];
                  final intervals = unitsData[unit]!;
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(unit, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add Interval'),
                                onPressed: () => addInterval(unit),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          intervals.isEmpty
                              ? const Text('No intervals entered', style: TextStyle(color: Colors.grey))
                              : Column(
                                  children: [
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: intervals.length,
                                      itemBuilder: (c, i) {
                                        final iv = intervals[i];
                                        final dur = _durationForInterval(iv);
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text('${timeOfDayToString(iv.on)}  →  ${timeOfDayToString(iv.off)}'),
                                          subtitle: Text('${dur.inHours}h ${dur.inMinutes % 60}m'),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete_outline),
                                            onPressed: () => removeInterval(unit, i),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 6),
                          Text('Total for $unit: ${formatDurationMinutes(perUnitMins[unit] ?? 0)}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Total combined run time (sum of all units): ${formatDurationMinutes(totalCombined)}'),
                    const SizedBox(height: 6),
                    Text('Station run time (merged across units): ${formatDurationMinutes(stationMinutes)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class Interval {
  final TimeOfDay on;
  final TimeOfDay off;

  Interval(this.on, this.off);
}

class _DateInterval {
  final DateTime start;
  final DateTime end;

  _DateInterval(this.start, this.end);
}


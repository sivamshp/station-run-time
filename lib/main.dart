import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for TextInputFormatter
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
  final List<String> fixedUnits = <String>['Unit1', 'Unit2', 'Unit3', 'Unit4'];

  // For each unit store a list of intervals (pair of TimeOfDay)
  final Map<String, List<Interval>> unitsData = <String, List<Interval>>{};

  @override
  void initState() {
    super.initState();
    for (final String u in fixedUnits) {
      unitsData[u] = <Interval>[];
    }
  }

  /// Shows a custom dialog for simple time input (hhmm format).
  Future<TimeOfDay?> _showSimpleTimeInputDialog(BuildContext context, String title) async {
    return showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return SimpleTimeInputDialog(title: title);
      },
    );
  }

  void addInterval(String unit) async {
    final TimeOfDay? on = await _showSimpleTimeInputDialog(context, 'Enter ON Time (hhmm)');
    if (on == null) return; // canceled

    final TimeOfDay? off = await _showSimpleTimeInputDialog(context, 'Enter OFF Time (hhmm)');
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
    final DateTime now = DateTime.now();
    DateTime onDT = DateTime(now.year, now.month, now.day, iv.on.hour, iv.on.minute);
    DateTime offDT = DateTime(now.year, now.month, now.day, iv.off.hour, iv.off.minute);
    if (offDT.isBefore(onDT) || offDT.isAtSameMomentAs(onDT)) {
      // treat as next day
      offDT = offDT.add(const Duration(days: 1));
    }
    return offDT.difference(onDT);
  }

  String formatDurationMinutes(double minutes) {
    final int hours = minutes ~/ 60;
    final int mins = minutes.toInt() % 60;
    final double decHours = minutes / 60.0;
    return "${decHours.toStringAsFixed(2)} hours ($hours hour(s) and $mins minute(s))";
  }

  Map<String, double> calculatePerUnitMinutes() {
    final Map<String, double> results = <String, double>{};
    for (final String unit in fixedUnits) {
      final List<Interval> list = unitsData[unit]!;
      double total = 0;
      for (final Interval iv in list) {
        total += _durationForInterval(iv).inMinutes.toDouble();
      }
      results[unit] = total;
    }
    return results;
  }

  double calculateTotalCombinedMinutes(Map<String, double> perUnit) {
    double sum = 0;
    for (final double v in perUnit.values) {
      sum += v;
    }
    return sum;
  }

  // Merge intervals from all units and return the list of merged intervals.
  List<_DateInterval> _getStationMergedIntervals() {
    final DateTime now = DateTime.now();
    final List<_DateInterval> all = <_DateInterval>[];
    for (final List<Interval> list in unitsData.values) {
      for (final Interval iv in list) {
        DateTime onDT = DateTime(now.year, now.month, now.day, iv.on.hour, iv.on.minute);
        DateTime offDT = DateTime(now.year, now.month, now.day, iv.off.hour, iv.off.minute);
        if (offDT.isBefore(onDT) || offDT.isAtSameMomentAs(onDT)) {
          offDT = offDT.add(const Duration(days: 1));
        }
        all.add(_DateInterval(onDT, offDT));
      }
    }

    if (all.isEmpty) return <_DateInterval>[];

    all.sort((_DateInterval a, _DateInterval b) => a.start.compareTo(b.start));

    final List<_DateInterval> merged = <_DateInterval>[];
    merged.add(all.first);

    for (int i = 1; i < all.length; i++) {
      final _DateInterval current = all[i];
      final _DateInterval last = merged.last;
      if (!current.start.isAfter(last.end)) {
        // overlap
        final DateTime newEnd = current.end.isAfter(last.end) ? current.end : last.end;
        merged[merged.length - 1] = _DateInterval(last.start, newEnd);
      } else {
        merged.add(current);
      }
    }
    return merged;
  }

  // Helper to calculate total minutes from a list of _DateIntervals
  double _calculateTotalMinutesFromDateIntervals(List<_DateInterval> intervals) {
    double totalMinutes = 0;
    for (final _DateInterval m in intervals) {
      totalMinutes += m.end.difference(m.start).inMinutes.toDouble();
    }
    return totalMinutes;
  }

  String timeOfDayToString(TimeOfDay t) {
    final DateTime dt = DateTime(0, 1, 1, t.hour, t.minute);
    return DateFormat.Hm().format(dt); // 24-hour format
  }

  void clearAll() {
    setState(() {
      for (final String k in fixedUnits) {
        unitsData[k] = <Interval>[];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, double> perUnitMins = calculatePerUnitMinutes();
    final double totalCombined = calculateTotalCombinedMinutes(perUnitMins);
    final List<_DateInterval> stationMergedIntervals = _getStationMergedIntervals();
    final double stationMinutes = _calculateTotalMinutesFromDateIntervals(stationMergedIntervals);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Runtime Calculator'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear all intervals',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (BuildContext _) => AlertDialog(
                  title: const Text('Clear all intervals?'),
                  content: const Text('This will remove all entered ON/OFF intervals.'),
                  actions: <Widget>[
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
          children: <Widget>[
            const Text('Enter ON/OFF times for each unit (24-hour hhmm format):', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: fixedUnits.length,
                itemBuilder: (BuildContext context, int idx) {
                  final String unit = fixedUnits[idx];
                  final List<Interval> intervals = unitsData[unit]!;
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
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
                                  children: <Widget>[
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: intervals.length,
                                      itemBuilder: (BuildContext c, int i) {
                                        final Interval iv = intervals[i];
                                        final Duration dur = _durationForInterval(iv);
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
                  children: <Widget>[
                    const Text('Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Total combined run time (sum of all units): ${formatDurationMinutes(totalCombined)}'),
                    const SizedBox(height: 6),
                    Text('Station run time (merged across units): ${formatDurationMinutes(stationMinutes)}'),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.timeline),
                        label: const Text('View Merged Intervals'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (BuildContext ctx) => StationMergedIntervalsPage(
                                mergedIntervals: stationMergedIntervals,
                                totalMergedMinutes: stationMinutes,
                                formatDurationMinutes: formatDurationMinutes,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
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

/// A custom dialog for entering time in a simple 'hhmm' 24-hour format.
class SimpleTimeInputDialog extends StatefulWidget {
  final String title;

  const SimpleTimeInputDialog({Key? key, required this.title}) : super(key: key);

  @override
  State<SimpleTimeInputDialog> createState() => _SimpleTimeInputDialogState();
}

class _SimpleTimeInputDialogState extends State<SimpleTimeInputDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final String input = _controller.text;
    if (input.length != 4) {
      setState(() {
        _errorText = 'Enter exactly 4 digits (hhmm)';
      });
      return;
    }

    final String hourStr = input.substring(0, 2);
    final String minuteStr = input.substring(2, 4);

    final int? hour = int.tryParse(hourStr);
    final int? minute = int.tryParse(minuteStr);

    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      setState(() {
        _errorText = 'Invalid time. Use hhmm format (00-23 for hours, 00-59 for minutes).';
      });
      return;
    }

    Navigator.pop(context, TimeOfDay(hour: hour, minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.phone,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        decoration: InputDecoration(
          hintText: 'hhmm (e.g., 0930 for 9:30 AM, 1545 for 3:45 PM)',
          errorText: _errorText,
          counterText: "", // Hide the default character counter
        ),
        autofocus: true,
        onSubmitted: (String _) => _validateAndSubmit(), // Allows submitting with enter key
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _validateAndSubmit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// A new widget to display the station's merged intervals on a separate page.
class StationMergedIntervalsPage extends StatelessWidget {
  final List<_DateInterval> mergedIntervals;
  final double totalMergedMinutes;
  final String Function(double) formatDurationMinutes; // Function to format durations

  const StationMergedIntervalsPage({
    Key? key,
    required this.mergedIntervals,
    required this.totalMergedMinutes,
    required this.formatDurationMinutes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Station Merged Intervals'),
        // A back button is automatically provided by MaterialApp when pushing a new route
        // when the previous route is available in the navigator stack.
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Total Station Run Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      formatDurationMinutes(totalMergedMinutes),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Merged Intervals Details:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: mergedIntervals.isEmpty
                  ? const Center(child: Text('No merged intervals to display', style: TextStyle(color: Colors.grey, fontSize: 16)))
                  : ListView.builder(
                      itemCount: mergedIntervals.length,
                      itemBuilder: (BuildContext c, int i) {
                        final _DateInterval iv = mergedIntervals[i];
                        final Duration dur = iv.end.difference(iv.start);
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              '${DateFormat.Hm().format(iv.start)}  →  ${DateFormat.Hm().format(iv.end)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${dur.inHours}h ${dur.inMinutes % 60}m'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
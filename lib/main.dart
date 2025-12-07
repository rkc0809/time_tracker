import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'time_tracker_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final model = TimeTrackerModel();
  await model.init();

  runApp(
    ChangeNotifierProvider<TimeTrackerModel>.value(
      value: model,
      child: const TimeTrackerApp(),
    ),
  );
}

class TimeTrackerApp extends StatelessWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const relationOptions = <String>[
    'Mother',
    'Father',
    'Brother',
    'Sister',
    'Friend',
    'Relative',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TimeTrackerModel>();

    if (!model.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Time Tracker'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Track'),
              Tab(text: 'Summary'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddPersonDialog(context),
          child: const Icon(Icons.add),
        ),
        body: const TabBarView(
          children: [
            TrackTab(),
            SummaryTab(),
          ],
        ),
      ),
    );
  }

  void _showAddPersonDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedType = 'person'; // 'person', 'place', 'activity'
    String? selectedRelation;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      isExpanded: true, // ✅ avoids right overflow
                      decoration: const InputDecoration(
                        labelText: 'Type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'person',
                          child: Text('Person'),
                        ),
                        DropdownMenuItem(
                          value: 'place',
                          child: Text('Place'),
                        ),
                        DropdownMenuItem(
                          value: 'activity',
                          child: Text('Activity'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedType = value;
                          if (selectedType != 'person') {
                            selectedRelation = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (selectedType == 'person')
                      DropdownButtonFormField<String>(
                        value: selectedRelation,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Relation',
                        ),
                        items: relationOptions
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(r),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRelation = value;
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    await context.read<TimeTrackerModel>().addPerson(
                          name,
                          selectedType,
                          selectedType == 'person' ? selectedRelation : null,
                        );
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class TrackTab extends StatelessWidget {
  const TrackTab({super.key});

  String _typeLabel(Person p) {
    switch (p.type) {
      case 'person':
        return p.relation ?? 'Person';
      case 'place':
        return 'Place';
      case 'activity':
        return 'Activity';
      default:
        return p.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TimeTrackerModel>();
    final persons = model.persons;
    final activeIds = model.activePersonIds;
    final remarks = model.todayRemarks;

    return Column(
      children: [
        // ✅ Search now only in Track tab
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: model.setSearchQuery,
          ),
        ),
        Expanded(
          child: persons.isEmpty
              ? const Center(
                  child:
                      Text('Add a person / place / activity to start tracking.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: persons.length,
                  itemBuilder: (context, index) {
                    final person = persons[index];
                    final isActive = person.id != null &&
                        activeIds.contains(person.id);
                    final remark =
                        person.id != null ? remarks[person.id!] : null;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _typeLabel(person),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () {
                                    if (isActive) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Stop tracking before deleting this item.'),
                                        ),
                                      );
                                      return;
                                    }
                                    _confirmDelete(context, person);
                                  },
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isActive
                                        ? Colors.red
                                        : Colors.green, // ✅ color change
                                  ),
                                  onPressed: () => context
                                      .read<TimeTrackerModel>()
                                      .toggleTracking(person),
                                  child: Text(isActive ? 'Stop' : 'Start'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Today remark:'),
                                const Spacer(),
                                ChoiceChip(
                                  label: const Text('Worthwhile'),
                                  selected: remark == true,
                                  onSelected: (_) => context
                                      .read<TimeTrackerModel>()
                                      .setTodayRemark(person, true),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Worthless'),
                                  selected: remark == false,
                                  onSelected: (_) => context
                                      .read<TimeTrackerModel>()
                                      .setTodayRemark(person, false),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, Person person) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete'),
        content: Text(
            'Delete "${person.name}" and all its time records and remarks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<TimeTrackerModel>().deletePerson(person);
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class SummaryTab extends StatelessWidget {
  const SummaryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<TimeTrackerModel>();
    final stats = model.stats;
    final persons = model.persons;

    // relation summary only for type == 'person'
    final Map<String, int> relationDurations = {};
    final personById = {for (var p in persons) p.id: p};

    for (final s in stats) {
      final p = personById[s.personId];
      if (p == null) continue;
      if (p.type != 'person') continue;

      final rel = p.relation ?? 'Unspecified';
      relationDurations[rel] =
          (relationDurations[rel] ?? 0) + s.totalDurationMillis;
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RangeChip(
              label: 'Week',
              selected: model.currentRange == StatsRange.week,
              onTap: () => context
                  .read<TimeTrackerModel>()
                  .setStatsRange(StatsRange.week),
            ),
            const SizedBox(width: 8),
            _RangeChip(
              label: 'Month',
              selected: model.currentRange == StatsRange.month,
              onTap: () => context
                  .read<TimeTrackerModel>()
                  .setStatsRange(StatsRange.month),
            ),
            const SizedBox(width: 8),
            _RangeChip(
              label: 'Year',
              selected: model.currentRange == StatsRange.year,
              onTap: () => context
                  .read<TimeTrackerModel>()
                  .setStatsRange(StatsRange.year),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (stats.isEmpty)
          const Expanded(
            child: Center(child: Text('No data yet.')),
          )
        else ...[
          if (relationDurations.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Text(
                'Time by Relation',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: RelationPieChart(
                data: relationDurations,
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Padding(
            padding: EdgeInsets.only(bottom: 4.0),
            child: Text(
              'Time by Person / Place / Activity',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: StatsBarChart(stats: stats),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: stats.length,
              itemBuilder: (context, index) {
                final s = stats[index];
                final hours = s.totalDurationMillis ~/ (1000 * 60 * 60);
                final minutes =
                    (s.totalDurationMillis ~/ (1000 * 60)) % 60;
                return ListTile(
                  title: Text(s.personName),
                  subtitle: Text('${hours}h ${minutes}m'),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class StatsBarChart extends StatelessWidget {
  final List<PersonDuration> stats;

  const StatsBarChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    final maxMillis =
        stats.map((e) => e.totalDurationMillis).reduce((a, b) => a > b ? a : b);
    final maxMillisSafe = maxMillis == 0 ? 1 : maxMillis;

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth / (stats.length * 1.5);

        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: stats.map((s) {
                  final ratio = s.totalDurationMillis / maxMillisSafe;
                  final barHeight = constraints.maxHeight * ratio * 0.8;

                  return SizedBox(
                    width: barWidth,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: barHeight,
                        width: barWidth * 0.6,
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: stats.map((s) {
                return SizedBox(
                  width: barWidth,
                  child: Text(
                    s.personName,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

/// ✅ Pie chart adjusted so it doesn't overflow bottom
class RelationPieChart extends StatelessWidget {
  final Map<String, int> data;

  const RelationPieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.values.fold<int>(0, (sum, v) => sum + v);
    if (total == 0) return const SizedBox.shrink();

    final colors = <Color>[
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.pink,
    ];

    final entries = data.entries.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180,
          width: 180,
          child: CustomPaint(
            painter: _PiePainter(
              entries: entries,
              colors: colors,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            for (int i = 0; i < entries.length; i++)
              _LegendItem(
                color: colors[i % colors.length],
                label: entries[i].key,
              ),
          ],
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final List<Color> colors;

  _PiePainter({required this.entries, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    if (total == 0) return;

    double startRadian = -3.14159 / 2; // start at top
    for (int i = 0; i < entries.length; i++) {
      final sweep = (entries[i].value / total) * 3.14159 * 2;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, startRadian, sweep, true, paint);
      startRadian += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.entries != entries;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

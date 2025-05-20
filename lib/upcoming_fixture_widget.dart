import 'package:flutter/material.dart';
import 'fixture_loader.dart';

class UpcomingFixtureWidget extends StatefulWidget {
  const UpcomingFixtureWidget({super.key});

  @override
  State<UpcomingFixtureWidget> createState() => _UpcomingFixtureWidgetState();
}

class _UpcomingFixtureWidgetState extends State<UpcomingFixtureWidget> {
  bool _includeNonPremier = false;
  late Future<List<Fixture>> _fixturesFuture;

  @override
  void initState() {
    super.initState();
    _fixturesFuture = FixtureLoader.loadFixtures();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Fixture>>(
      future: _fixturesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load fixtures.'));
        }
        final fixtures = snapshot.data ?? [];
        final filtered = fixtures.where((f) => _includeNonPremier || f.premier).toList();
        if (filtered.isEmpty) {
          return const Center(child: Text('No upcoming fixtures.'));
        }
        
        // Sort by date (assuming date_time is in dd/MM/yyyy h:mm a)
        filtered.sort((a, b) {
          DateTime parse(String s) {
            try {
              return DateTime.parse(
                s.replaceAllMapped(
                  RegExp(r'(\d{2})/(\d{2})/(\d{4}) (\d{1,2}):(\d{2}) ([AP]M)'),
                  (m) {
                    final day = m[1]!;
                    final month = m[2]!;
                    final year = m[3]!;
                    var hour = int.parse(m[4]!);
                    final minute = m[5]!;
                    final ampm = m[6]!;
                    if (ampm == 'PM' && hour != 12) hour += 12;
                    if (ampm == 'AM' && hour == 12) hour = 0;
                    return '$year-$month-$day $hour:$minute:00';
                  },
                ),
              );
            } catch (_) {
              return DateTime.now();
            }
          }
          return parse(a.dateTime).compareTo(parse(b.dateTime));
        });

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Include non-premier teams', style: Theme.of(context).textTheme.bodyMedium),
                Switch(
                  value: _includeNonPremier,
                  onChanged: (val) => setState(() => _includeNonPremier = val),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final fixture = filtered[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fixture.sport,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fixture.competition,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(fixture.dateTime),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 18, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(fixture.venue),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${fixture.homeOrg} vs ${fixture.awayOrg}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (fixture.premier)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Chip(
                                label: const Text('Premier'),
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              ),
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
      },
    );
  }
}

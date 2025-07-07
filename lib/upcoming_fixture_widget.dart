// lib/upcoming_fixture_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'models.dart';

class UpcomingFixtureWidget extends StatefulWidget {
  const UpcomingFixtureWidget({super.key});

  @override
  State<UpcomingFixtureWidget> createState() => _UpcomingFixtureWidgetState();
}

class _UpcomingFixtureWidgetState extends State<UpcomingFixtureWidget> {
  bool _showAllFixtures = false; 
  late Future<List<Fixture>> _fixturesFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fixturesFuture = _apiService.getFixtures();
  }

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Date TBC';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('E, d MMM yyyy, h:mm a').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Show All Fixtures', style: Theme.of(context).textTheme.bodyMedium),
              Switch(
                value: _showAllFixtures,
                onChanged: (val) => setState(() => _showAllFixtures = val),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Fixture>>(
            future: _fixturesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Failed to load fixtures.\nError: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              
              final allFixtures = snapshot.data ?? [];
              if (allFixtures.isEmpty) {
                return const Center(child: Text('No upcoming fixtures found for Sacred Heart College.'));
              }

              final filteredFixtures = allFixtures
                  .where((f) => _showAllFixtures || f.premier)
                  .toList();
              
              if (filteredFixtures.isEmpty && !_showAllFixtures) {
                 return const Center(child: Text('No upcoming premier fixtures found.'));
              }

              filteredFixtures.sort((a, b) {
                try {
                  return DateTime.parse(a.dateTime).compareTo(DateTime.parse(b.dateTime));
                } catch (_) {
                  return 0;
                }
              });

              return ListView.builder(
                itemCount: filteredFixtures.length,
                itemBuilder: (context, index) {
                  final fixture = filteredFixtures[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(_formatDateTime(fixture.dateTime)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 18, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(fixture.venue)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${fixture.homeSchool}: ${fixture.homeTeam}\nvs\n${fixture.awaySchool}: ${fixture.awayTeam}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.5),
                          ),
                          if (fixture.premier)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Chip(
                                label: const Text('Premier'),
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                side: BorderSide.none,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

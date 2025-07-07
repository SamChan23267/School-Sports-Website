// lib/upcoming_fixture_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'models.dart';

// --- Filter Model and Enums ---
enum PremierStatus { all, premierOnly }
enum LocationStatus { all, home, away }

class FixtureFilters {
  PremierStatus premierStatus;
  LocationStatus locationStatus;
  String? sport;
  String? team;
  DateTimeRange? dateRange;

  FixtureFilters({
    this.premierStatus = PremierStatus.premierOnly,
    this.locationStatus = LocationStatus.all,
    this.sport,
    this.team,
    this.dateRange,
  });
}
// ---------------------------------

class UpcomingFixtureWidget extends StatefulWidget {
  const UpcomingFixtureWidget({super.key});

  @override
  State<UpcomingFixtureWidget> createState() => _UpcomingFixtureWidgetState();
}

class _UpcomingFixtureWidgetState extends State<UpcomingFixtureWidget> {
  late Future<List<Fixture>> _fixturesFuture;
  final ApiService _apiService = ApiService();
  FixtureFilters _filters = FixtureFilters();
  bool _isCompactView = false;

  @override
  void initState() {
    super.initState();
    _fixturesFuture = _apiService.getFixtures();
  }

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Date TBC';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('E, d MMM, h:mm a').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  void _showFilterDialog(List<Fixture> allFixtures) {
    final sports = allFixtures.map((f) => f.sport).toSet().toList()..sort();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            
            final sacredHeartTeams = allFixtures
                .where((f) => _filters.sport == null || f.sport == _filters.sport)
                .map((f) => f.homeSchool == "Sacred Heart College (Auckland)" ? f.homeTeam : f.awayTeam)
                .toSet().toList()..sort();

            return AlertDialog(
              title: const Text('Filter Fixtures'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status'),
                    DropdownButton<PremierStatus>(
                      value: _filters.premierStatus,
                      onChanged: (PremierStatus? newValue) {
                        setDialogState(() => _filters.premierStatus = newValue!);
                      },
                      items: PremierStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s == PremierStatus.all ? 'All Fixtures' : 'Premier Only'))).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Location'),
                    DropdownButton<LocationStatus>(
                      value: _filters.locationStatus,
                      onChanged: (LocationStatus? newValue) {
                        setDialogState(() => _filters.locationStatus = newValue!);
                      },
                      items: LocationStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.capitalize()))).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Sport'),
                    DropdownButton<String>(
                      value: _filters.sport,
                      hint: const Text('All Sports'),
                      isExpanded: true,
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          _filters.sport = newValue;
                          _filters.team = null;
                        });
                      },
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Sports')),
                        ...sports.map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Team'),
                    DropdownButton<String>(
                      value: _filters.team,
                      hint: const Text('All Teams'),
                      isExpanded: true,
                      onChanged: (String? newValue) {
                        setDialogState(() => _filters.team = newValue);
                      },
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Teams')),
                        ...sacredHeartTeams.map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Date Range'),
                    const SizedBox(height: 8),
                    // --- NEW: Separate Date Pickers ---
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            child: Text(_filters.dateRange?.start == null ? 'Start Date' : DateFormat.yMd().format(_filters.dateRange!.start)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _filters.dateRange?.start ?? DateTime.now(),
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  final end = _filters.dateRange?.end ?? picked.add(const Duration(days: 30));
                                  _filters.dateRange = DateTimeRange(start: picked, end: end);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            child: Text(_filters.dateRange?.end == null ? 'End Date' : DateFormat.yMd().format(_filters.dateRange!.end)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _filters.dateRange?.end ?? DateTime.now(),
                                firstDate: _filters.dateRange?.start ?? DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  final start = _filters.dateRange?.start ?? picked.subtract(const Duration(days: 30));
                                  _filters.dateRange = DateTimeRange(start: start, end: picked);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    )
                    // --- END NEW ---
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _filters = FixtureFilters());
                    Navigator.of(context).pop();
                  },
                  child: const Text('Reset'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  _fixturesFuture.then((allFixtures) {
                    if (allFixtures.isNotEmpty) {
                      _showFilterDialog(allFixtures);
                    }
                  });
                },
                tooltip: 'Filter Fixtures',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_isCompactView ? Icons.view_stream : Icons.view_list),
                onPressed: () {
                  setState(() {
                    _isCompactView = !_isCompactView;
                  });
                },
                tooltip: _isCompactView ? 'Show Detailed View' : 'Show Compact View',
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
                return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Failed to load fixtures.\nError: ${snapshot.error}', textAlign: TextAlign.center)));
              }
              
              final allFixtures = snapshot.data ?? [];
              if (allFixtures.isEmpty) {
                return const Center(child: Text('No upcoming fixtures found for Sacred Heart College.'));
              }

              final filteredFixtures = allFixtures.where((f) {
                final premierMatch = _filters.premierStatus == PremierStatus.all || f.premier;
                final sportMatch = _filters.sport == null || f.sport == _filters.sport;
                final teamMatch = _filters.team == null || f.homeTeam == _filters.team || f.awayTeam == _filters.team;
                final locationMatch = _filters.locationStatus == LocationStatus.all ||
                                      (_filters.locationStatus == LocationStatus.home && f.venue.toLowerCase().contains("sacred heart")) ||
                                      (_filters.locationStatus == LocationStatus.away && !f.venue.toLowerCase().contains("sacred heart"));
                final dateMatch = _filters.dateRange == null || 
                                  (DateTime.parse(f.dateTime).isAfter(_filters.dateRange!.start.subtract(const Duration(days:1))) && 
                                   DateTime.parse(f.dateTime).isBefore(_filters.dateRange!.end.add(const Duration(days: 1))));

                return premierMatch && sportMatch && teamMatch && locationMatch && dateMatch;
              }).toList();
              
              if (filteredFixtures.isEmpty) {
                 return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No fixtures match the current filters.', textAlign: TextAlign.center)));
              }

              filteredFixtures.sort((a, b) => DateTime.parse(a.dateTime).compareTo(DateTime.parse(b.dateTime)));

              return ListView.builder(
                itemCount: filteredFixtures.length,
                itemBuilder: (context, index) {
                  final fixture = filteredFixtures[index];
                  return _isCompactView
                      ? _CompactFixtureCard(fixture: fixture)
                      : _DetailedFixtureCard(fixture: fixture);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CompactFixtureCard extends StatelessWidget {
  final Fixture fixture;
  const _CompactFixtureCard({required this.fixture});

  String _formatCompactDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Date TBC';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('E, d MMM, h:mm a').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const String ourSchool = "Sacred Heart College (Auckland)";
    final ourTeam = fixture.homeSchool == ourSchool ? fixture.homeTeam : fixture.awayTeam;
    final opponentSchool = fixture.homeSchool == ourSchool ? fixture.awaySchool : fixture.homeSchool;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fixture.sport, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('$ourTeam vs $opponentSchool', style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(_formatCompactDateTime(fixture.dateTime), style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _DetailedFixtureCard extends StatelessWidget {
  final Fixture fixture;
  const _DetailedFixtureCard({required this.fixture});

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Date TBC';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('E, d MMM yy, h:mm a').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fixture.sport, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(fixture.competition, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(_formatDateTime(fixture.dateTime)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(fixture.venue)),
            ]),
            const Divider(height: 24),
            _TeamVsWidget(fixture: fixture),
            if (fixture.premier)
              Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  label: const Text('Premier'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  side: BorderSide.none,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamVsWidget extends StatelessWidget {
  final Fixture fixture;
  const _TeamVsWidget({required this.fixture});

  Widget _buildTeamRow(BuildContext context, String school, String team, String? logoUrl) {
    return Row(
      children: [
        if (logoUrl != null && logoUrl.isNotEmpty)
          Image.network(
            logoUrl,
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 24),
          )
        else
          const Icon(Icons.shield, size: 24),
        const SizedBox(width: 8),
        Expanded(child: Text('$school: $team', style: Theme.of(context).textTheme.titleMedium)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamRow(context, fixture.homeSchool, fixture.homeTeam, fixture.homeOrgLogo),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
          child: Text('vs'),
        ),
        _buildTeamRow(context, fixture.awaySchool, fixture.awayTeam, fixture.awayOrgLogo),
      ],
    );
  }
}

extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return this;
      return "${this[0].toUpperCase()}${substring(1)}";
    }
}

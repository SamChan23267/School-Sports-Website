// lib/upcoming_fixture_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'models.dart';
import 'fixture_detail_screen.dart'; 


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
  final bool isResultsView;

  const UpcomingFixtureWidget({super.key, required this.isResultsView});

  @override
  State<UpcomingFixtureWidget> createState() => _UpcomingFixtureWidgetState();
}

class _UpcomingFixtureWidgetState extends State<UpcomingFixtureWidget> {
  Future<List<Fixture>>? _fixturesFuture;
  final ApiService _apiService = ApiService();
  late FixtureFilters _filters;
  bool _isCompactView = false;
  
  List<Fixture> _allFixtures = [];

  // --- NEW STATE FOR FILTERS ---
  List<String> _allPossibleSports = [];
  Map<String, List<String>> _allPossibleTeamsBySport = {};
  bool _areFiltersLoading = true;
  // -----------------------------


  @override
  void initState() {
    super.initState();
    _loadFilterData();
    _resetFiltersAndFetch();
  }

  // --- NEW METHOD to pre-load all possible filter options ---
  void _loadFilterData() async {
    setState(() {
      _areFiltersLoading = true;
    });

    // Get all sports associated with the school
    final sports = await _apiService.getSportsForSacredHeart();
    _allPossibleSports = sports.map((s) => s.name).toList()..sort();

    // Fetch all teams for all sports in parallel for efficiency
    final teamsFutures = _allPossibleSports.map((sportName) {
      return _apiService.getTeamsForSport(sportName);
    }).toList();

    final teamsResults = await Future.wait(teamsFutures);

    // Populate the map for easy lookup in the filter dialog
    for (int i = 0; i < _allPossibleSports.length; i++) {
      _allPossibleTeamsBySport[_allPossibleSports[i]] = teamsResults[i];
    }

    if (mounted) {
      setState(() {
        _areFiltersLoading = false;
      });
    }
  }
  // ---------------------------------------------------------

  @override
  void didUpdateWidget(UpcomingFixtureWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isResultsView != oldWidget.isResultsView) {
      _resetFiltersAndFetch();
    }
  }

  void _resetFiltersAndFetch() {
    setState(() {
      if (widget.isResultsView) {
        _filters = FixtureFilters(
          dateRange: DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 60)),
            end: DateTime.now(),
          ),
        );
      } else {
        _filters = FixtureFilters(
          dateRange: DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now().add(const Duration(days: 7)),
          ),
        );
      }
      _fetchFixtures();
    });
  }


  void _fetchFixtures() {
    setState(() {
      _fixturesFuture = _apiService.getFixtures(dateRange: _filters.dateRange);
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            
            // Get the list of teams based on the currently selected sport in the filter.
            final sacredHeartTeams = _filters.sport == null
                ? <String>[] // If no sport is selected, the team list is empty.
                : _allPossibleTeamsBySport[_filters.sport] ?? [];

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
                          _filters.team = null; // Reset team when sport changes
                        });
                      },
                      // Populate dropdown with all possible sports
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Sports')),
                        ..._allPossibleSports.map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
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
                      // Populate dropdown with teams for the selected sport
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('All Teams')),
                        ...sacredHeartTeams.map((t) => DropdownMenuItem<String>(value: t, child: Text(t)))
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Date Range'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            child: Text(_filters.dateRange?.start == null ? 'Start Date' : DateFormat.yMd().format(_filters.dateRange!.start)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _filters.dateRange?.start ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  final end = _filters.dateRange?.end ?? picked.add(const Duration(days: 7));
                                  _filters.dateRange = DateTimeRange(
                                    start: picked, 
                                    end: picked.isAfter(end) ? picked : end
                                  );
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
                                firstDate: _filters.dateRange?.start ?? DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  final start = _filters.dateRange?.start ?? picked.subtract(const Duration(days: 7));
                                  _filters.dateRange = DateTimeRange(start: start, end: picked);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    )               
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _resetFiltersAndFetch();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Reset'),
                ),
                TextButton(
                  onPressed: () {
                    _fetchFixtures(); 
                    setState((){});
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
                onPressed: _areFiltersLoading ? null : _showFilterDialog,
                tooltip: _areFiltersLoading ? 'Loading filters...' : 'Filter Fixtures',
              ),
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
                return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Failed to load data.\nError: ${snapshot.error}', textAlign: TextAlign.center)));
              }
              
              _allFixtures = snapshot.data ?? [];
              if (_allFixtures.isEmpty) {
                return const Center(child: Text('No fixtures found for the selected criteria.'));
              }

              final filteredFixtures = _allFixtures.where((f) {
                final premierMatch = _filters.premierStatus == PremierStatus.all || f.premier;
                final sportMatch = _filters.sport == null || f.sport == _filters.sport;
                final teamMatch = _filters.team == null || f.homeTeam == _filters.team || f.awayTeam == _filters.team;
                
                bool locationMatch = true;
                if (f.source == DataSource.collegeSport) {
                    locationMatch = _filters.locationStatus == LocationStatus.all ||
                                (_filters.locationStatus == LocationStatus.home && f.venue.toLowerCase().contains("sacred heart")) ||
                                (_filters.locationStatus == LocationStatus.away && !f.venue.toLowerCase().contains("sacred heart"));
                }
                
                final bool hasScore = (f.homeScore != null && f.homeScore!.isNotEmpty) || (f.awayScore != null && f.awayScore!.isNotEmpty);
                final bool isFinished = hasScore || f.resultStatus != 0;
                final bool viewMatch = widget.isResultsView ? isFinished : !isFinished;

                return premierMatch && sportMatch && teamMatch && locationMatch && viewMatch;
              }).toList();
              
              if (filteredFixtures.isEmpty) {
                 return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No fixtures match the current filters.', textAlign: TextAlign.center)));
              }

              filteredFixtures.sort((a, b) {
                  try {
                    return DateTime.parse(b.dateTime).compareTo(DateTime.parse(a.dateTime));
                  } catch (e) {
                    return 0;
                  }
              });

              return ListView.builder(
                itemCount: filteredFixtures.length,
                itemBuilder: (context, index) {
                  final fixture = filteredFixtures[index];
                  return _isCompactView
                      ? _CompactFixtureCard(fixture: fixture, isResult: widget.isResultsView)
                      : _DetailedFixtureCard(fixture: fixture, isResult: widget.isResultsView);
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
  final bool isResult;
  const _CompactFixtureCard({required this.fixture, required this.isResult});

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
    final bool isCricket = fixture.source == DataSource.playHQ;
    final bool isRugby = fixture.source == DataSource.rugbyUnion;

    // For cricket or rugby, school and team name are the same or combined, so just show team name.
    // For others, show school: team.
    final String homeDisplay = (isCricket || isRugby) ? fixture.homeTeam : '${fixture.homeSchool}: ${fixture.homeTeam}';
    final String awayDisplay = (isCricket || isRugby) ? fixture.awayTeam : '${fixture.awaySchool}: ${fixture.awayTeam}';

    final homeScore = fixture.homeScore ?? '-';
    final awayScore = fixture.awayScore ?? '-';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FixtureDetailScreen(fixture: fixture),
            ),
          );
        },
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
                    Text(
                      '$homeDisplay vs $awayDisplay',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2, // Allow wrapping to a second line
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              isResult
                ? Text(
                    '$homeScore - $awayScore',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  )
                : Text(
                    _formatCompactDateTime(fixture.dateTime),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailedFixtureCard extends StatelessWidget {
  final Fixture fixture;
  final bool isResult;
  const _DetailedFixtureCard({required this.fixture, required this.isResult});

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Date TBC';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('E, d MMM yy, h:mm a').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  Widget _buildTeamDisplay(BuildContext context, {
    required String school,
    required String team,
    required String? logoUrl,
    required CrossAxisAlignment alignment
  }) {
    final bool isCricket = fixture.source == DataSource.playHQ;
    final bool isRugby = fixture.source == DataSource.rugbyUnion;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        if (logoUrl != null && logoUrl.isNotEmpty)
          Image.network(
            logoUrl,
            width: 48,
            height: 48,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 48),
          )
        else
          const Icon(Icons.shield, size: 48),
        const SizedBox(height: 8),
        if (!isCricket && !isRugby)
          Text(
            school,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: alignment == CrossAxisAlignment.start ? TextAlign.left : TextAlign.right,
          ),
        if (!isCricket && !isRugby) const SizedBox(height: 2),
        Text(
          team,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: alignment == CrossAxisAlignment.start ? TextAlign.left : TextAlign.right,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeScore = fixture.homeScore ?? '-';
    final awayScore = fixture.awayScore ?? '-';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FixtureDetailScreen(fixture: fixture),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(fixture.sport, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(fixture.competition, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center,),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTeamDisplay(
                      context,
                      school: fixture.homeSchool,
                      team: fixture.homeTeam,
                      logoUrl: fixture.homeOrgLogo,
                      alignment: CrossAxisAlignment.start,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                    child: isResult 
                      ? Text("$homeScore - $awayScore", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))
                      : Text("vs", style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  Expanded(
                    child: _buildTeamDisplay(
                      context,
                      school: fixture.awaySchool,
                      team: fixture.awayTeam,
                      logoUrl: fixture.awayOrgLogo,
                      alignment: CrossAxisAlignment.end,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(_formatDateTime(fixture.dateTime)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Flexible(child: Text(fixture.venue, textAlign: TextAlign.center)),
                ],
              ),
               if (fixture.premier)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
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
      ),
    );
  }
}


extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return this;
      return "${this[0].toUpperCase()}${substring(1)}";
    }
}

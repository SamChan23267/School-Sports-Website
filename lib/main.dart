// lib/main.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'upcoming_fixture_widget.dart';
import 'api_service.dart';
import 'models.dart';
import 'contact_us_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sports Fixtures',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF181A20),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF23272F),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: LandingPage(
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

enum AppView { upcomingFixtures, results, selectTeam }

class LandingPage extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const LandingPage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  AppView _currentView = AppView.upcomingFixtures;

  String get _currentViewTitle {
    switch (_currentView) {
      case AppView.upcomingFixtures:
        return 'Upcoming Fixtures';
      case AppView.results:
        return 'Results';
      case AppView.selectTeam:
        return 'Select Team';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentViewTitle),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactUsPage()),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            child: const Text('Contact Us'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () {},
            child: const Text(
              'Login',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            tooltip: "Toggle dark mode",
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.nightlight_round
                  : Icons.wb_sunny,
            ),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Upcoming Fixtures'),
              selected: _currentView == AppView.upcomingFixtures,
              onTap: () {
                setState(() {
                  _currentView = AppView.upcomingFixtures;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Results'),
              selected: _currentView == AppView.results,
              onTap: () {
                setState(() {
                  _currentView = AppView.results;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_work),
              title: const Text('Select Team'),
              selected: _currentView == AppView.selectTeam,
              onTap: () {
                setState(() {
                  _currentView = AppView.selectTeam;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _buildCurrentView(),
    );
  }

  Widget _buildCurrentView() {
    Widget content;
    switch (_currentView) {
      case AppView.upcomingFixtures:
        content = const UpcomingFixtureWidget(isResultsView: false);
        break;
      case AppView.results:
        content = const UpcomingFixtureWidget(isResultsView: true);
        break;
      case AppView.selectTeam:
        content = const SportsListColumn();
        break;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.15),
              ),
              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}


class SportsListColumn extends StatefulWidget {
  const SportsListColumn({super.key});

  @override
  State<SportsListColumn> createState() => _SportsListColumnState();
}

class _SportsListColumnState extends State<SportsListColumn> {
  final ApiService _apiService = ApiService();
  
  String? _selectedSport;
  String? _selectedTeam;
  Future<List<String>>? _teamsFuture;
  Future<List<Fixture>>? _teamFixturesFuture;
  Future<List<StandingsTable>>? _standingsFuture;

  int _selectedTabIndex = 0;
  final PageController _pageController = PageController();

  void _onSportSelected(String sportName) {
    setState(() {
      _selectedSport = sportName;
      _teamsFuture = _apiService.getTeamsForSport(sportName);
    });
  }

  void _onTeamSelected(String teamName) {
    setState(() {
      _selectedTeam = teamName;
      _teamFixturesFuture = _apiService.getFixturesForTeam(teamName);
      
      _standingsFuture = _teamFixturesFuture!.then((fixtures) {
        if (fixtures.isNotEmpty) {
          final firstFixture = fixtures.first;
          final competitionId = firstFixture.competitionId;
          final gradeId = firstFixture.gradeId;
          final source = firstFixture.source;
          
          return _apiService.getStandings(competitionId, gradeId ?? 0, source);
        } else {
          return <StandingsTable>[];
        }
      });
    });
  }

  void _onBackToTeams() {
    setState(() {
      _selectedTeam = null;
      _teamFixturesFuture = null;
      _standingsFuture = null;
    });
  }

  void _onBackToSports() {
    setState(() {
      _selectedSport = null;
      _selectedTeam = null;
      _teamsFuture = null;
      _teamFixturesFuture = null;
      _standingsFuture = null;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    if (_selectedSport == null) {
      return Text(
        "Sports",
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    } else if (_selectedTeam == null) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBackToSports,
            tooltip: "Back to Sports",
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedSport!,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBackToTeams,
            tooltip: "Back to Teams",
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedTeam!,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildContent() {
    if (_selectedSport == null) {
      return _buildSportsList();
    } else if (_selectedTeam == null) {
      return _buildTeamsList();
    } else {
      return _buildTeamDetails();
    }
  }

  Widget _buildSportsList() {
    return FutureBuilder<List<Sport>>(
      future: _apiService.getSportsForSacredHeart(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No sports found.'));
        }

        final sports = snapshot.data!;
        return ListView.builder(
          itemCount: sports.length,
          itemBuilder: (context, index) {
            final sport = sports[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 0,
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withOpacity(0.8),
              child: ListTile(
                leading: Text(
                  sport.icon,
                  style: const TextStyle(fontSize: 32),
                ),
                title: Text(
                  sport.name,
                  style: const TextStyle(fontSize: 18),
                ),
                onTap: () => _onSportSelected(sport.name),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamsList() {
    return FutureBuilder<List<String>>(
      future: _teamsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No teams found for this sport.'));
        }

        final teams = snapshot.data!;
        return ListView.builder(
          itemCount: teams.length,
          itemBuilder: (context, index) {
            final teamName = teams[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _onTeamSelected(teamName),
                child: Text(teamName, textAlign: TextAlign.center),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildTeamDetails() {
    return Column(
      children: [
        ToggleButtons(
          isSelected: [_selectedTabIndex == 0, _selectedTabIndex == 1],
          onPressed: (index) {
            setState(() {
              _selectedTabIndex = index;
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          },
          borderRadius: BorderRadius.circular(8),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Text('Fixtures & Results'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Text('Standings'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            children: [
              _buildFixturesContent(),
              _buildStandingsContent(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFixturesContent() {
    return FutureBuilder<List<Fixture>>(
      future: _teamFixturesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No fixtures found.'));
        }

        final fixtures = snapshot.data!;
        return ListView.builder(
          itemCount: fixtures.length,
          itemBuilder: (context, index) {
            return _FixtureResultCard(fixture: fixtures[index]);
          },
        );
      },
    );
  }

  Widget _buildStandingsContent() {
    return FutureBuilder<List<StandingsTable>>(
      future: _standingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Could not load standings data.\nPlease check the network connection and try again.\n\nError: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No standings available.'));
        }

        final tables = snapshot.data!;
        return ListView.builder(
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        table.sectionName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 35,
                        dataRowMaxHeight: 40,
                        columns: const [
                          DataColumn(label: Text('Team')),
                          DataColumn(label: Text('P'), numeric: true),
                          DataColumn(label: Text('W'), numeric: true),
                          DataColumn(label: Text('L'), numeric: true),
                          DataColumn(label: Text('D'), numeric: true),
                          DataColumn(label: Text('B'), numeric: true),
                          DataColumn(label: Text('BP'), numeric: true),
                          DataColumn(label: Text('PF'), numeric: true),
                          DataColumn(label: Text('PA'), numeric: true),
                          DataColumn(label: Text('GD'), numeric: true),
                          DataColumn(label: Text('Pts'), numeric: true),
                        ],
                        rows: table.standings.map((s) => DataRow(cells: [
                          DataCell(Text(s.teamName)), 
                          DataCell(Text(s.played.toString())),
                          DataCell(Text(s.win.toString())),
                          DataCell(Text(s.loss.toString())),
                          DataCell(Text(s.draw.toString())),
                          DataCell(Text(s.byes.toString())),
                          DataCell(Text(s.bonus.toString())),
                          DataCell(Text(s.pointsFor.toString())),
                          DataCell(Text(s.pointsAgainst.toString())),
                          DataCell(Text(s.differential.toString())),
                          DataCell(Text(s.total.toString())),
                        ])).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


class _FixtureResultCard extends StatelessWidget {
  final Fixture fixture;
  const _FixtureResultCard({required this.fixture});

  Widget _buildTeamDisplay(BuildContext context, String school, String team, {required CrossAxisAlignment alignment}) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          school,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: alignment == CrossAxisAlignment.start ? TextAlign.left : TextAlign.right,
        ),
        const SizedBox(height: 2),
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
    final bool hasScore = (fixture.homeScore != null && fixture.homeScore!.isNotEmpty) || 
                          (fixture.awayScore != null && fixture.awayScore!.isNotEmpty);
    final bool isFinished = hasScore || fixture.resultStatus != 0;

    final homeScore = fixture.homeScore ?? '';
    final awayScore = fixture.awayScore ?? '';
    final scoreColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEE, d MMM yy - hh:mm a').format(DateTime.parse(fixture.dateTime)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildTeamDisplay(
                    context,
                    fixture.homeSchool,
                    fixture.homeTeam,
                    alignment: CrossAxisAlignment.start,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: isFinished 
                    ? Text(
                        '$homeScore - $awayScore',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: scoreColor),
                      )
                    : Text(
                        'vs',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
                      ),
                ),
                Expanded(
                  child: _buildTeamDisplay(
                    context,
                    fixture.awaySchool,
                    fixture.awayTeam,
                    alignment: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    fixture.venue,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

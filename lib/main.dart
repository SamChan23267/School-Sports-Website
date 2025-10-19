// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'upcoming_fixture_widget.dart';
import 'contact_us_page.dart';
import 'login_page.dart';
import 'admin_page.dart';
import 'teacher_panel_page.dart';
import 'user_settings_page.dart';
import 'services/api_service.dart';
import 'models.dart';
import 'providers/user_provider.dart';
import 'services/firestore_service.dart';
import 'classroom_teams_page.dart';
import 'followed_teams_page.dart';
import 'services/auth_service.dart';
import 'calendar_page.dart';
import 'my_calendar_page.dart';
import 'dashboard_page.dart'; // Import the new dashboard page

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        Provider(create: (context) => FirestoreService()),
        Provider(create: (context) => AuthService.instance),
        Provider(create: (context) => ApiService()),
      ],
      child: const MyApp(),
    ),
  );
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
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: FutureBuilder(
        future: Provider.of<UserProvider>(context, listen: false)
            .onInitializationComplete,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          return LandingPage(
            themeMode: _themeMode,
            onToggleTheme: _toggleTheme,
          );
        },
      ),
    );
  }
}

enum AppView {
  dashboard, // New view for the dashboard
  upcomingFixtures,
  results,
  selectTeam,
  classroomTeams,
  followedTeams,
  calendar,
  myCalendar,
}

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
  AppView? _currentView;
  Map<String, String>? _selectTeamParams;
  bool? _wasLoggedIn; // Tracks login state changes

  void _navigateTo(AppView view, {Map<String, String>? params}) {
    setState(() {
      _currentView = view;
      _selectTeamParams = params;
    });
  }

  void _showJoinTeamDialog() {
    final firestoreService = context.read<FirestoreService>();
    final userModel = context.read<UserProvider>().userModel;
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Join a Team'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Enter Join Code'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a code' : null,
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate() && userModel != null) {
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);
                    final code = codeController.text;

                    try {
                      final teamName = await firestoreService.joinTeamWithCode(
                          code: code, userId: userModel.uid);
                      navigator.pop();
                      messenger.showSnackBar(SnackBar(
                        content: Text('Successfully joined $teamName!'),
                        backgroundColor: Colors.green,
                      ));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                            'Error: ${e.toString().replaceAll("Exception: ", "")}'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  }
                },
                child: const Text('Join'),
              ),
            ],
          );
        });
  }

  String _getCurrentViewTitle(AppView view) {
    switch (view) {
      case AppView.dashboard:
        return 'Dashboard';
      case AppView.upcomingFixtures:
        return 'Upcoming Fixtures';
      case AppView.results:
        return 'Results';
      case AppView.selectTeam:
        return _selectTeamParams?['team'] ?? 'Select a Team';
      case AppView.classroomTeams:
        return 'My Classroom Teams';
      case AppView.followedTeams:
        return 'Followed Teams';
      case AppView.calendar:
        return 'Fixtures Calendar';
      case AppView.myCalendar:
        return 'My Calendar';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final userModel = userProvider.userModel;
        final isLoggedIn = userModel != null;

        // Initialize login state tracker on the first build
        _wasLoggedIn ??= isLoggedIn;

        // Check if the login state has changed to reset the view
        if (isLoggedIn != _wasLoggedIn) {
          _currentView =
              isLoggedIn ? AppView.dashboard : AppView.upcomingFixtures;
          _wasLoggedIn = isLoggedIn; // Update the tracker
        } else {
          // If login state hasn't changed, set the initial view only if it's null
          _currentView ??=
              isLoggedIn ? AppView.dashboard : AppView.upcomingFixtures;
        }

        final currentView = _currentView!;

        return Scaffold(
          appBar: AppBar(
            title: Text(_getCurrentViewTitle(currentView)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ContactUsPage()),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).appBarTheme.foregroundColor,
                ),
                child: const Text('Contact Us'),
              ),
              const SizedBox(width: 8),
              if (userModel != null)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'logout') {
                      // The provider will notify listeners, and the logic above will handle the view change.
                      Provider.of<UserProvider>(context, listen: false)
                          .signOut();
                    } else if (value == 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserSettingsPage(
                            themeMode: widget.themeMode,
                            onToggleTheme: widget.onToggleTheme,
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(userModel.photoURL),
                            radius: 15,
                            child: userModel.photoURL.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(userModel.displayName),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'settings',
                      child: Text('Settings'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Text('Logout'),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(userModel.photoURL),
                      radius: 18,
                      child: userModel.photoURL.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                  ),
                )
              else
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).appBarTheme.foregroundColor,
                    side: BorderSide(
                        color:
                            Theme.of(context).appBarTheme.foregroundColor ??
                                Theme.of(context).colorScheme.onPrimary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
                  child: const Text('Login',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                  child: Text('Menu',
                      style:
                          Theme.of(context).primaryTextTheme.headlineMedium),
                ),
                if (userModel != null) ...[
                  ListTile(
                    leading: const Icon(Icons.dashboard),
                    title: const Text('Dashboard'),
                    selected: currentView == AppView.dashboard,
                    onTap: () {
                      _navigateTo(AppView.dashboard);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                ],
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Upcoming Fixtures'),
                  selected: currentView == AppView.upcomingFixtures,
                  onTap: () {
                    _navigateTo(AppView.upcomingFixtures);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.emoji_events),
                  title: const Text('Results'),
                  selected: currentView == AppView.results,
                  onTap: () {
                    _navigateTo(AppView.results);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Calendar'),
                  selected: currentView == AppView.calendar,
                  onTap: () {
                    _navigateTo(AppView.calendar);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group_work),
                  title: const Text('Select Team'),
                  selected: currentView == AppView.selectTeam,
                  onTap: () {
                    _navigateTo(AppView.selectTeam);
                    Navigator.pop(context);
                  },
                ),
                if (userModel != null) const Divider(),
                if (userModel != null)
                  ListTile(
                    leading: const Icon(Icons.person_pin_circle_outlined),
                    title: const Text('My Calendar'),
                    selected: currentView == AppView.myCalendar,
                    onTap: () {
                      _navigateTo(AppView.myCalendar);
                      Navigator.pop(context);
                    },
                  ),
                if (userModel != null)
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text('My Classroom Teams'),
                    selected: currentView == AppView.classroomTeams,
                    onTap: () {
                      _navigateTo(AppView.classroomTeams);
                      Navigator.pop(context);
                    },
                  ),
                if (userModel != null)
                  ListTile(
                    leading: const Icon(Icons.star),
                    title: const Text('Followed Teams'),
                    selected: currentView == AppView.followedTeams,
                    onTap: () {
                      _navigateTo(AppView.followedTeams);
                      Navigator.pop(context);
                    },
                  ),
                const Divider(),
                if (userModel != null &&
                    (userModel.appRole == 'admin' ||
                        userModel.appRole == 'teacher'))
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Teacher Panel'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const TeacherPanelPage()),
                      );
                    },
                  ),
                if (userModel != null && userModel.appRole == 'admin')
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Admin Panel'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AdminPage()),
                      );
                    },
                  ),
              ],
            ),
          ),
          body: _buildCurrentView(currentView, userProvider),
          floatingActionButton: _buildFloatingActionButton(currentView),
        );
      },
    );
  }

  Widget? _buildFloatingActionButton(AppView currentView) {
    if (currentView == AppView.classroomTeams) {
      return FloatingActionButton(
        onPressed: _showJoinTeamDialog,
        tooltip: 'Join a Team',
        child: const Icon(Icons.group_add),
      );
    }
    return null;
  }

  Widget _buildCurrentView(AppView currentView, UserProvider userProvider) {
    Widget content;
    switch (currentView) {
      case AppView.dashboard:
        content = DashboardPage(onNavigate: _navigateTo);
        break;
      case AppView.upcomingFixtures:
        content = const UpcomingFixtureWidget(isResultsView: false);
        break;
      case AppView.results:
        content = const UpcomingFixtureWidget(isResultsView: true);
        break;
      case AppView.selectTeam:
        content = SportsListColumn(
          initialSport: _selectTeamParams?['sport'],
          initialTeam: _selectTeamParams?['team'],
        );
        break;
      case AppView.classroomTeams:
        content = userProvider.userModel != null
            ? const ClassroomTeamsPage()
            : const Center(
                child: Text("Please log in to see your teams."),
              );
        break;
      case AppView.followedTeams:
        content = userProvider.userModel != null
            ? FollowedTeamsPage(
                onTeamSelected: (sport, team) {
                  _navigateTo(AppView.selectTeam,
                      params: {'sport': sport, 'team': team});
                },
              )
            : const Center(
                child: Text("Please log in to see your followed teams."),
              );
        break;
      case AppView.calendar:
        content = const CalendarPage();
        break;
      case AppView.myCalendar:
        content = const MyCalendarPage();
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
  final String? initialSport;
  final String? initialTeam;
  const SportsListColumn({super.key, this.initialSport, this.initialTeam});

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

  @override
  void initState() {
    super.initState();
    if (widget.initialSport != null) {
      _onSportSelected(widget.initialSport!);
      if (widget.initialTeam != null) {
        _onTeamSelected(widget.initialTeam!, widget.initialSport!);
      }
    }
  }

  void _onSportSelected(String sportName) {
    setState(() {
      _selectedSport = sportName;
      _teamsFuture = _apiService.getTeamsForSport(sportName);
    });
  }

  void _onTeamSelected(String teamName, String sportName) {
    setState(() {
      _selectedTeam = teamName;
      _teamFixturesFuture = _apiService.getFixturesForTeam(teamName, sportName);
      _standingsFuture = _teamFixturesFuture!.then((fixtures) async {
        if (fixtures.isEmpty) return <StandingsTable>[];
        final fixtureForStandings = fixtures.first;
        try {
          return await _apiService.getStandings(
              fixtureForStandings.competitionId,
              fixtureForStandings.gradeId ?? 0,
              fixtureForStandings.source);
        } catch (e) {
          print("Error getting standings: $e");
          return [];
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
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildHeader() {
    if (_selectedSport == null) {
      return Text("Sports", style: Theme.of(context).textTheme.headlineMedium);
    } else if (_selectedTeam == null) {
      return Row(children: [
        IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: _onBackToSports),
        Expanded(
            child: Text(_selectedSport!,
                style: Theme.of(context).textTheme.headlineMedium)),
      ]);
    } else {
      return Row(children: [
        IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: _onBackToTeams),
        Expanded(
            child: Text(_selectedTeam!,
                style: Theme.of(context).textTheme.headlineMedium)),
      ]);
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
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(child: Text('No sports found.'));

        final sports = snapshot.data!;
        return ListView.builder(
          itemCount: sports.length,
          itemBuilder: (context, index) {
            final sport = sports[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: Text(sport.icon, style: const TextStyle(fontSize: 32)),
                title: Text(sport.name, style: const TextStyle(fontSize: 18)),
                onTap: () => _onSportSelected(sport.name),
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
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(child: Text('No teams found.'));

        final teams = snapshot.data!;
        return ListView.builder(
          itemCount: teams.length,
          itemBuilder: (context, index) {
            final teamName = teams[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: ElevatedButton(
                onPressed: () => _onTeamSelected(teamName, _selectedSport!),
                child: Text(teamName),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamDetails() {
    final userProvider = context.watch<UserProvider>();
    final userModel = userProvider.userModel;

    final uniqueTeamId = '${_selectedSport!}::${_selectedTeam!}';
    final isFollowed = userModel?.followedTeams.contains(uniqueTeamId) ?? false;

    return Column(
      children: [
        if (userModel != null)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                final firestoreService = context.read<FirestoreService>();
                if (isFollowed) {
                  firestoreService.unfollowTeam(
                      userModel.uid, _selectedSport!, _selectedTeam!);
                } else {
                  firestoreService.followTeam(
                      userModel.uid, _selectedSport!, _selectedTeam!);
                }
              },
              icon: Icon(isFollowed ? Icons.star : Icons.star_border,
                  color: isFollowed ? Colors.amber : null),
              label: Text(isFollowed ? 'Following' : 'Follow'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowed
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
              ),
            ),
          ),
        const SizedBox(height: 16),
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
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Fixtures & Results')),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Standings')),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) =>
                setState(() => _selectedTabIndex = index),
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
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(child: Text('No fixtures found.'));

        final fixtures = snapshot.data!;
        return ListView.builder(
          itemCount: fixtures.length,
          itemBuilder: (context, index) =>
              _FixtureResultCard(fixture: fixtures[index]),
        );
      },
    );
  }

  Widget _buildStandingsContent() {
    return FutureBuilder<List<StandingsTable>>(
      future: _standingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
              child: Text('Could not load standings: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(child: Text('No standings available.'));

        final tables = snapshot.data!;
        return ListView.builder(
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Team')),
                    DataColumn(label: Text('P')),
                    DataColumn(label: Text('W')),
                    DataColumn(label: Text('L')),
                    DataColumn(label: Text('D')),
                    DataColumn(label: Text('Pts')),
                  ],
                  rows: table.standings
                      .map((s) => DataRow(cells: [
                            DataCell(Text(s.teamName)),
                            DataCell(Text(s.played.toString())),
                            DataCell(Text(s.win.toString())),
                            DataCell(Text(s.loss.toString())),
                            DataCell(Text(s.draw.toString())),
                            DataCell(Text(s.total.toString())),
                          ]))
                      .toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TeamDisplay extends StatelessWidget {
  final String school;
  final String team;
  final bool isCricket;
  final CrossAxisAlignment alignment;

  const _TeamDisplay({
    required this.school,
    required this.team,
    required this.isCricket,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        if (!isCricket)
          Text(
            school,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: alignment == CrossAxisAlignment.start
                ? TextAlign.left
                : TextAlign.right,
          ),
        if (!isCricket) const SizedBox(height: 2),
        Text(
          team,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: alignment == CrossAxisAlignment.start
              ? TextAlign.left
              : TextAlign.right,
        ),
      ],
    );
  }
}

class _FixtureResultCard extends StatelessWidget {
  final Fixture fixture;
  const _FixtureResultCard({required this.fixture});

  @override
  Widget build(BuildContext context) {
    final bool hasScore =
        (fixture.homeScore != null && fixture.homeScore!.isNotEmpty) ||
            (fixture.awayScore != null && fixture.awayScore!.isNotEmpty);
    final bool isFinished = hasScore || fixture.resultStatus != 0;

    final homeScore = fixture.homeScore ?? '';
    final awayScore = fixture.awayScore ?? '';
    final scoreColor = Theme.of(context).colorScheme.primary;
    final bool isCricket = fixture.source == DataSource.playHQ;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEE, d MMM yy - hh:mm a')
                  .format(DateTime.parse(fixture.dateTime)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _TeamDisplay(
                    school: fixture.homeSchool,
                    team: fixture.homeTeam,
                    isCricket: isCricket,
                    alignment: CrossAxisAlignment.start,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: isFinished
                      ? Text(
                          '$homeScore - $awayScore',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scoreColor),
                        )
                      : Text(
                          'vs',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.grey),
                        ),
                ),
                Expanded(
                  child: _TeamDisplay(
                    school: fixture.awaySchool,
                    team: fixture.awayTeam,
                    isCricket: isCricket,
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


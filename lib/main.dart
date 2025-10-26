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

// Define the SHC Branding Colors from the PDF
const Color kShcDarkBlue = Color(0xFF184287); // PMS 280
const Color kShcLightBlue = Color(0xFF86C1EA); // PMS 283
const Color kShcRed = Color(0xFFE30613); // PMS 485

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
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark mode as per shc branch

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHC Sports', // Updated title slightly
      debugShowCheckedModeBanner: false,
      theme: ThemeData( // Light Theme
        colorScheme: ColorScheme.fromSeed(
            seedColor: kShcDarkBlue, brightness: Brightness.light),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          // Explicitly set a dark foreground for the light theme's AppBar
          foregroundColor: Colors.black87, // Use a dark color for text/icons
          // Use the primary color generated from the seed for the background
          // backgroundColor: kShcDarkBlue, // Optional: Force specific background
          // Ensure title text also uses the foreground color
          titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w500),
          // Ensure icons also use the foreground color
          iconTheme: IconThemeData(color: Colors.black87),
          actionsIconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      darkTheme: ThemeData( // Dark Theme
        colorScheme: ColorScheme.fromSeed(
            seedColor: kShcDarkBlue, brightness: Brightness.dark),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          // Ensure AppBar text/icons are white against the dark theme's AppBar background
          foregroundColor: Colors.white,
          // Ensure title text also uses the foreground color
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
           // Ensure icons also use the foreground color
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
        ),
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

// --- Widget for the Branding Stripe ---
class _BrandingStripe extends StatelessWidget implements PreferredSizeWidget {
  final double height;

  const _BrandingStripe({this.height = 8.0}); // Updated height to 8.0

  @override
  Widget build(BuildContext context) {
    // Calculate the left padding as a percentage of screen width, similar to the website's 8%
    final double screenWidth = MediaQuery.of(context).size.width;
    final double leftPadding = screenWidth * 0.08;

    // Implemented the specific layout provided by the user
    return Container(
      height: height,
      color: kShcDarkBlue, // Dark blue background of the line
      padding: EdgeInsets.only(left: leftPadding),
      child: Row(
        children: [
          Container(
            width: 40,
            color: kShcRed, // Red part
          ),
          Container(
            width: 106,
            color: kShcLightBlue, // Light blue part
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}
// ------------------------------------------


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

        // No need to manually calculate foreground color here, rely on AppBarTheme
        // final appBarForegroundColor = ... ;


        return Scaffold(
          appBar: AppBar(
              // foregroundColor is now handled by AppBarTheme
              title: Text(_getCurrentViewTitle(currentView)),
              // --- Add the branding stripe below the AppBar ---
              bottom: const _BrandingStripe(), // Using the updated widget
              // -----------------------------------------------
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ContactUsPage()),
                    );
                  },
                  // Style automatically comes from AppBarTheme's foregroundColor
                  // style: TextButton.styleFrom(
                  //   foregroundColor: appBarForegroundColor,
                  // ),
                  child: const Text('Contact Us'),
                ),
                const SizedBox(width: 8),
                if (userModel != null)
                  PopupMenuButton<String>(
                      // iconColor automatically comes from AppBarTheme
                      // iconColor: appBarForegroundColor,
                      onSelected: (value) {
                        if (value == 'logout') {
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
                      // Style automatically comes from AppBarTheme
                      // style: OutlinedButton.styleFrom(
                      //   foregroundColor: appBarForegroundColor,
                      //   side: BorderSide(color: appBarForegroundColor),
                      //   shape: RoundedRectangleBorder(
                      //       borderRadius: BorderRadius.circular(18)),
                      // ),
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
                  // color automatically comes from AppBarTheme
                  // color: appBarForegroundColor,
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
                          Theme.of(context).primaryTextTheme.headlineMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary // Ensure text is visible
                          )),
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
    // Updated container styling to better match the branding branch example
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Reduced padding slightly
          child: Container(
             padding: const EdgeInsets.all(16.0), // Keep internal padding
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12), // Slightly smaller radius
               // Use surfaceVariant for a subtle background difference
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2), // Softer border
              ),
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
      // Reset team selection when sport changes
      _selectedTeam = null;
      _teamFixturesFuture = null;
      _standingsFuture = null;
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
      // Reset tab index when a new team is selected
      _selectedTabIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
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
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200, // Adjust size as needed
            childAspectRatio: 2.5, // Adjust aspect ratio for button shape
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: sports.length,
          itemBuilder: (context, index) {
            final sport = sports[index];
            return ElevatedButton.icon(
              icon: Text(sport.icon, style: const TextStyle(fontSize: 24)), // Larger icon
              label: Text(sport.name, textAlign: TextAlign.center),
              onPressed: () => _onSportSelected(sport.name),
              style: ElevatedButton.styleFrom(
                // Use secondary container for background
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                // Use onSecondaryContainer for text/icon
                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8), // Adjust padding
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
        // Using GridView for teams as well
         return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250, // Slightly larger for team names
            childAspectRatio: 3.5, // Adjust aspect ratio
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: teams.length,
          itemBuilder: (context, index) {
            final teamName = teams[index];
            return ElevatedButton(
              onPressed: () => _onTeamSelected(teamName, _selectedSport!),
              style: ElevatedButton.styleFrom(
                // Use tertiary container for team buttons
                backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                // Use onTertiaryContainer for text
                foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Adjust padding
              ),
              child: Text(teamName, textAlign: TextAlign.center),
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
                // Style the follow button based on state
                backgroundColor: isFollowed
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant,
                foregroundColor: isFollowed
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Using SegmentedButton for tabs - a Material 3 component
        SegmentedButton<int>(
          segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 0, label: Text('Fixtures'), icon: Icon(Icons.list)),
              ButtonSegment<int>(value: 1, label: Text('Standings'), icon: Icon(Icons.leaderboard)),
          ],
          selected: <int>{_selectedTabIndex},
          onSelectionChanged: (Set<int> newSelection) {
            setState(() {
              _selectedTabIndex = newSelection.first;
              _pageController.animateToPage(
                _selectedTabIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          },
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
        // Sort fixtures: upcoming ascending, results descending
        fixtures.sort((a, b) {
          try {
            final dateA = DateTime.parse(a.dateTime);
            final dateB = DateTime.parse(b.dateTime);
            final bool isFinishedA = (a.homeScore != null && a.homeScore!.isNotEmpty) || (a.awayScore != null && a.awayScore!.isNotEmpty) || a.resultStatus != 0;
            final bool isFinishedB = (b.homeScore != null && b.homeScore!.isNotEmpty) || (b.awayScore != null && b.awayScore!.isNotEmpty) || b.resultStatus != 0;

            if (isFinishedA && !isFinishedB) return 1; // Finished games come after upcoming
            if (!isFinishedA && isFinishedB) return -1; // Upcoming games come before finished
            if (isFinishedA && isFinishedB) return dateB.compareTo(dateA); // Sort finished descending
            return dateA.compareTo(dateB); // Sort upcoming ascending
          } catch (e) {
            return 0; // Keep original order if dates are invalid
          }
        });

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
        // Display standings in Cards
        return ListView.builder(
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                  padding: const EdgeInsets.all(8.0), // Add padding inside card
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      if (table.sectionName != 'Standings') // Show section name if available
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(table.sectionName, style: Theme.of(context).textTheme.titleMedium),
                      ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        // Make columns more compact
                        columnSpacing: 12.0,
                        headingTextStyle: Theme.of(context).textTheme.labelSmall,
                        dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                        columns: const [
                          // Previous columns...
                          DataColumn(label: Text('Pos'), numeric: true),
                          DataColumn(label: Text('Team')),
                          DataColumn(label: Text('P'), numeric: true),
                          DataColumn(label: Text('W'), numeric: true),
                          DataColumn(label: Text('L'), numeric: true),
                          DataColumn(label: Text('D'), numeric: true),
                          // --- FIX: Add GF, GA, GD Columns ---
                          DataColumn(label: Text('GF'), numeric: true),
                          DataColumn(label: Text('GA'), numeric: true),
                          DataColumn(label: Text('GD'), numeric: true),
                          // --- END FIX ---
                          DataColumn(label: Text('Pts'), numeric: true),
                        ],
                        rows: table.standings
                            .map((s) => DataRow(cells: [
                                  // Previous cells...
                                  DataCell(Text(s.position.toString())),
                                  DataCell(Text(s.teamName)),
                                  DataCell(Text(s.played.toString())),
                                  DataCell(Text(s.win.toString())),
                                  DataCell(Text(s.loss.toString())),
                                  DataCell(Text(s.draw.toString())),
                                  // --- FIX: Add GF, GA, GD Cells ---
                                  DataCell(Text(s.pointsFor.toString())),
                                  DataCell(Text(s.pointsAgainst.toString())),
                                  DataCell(Text(s.differential.toString())),
                                  // --- END FIX ---
                                  DataCell(Text(s.total.toString())),
                                ]))
                            .toList(),
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
    // Use primary color for scores
    final scoreColor = Theme.of(context).colorScheme.primary;
    final bool isCricket = fixture.source == DataSource.playHQ;

    return Card(
      // Use surfaceVariant for card background
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // Format date more clearly
              DateFormat('EEE, d MMM yy • hh:mm a')
                  .format(DateTime.parse(fixture.dateTime)),
               // Use label small style for date
              style: Theme.of(context).textTheme.labelSmall,
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
                                  color: scoreColor), // Apply score color
                        )
                      : Text(
                          'vs',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Theme.of(context).colorScheme.outline), // Use outline color for 'vs'
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
                 // Use outline color for location icon
                Icon(Icons.location_on, size: 14, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    fixture.venue,
                     // Use label small for venue
                    style: Theme.of(context).textTheme.labelSmall,
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

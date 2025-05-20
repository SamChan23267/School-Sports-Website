import 'package:flutter/material.dart';
import 'upcoming_fixture_widget.dart';

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

class LandingPage extends StatelessWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const LandingPage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).appBarTheme.backgroundColor ??
                  Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title
                Row(
                  children: [
                    Icon(Icons.sports_soccer,
                        color: Theme.of(context).colorScheme.primary, size: 32),
                    const SizedBox(width: 10),
                    Text(
                      'Sports Fixtures',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                // Nav items
                Row(
                  children: [
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      child: const Text('Contact Us'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {},
                      child: const Text(
                        'Login',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Dark/light mode toggle
                    IconButton(
                      tooltip: "Toggle dark mode",
                      icon: Icon(
                        themeMode == ThemeMode.dark
                            ? Icons.nightlight_round
                            : Icons.wb_sunny,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: onToggleTheme,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body content
          Expanded(
            child: Container(
              width: double.infinity,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  children: [
                    // Left: Sports list (card style)
                    Flexible(
                      flex: 2,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(top: 40, right: 24, left: 24),
                        child: Material(
                          elevation: 3,
                          borderRadius: BorderRadius.circular(18),
                          color: Theme.of(context).colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: SportsListColumn(),
                          ),
                        ),
                      ),
                    ),
                    // Right: Future content (empty for now, leave space)
                    Flexible(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 48, horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.15),
                            ),
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withOpacity(0.5),
                          ),
                          child: const UpcomingFixtureWidget(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Sports list column widget
class SportsListColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sortedSports = List<Map<String, dynamic>>.from(mockSports)
      ..sort((a, b) => a['name'].compareTo(b['name']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Sports",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        ...sortedSports.map((sport) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 0,
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withOpacity(0.8),
            child: ListTile(
              leading: Text(
                sport['icon'] ?? '',
                style: const TextStyle(fontSize: 32),
              ),
              title: Text(
                sport['name'],
                style: const TextStyle(fontSize: 18),
              ),
              onTap: () {
                // TODO: Navigate to Teams List Page
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          );
        }),
      ],
    );
  }
}

// Mock data for sports
const List<Map<String, dynamic>> mockSports = [
  {'name': 'Football', 'icon': '⚽'},
  {'name': 'Basketball', 'icon': '🏀'},
  {'name': 'Tennis', 'icon': '🎾'},
  {'name': 'Cricket', 'icon': '🏏'},
  {'name': 'Baseball', 'icon': '⚾'},
  {'name': 'Swimming', 'icon': '🏊‍♂️'},
  {'name': 'Running', 'icon': '🏃‍♂️'},
];

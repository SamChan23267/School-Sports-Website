// lib/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import 'main.dart'; 
import 'models.dart';
import 'models/announcement_model.dart';
import 'models/team_model.dart';
import 'providers/user_provider.dart';
import 'services/api_service.dart';
import 'services/firestore_service.dart';
import 'fixture_detail_screen.dart';
import 'team_detail_page.dart';

class DashboardPage extends StatefulWidget {
  final Function(AppView view, {Map<String, String>? params}) onNavigate;
  const DashboardPage({super.key, required this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<DashboardData>? _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    // We need context to be available, so we load data here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  void _loadDashboardData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    if (userProvider.userModel != null) {
      setState(() {
        _dashboardDataFuture =
            DashboardData.fetch(userProvider, apiService, firestoreService);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().userModel;
    if (user == null) {
      return const Center(child: Text("Please log in to see your dashboard."));
    }

    return FutureBuilder<DashboardData>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text("Error loading dashboard: ${snapshot.error}"),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: Text("Could not load dashboard data."));
        }

        final data = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            _loadDashboardData();
          },
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                'Welcome back, ${user.displayName}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              _NextGameCard(fixture: data.nextFixture),
              const SizedBox(height: 16),
              _LatestResultCard(fixture: data.latestResult),
              const SizedBox(height: 16),
              _LatestAnnouncementCard(
                  announcement: data.latestAnnouncement, team: data.announcementTeam),
              const SizedBox(height: 24),
              _QuickLinks(onNavigate: widget.onNavigate),
            ],
          ),
        );
      },
    );
  }
}

// --- Data Fetching Class ---
class DashboardData {
  final Fixture? nextFixture;
  final Fixture? latestResult;
  final AnnouncementModel? latestAnnouncement;
  final TeamModel? announcementTeam;

  DashboardData({
    this.nextFixture,
    this.latestResult,
    this.latestAnnouncement,
    this.announcementTeam,
  });

  static Future<DashboardData> fetch(UserProvider userProvider,
      ApiService apiService, FirestoreService firestoreService) async {
    final user = userProvider.userModel!;
    final teamIds = user.memberOfTeams;
    final followedTeamNames =
        user.followedTeams.map((e) => e.split('::')[1]).toSet();

    // --- Fetch Fixtures and Results ---
    final allFixtures = await apiService.getFixtures(
      dateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now().add(const Duration(days: 30)),
      ),
    );

    final relevantFixtures = allFixtures.where((f) =>
        followedTeamNames.contains(f.homeTeam) ||
        followedTeamNames.contains(f.awayTeam));

    final upcoming = relevantFixtures
        .where((f) => DateTime.tryParse(f.dateTime)?.isAfter(DateTime.now()) ?? false)
        .toList()
      ..sort((a, b) => DateTime.parse(a.dateTime).compareTo(DateTime.parse(b.dateTime)));

    final results = relevantFixtures
        .where((f) => DateTime.tryParse(f.dateTime)?.isBefore(DateTime.now()) ?? false)
        .toList()
      ..sort((a, b) => DateTime.parse(b.dateTime).compareTo(DateTime.parse(a.dateTime)));

    // --- Fetch Announcements ---
    AnnouncementModel? latestAnnouncement;
    TeamModel? announcementTeam;
    if (teamIds.isNotEmpty) {
      final announcementFutures = teamIds.map((teamId) async {
        final announcements = await firestoreService.getAnnouncementsStream(teamId).first;
        final team = await firestoreService.getTeamById(teamId);
        return announcements.map((a) => MapEntry(a, team)).toList();
      });

      final allAnnouncements = (await Future.wait(announcementFutures)).expand((e) => e).toList();
      
      allAnnouncements.sort((a, b) =>
          b.key.timestamp.compareTo(a.key.timestamp));
      
      if(allAnnouncements.isNotEmpty) {
        latestAnnouncement = allAnnouncements.first.key;
        announcementTeam = allAnnouncements.first.value;
      }
    }

    return DashboardData(
      nextFixture: upcoming.firstOrNull,
      latestResult: results.firstOrNull,
      latestAnnouncement: latestAnnouncement,
      announcementTeam: announcementTeam,
    );
  }
}

// --- Dashboard Cards ---

class _NextGameCard extends StatelessWidget {
  final Fixture? fixture;
  const _NextGameCard({this.fixture});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your Next Game", style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            if (fixture == null)
              const Text("No upcoming games for your followed teams in the next 30 days.")
            else
              _FixtureTile(fixture: fixture!),
          ],
        ),
      ),
    );
  }
}

class _LatestResultCard extends StatelessWidget {
  final Fixture? fixture;
  const _LatestResultCard({this.fixture});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Latest Result", style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            if (fixture == null)
              const Text("No recent results for your followed teams in the last 30 days.")
            else
              _FixtureTile(fixture: fixture!),
          ],
        ),
      ),
    );
  }
}

class _LatestAnnouncementCard extends StatelessWidget {
  final AnnouncementModel? announcement;
  final TeamModel? team;
  const _LatestAnnouncementCard({this.announcement, this.team});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Recent Announcement", style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            if (announcement == null || team == null)
              const Text("No new announcements in your teams.")
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(announcement!.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'From ${team!.teamName} - ${announcement!.content}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                   Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeamDetailPage(
                          team: team!,
                          initialTabIndex: 0, // Go to announcements tab
                        ),
                      ),
                    );
                },
              ),
          ],
        ),
      ),
    );
  }
}


class _QuickLinks extends StatelessWidget {
  final Function(AppView view, {Map<String, String>? params}) onNavigate;
  const _QuickLinks({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Quick Links", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: const Text("My Calendar"),
                onPressed: () => onNavigate(AppView.myCalendar),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.group),
                label: const Text("My Teams"),
                onPressed: () => onNavigate(AppView.classroomTeams),
                 style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


// --- Reusable Fixture Tile for Cards ---
class _FixtureTile extends StatelessWidget {
  final Fixture fixture;
  const _FixtureTile({required this.fixture});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${fixture.homeTeam} vs ${fixture.awayTeam}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fixture.competition),
          const SizedBox(height: 4),
          Text(DateFormat.yMMMEd().add_jm().format(DateTime.parse(fixture.dateTime))),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FixtureDetailScreen(fixture: fixture),
          ),
        );
      },
    );
  }
}


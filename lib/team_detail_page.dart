// lib/team_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/announcement_model.dart';
import '../models/event_model.dart';
import '../models/team_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import 'team_settings_page.dart';

class TeamDetailPage extends StatefulWidget {
  final TeamModel team;

  const TeamDetailPage({super.key, required this.team});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userModel = context.watch<UserProvider>().userModel;
    if (userModel == null) {
      return const Scaffold(
          body: Center(child: Text("Please log in to view team details.")));
    }

    final userTeamRole = widget.team.members[userModel.uid] ?? 'member';
    final canManage = userTeamRole == 'owner' || userTeamRole == 'headCoach';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.teamName),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Team Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamSettingsPage(team: widget.team),
                  ),
                );
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.announcement), text: 'Announcements'),
            Tab(icon: Icon(Icons.event), text: 'Events'),
            Tab(icon: Icon(Icons.photo_library), text: 'Gallery'),
            Tab(icon: Icon(Icons.people), text: 'Roster'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AnnouncementsTab(team: widget.team, canManage: canManage),
          _EventsTab(team: widget.team, canManage: canManage),
          const _FeatureComingSoonTab(featureName: 'Gallery'),
          _RosterTab(team: widget.team, canManage: canManage),
        ],
      ),
    );
  }
}

// --- Announcements Tab ---
class _AnnouncementsTab extends StatelessWidget {
  final TeamModel team;
  final bool canManage;
  const _AnnouncementsTab({required this.team, required this.canManage});

  void _showPostAnnouncementDialog(BuildContext context) {
    final userModel = context.read<UserProvider>().userModel;
    if (userModel == null) return;

    final contentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Announcement'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: contentController,
            decoration: const InputDecoration(labelText: 'Message'),
            maxLines: 4,
            validator: (value) =>
                value!.isEmpty ? 'Please enter a message' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await context.read<FirestoreService>().postAnnouncement(
                    team.id, userModel, contentController.text);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Post'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<AnnouncementModel>>(
        stream: context.read<FirestoreService>().getAnnouncementsStream(team.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          final announcements = snapshot.data ?? [];
          if (announcements.isEmpty) return const Center(child: Text("No announcements yet."));
          
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  title: Text(announcement.content),
                  subtitle: Text(
                      "Posted by ${announcement.authorName} on ${DateFormat.yMd().add_jm().format(announcement.timestamp.toDate())}"),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _showPostAnnouncementDialog(context),
              tooltip: 'Post Announcement',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// --- Events Tab ---
class _EventsTab extends StatelessWidget {
  final TeamModel team;
  final bool canManage;
  const _EventsTab({required this.team, required this.canManage});

  void _showCreateEventDialog(BuildContext context) {
    // ... Dialog logic to create an event
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<EventModel>>(
        stream: context.read<FirestoreService>().getEventsStream(team.id),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          final events = snapshot.data ?? [];
          if (events.isEmpty) return const Center(child: Text("No upcoming events."));
          
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "On ${DateFormat.yMMMEd().add_jm().format(event.eventDate.toDate())}\n${event.description ?? ''}"),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _showCreateEventDialog(context),
              tooltip: 'Create Event',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// --- Roster Tab ---
class _RosterTab extends StatelessWidget {
  final TeamModel team;
  final bool canManage;
  const _RosterTab({required this.team, required this.canManage});

  void _showAddMemberDialog(BuildContext context) {
    // ... Dialog logic to add a new member by email
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final currentUserId = context.read<UserProvider>().userModel?.uid;

    return Scaffold(
      body: ListView(
        children: team.members.entries.map((entry) {
          final userId = entry.key;
          final role = entry.value;

          return StreamBuilder<UserModel>(
            stream: firestoreService.getUserStream(userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const ListTile();
              final user = snapshot.data!;
              return ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(user.photoURL)),
                title: Text(user.displayName),
                subtitle: Text(user.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(label: Text(role)),
                    if (canManage && user.uid != currentUserId && role != 'owner')
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () async {
                           await firestoreService.removeTeamMember(team.id, user.uid);
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.displayName} removed from team.')));
                        },
                      ),
                  ],
                ),
              );
            },
          );
        }).toList(),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _showAddMemberDialog(context),
              tooltip: 'Add Member',
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }
}


// --- Placeholder Tab ---
class _FeatureComingSoonTab extends StatelessWidget {
  final String featureName;
  const _FeatureComingSoonTab({required this.featureName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '$featureName Feature Coming Soon!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}


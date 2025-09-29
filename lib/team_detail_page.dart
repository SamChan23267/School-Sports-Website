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
    final firestoreService = context.read<FirestoreService>();
    final userModel = context.watch<UserProvider>().userModel;
    
    if (userModel == null) {
      return const Scaffold(
          body: Center(child: Text("Please log in to view team details.")));
    }

    return StreamBuilder<TeamModel>(
      // Listen to live updates for the team
      stream: firestoreService.getTeamStream(widget.team.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(body: Center(child: Text("Error loading team data or team not found.")));
        }
        
        final team = snapshot.data!;

        // Check for membership before showing content
        if (!team.members.containsKey(userModel.uid)) {
          return Scaffold(
            appBar: AppBar(title: const Text("Access Denied")),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "You are not a member of this team and cannot view its details.",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final userTeamRole = team.members[userModel.uid] ?? 'member';
        final canManage = userTeamRole == 'owner' || userTeamRole == 'headCoach';

        return Scaffold(
          appBar: AppBar(
            title: Text(team.teamName), // Use live team name
            actions: [
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Team Settings',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeamSettingsPage(team: team),
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
              _AnnouncementsTab(team: team, canManage: canManage),
              _EventsTab(team: team, canManage: canManage),
              const _FeatureComingSoonTab(featureName: 'Gallery'),
              _RosterTab(team: team, canManage: canManage),
            ],
          ),
        );
      }
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
    final firestoreService = context.read<FirestoreService>();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedRole = 'member';

    showDialog(
      context: context,
      builder: (dialogContext) { // Use a different context name for the dialog
        return AlertDialog(
          title: const Text('Add New Member'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'User Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['member', 'coach', 'manager']
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role[0].toUpperCase() + role.substring(1)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectedRole = value;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final email = emailController.text;
                  
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(dialogContext);

                  navigator.pop(); 

                  final userToAdd = await firestoreService.getUserByEmail(email);

                  if (userToAdd == null) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error: User with email $email not found.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  if (team.members.containsKey(userToAdd.uid)) {
                     messenger.showSnackBar(
                      SnackBar(content: Text('${userToAdd.displayName} is already in the team.'), backgroundColor: Colors.orange),
                    );
                    return;
                  }

                  try {
                    await firestoreService.addTeamMember(team.id, userToAdd.uid, selectedRole);
                    messenger.showSnackBar(
                      SnackBar(content: Text('Successfully added ${userToAdd.displayName} to the team.'), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                     messenger.showSnackBar(
                      SnackBar(content: Text('Failed to add member: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showChangeRoleDialog(BuildContext context, TeamModel team, UserModel member) {
    final firestoreService = context.read<FirestoreService>();
    String selectedRole = team.members[member.uid] ?? 'member';
    final availableRoles = ['member', 'coach', 'manager'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Change Role for ${member.displayName}'),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            decoration: const InputDecoration(labelText: 'Role'),
            items: availableRoles
                .map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role[0].toUpperCase() + role.substring(1)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                selectedRole = value;
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);

                try {
                  await firestoreService.updateTeamMemberRole(team.id, member.uid, selectedRole);
                  messenger.showSnackBar(
                    SnackBar(content: Text('${member.displayName}\'s role updated to $selectedRole.'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to update role: $e'), backgroundColor: Colors.red),
                  );
                }
                navigator.pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
              if (!snapshot.hasData) return const ListTile(title: LinearProgressIndicator());
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
                        icon: const Icon(Icons.edit_note),
                        tooltip: 'Change ${user.displayName}\'s role',
                        onPressed: () {
                           _showChangeRoleDialog(context, team, user);
                        },
                      ),
                    if (canManage && user.uid != currentUserId && role != 'owner')
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        tooltip: 'Remove ${user.displayName}',
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


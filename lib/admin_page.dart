// lib/admin_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import 'team_detail_page.dart'; // Import the detail page

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Manage Users'),
            Tab(icon: Icon(Icons.groups), text: 'Manage Teams'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _UsersManagementTab(),
          _TeamsManagementTab(),
        ],
      ),
    );
  }
}

// User Management Tab
class _UsersManagementTab extends StatefulWidget {
  const _UsersManagementTab();
  @override
  __UsersManagementTabState createState() => __UsersManagementTabState();
}

class __UsersManagementTabState extends State<_UsersManagementTab> {
  final FirestoreService _firestoreService = FirestoreService();
  Future<List<UserModel>>? _usersFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _usersFuture = _firestoreService.getAllUsers();
    });
  }

  Future<void> _changeUserRole(UserModel user, String newRole) async {
    try {
      await _firestoreService.updateUserRole(user.uid, newRole);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${user.displayName}'s role updated to $newRole"),
          backgroundColor: Colors.green,
        ),
      );
      _refresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update role: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text(
            'Are you sure you want to delete ${user.displayName}? This will remove their app data but not their Google account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteUser(user.uid);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.displayName} deleted.')));
        _refresh();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<UserModel>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found.'));
          }
          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user.photoURL),
                    child: user.photoURL.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user.displayName),
                  subtitle: Text(user.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        onSelected: (String role) =>
                            _changeUserRole(user, role),
                        itemBuilder: (BuildContext context) {
                          return {'admin', 'teacher', 'student'}
                              .map((String role) {
                            return PopupMenuItem<String>(
                              value: role,
                              child: Text(
                                'Set as ${role[0].toUpperCase()}${role.substring(1)}',
                              ),
                            );
                          }).toList();
                        },
                        child: Chip(
                          label: Text(
                            user.appRole,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: _getRoleColor(user.appRole),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteUser(user),
                        tooltip: 'Delete User',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        tooltip: 'Refresh Users',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red.shade100;
      case 'teacher':
        return Colors.blue.shade100;
      case 'student':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade200;
    }
  }
}

// Teams Management Tab
class _TeamsManagementTab extends StatefulWidget {
  const _TeamsManagementTab();
  @override
  __TeamsManagementTabState createState() => __TeamsManagementTabState();
}

class __TeamsManagementTabState extends State<_TeamsManagementTab> {
  final FirestoreService _firestoreService = FirestoreService();
  Future<List<TeamModel>>? _teamsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _teamsFuture = _firestoreService.getAllTeams();
    });
  }

  Future<void> _showCreateTeamDialog() async {
    final userModel =
        Provider.of<UserProvider>(context, listen: false).userModel;
    if (userModel == null) return;

    final teamNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Team'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: teamNameController,
              decoration: const InputDecoration(labelText: 'Team Name'),
              validator: (value) =>
                  value!.isEmpty ? 'Please enter a team name' : null,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Create'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _firestoreService.createTeam(
                        teamNameController.text, userModel);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Team created successfully!")),
                    );
                    _refresh();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to create team: $e")),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTeam(TeamModel team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team?'),
        content: Text('Are you sure you want to delete ${team.teamName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteTeam(team.id);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${team.teamName} deleted.')));
        _refresh();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<TeamModel>>(
        future: _teamsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('No teams have been created yet.'));
          }
          final teams = snapshot.data!;
          return ListView.builder(
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.shield_outlined, size: 40),
                  title: Text(team.teamName),
                  subtitle: Text(team.sport ?? 'General'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${team.members.length} members'),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteTeam(team),
                        tooltip: 'Delete Team',
                      ),
                    ],
                  ),
                  onTap: () { // Make the list tile tappable
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeamDetailPage(
                          team: team,
                          isAdminOverride: true, // Grant admin access
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTeamDialog,
        label: const Text('New Team'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

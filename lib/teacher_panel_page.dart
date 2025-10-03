// lib/teacher_panel_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import 'team_detail_page.dart'; // Import the detail page

class TeacherPanelPage extends StatefulWidget {
  const TeacherPanelPage({super.key});

  @override
  State<TeacherPanelPage> createState() => _TeacherPanelPageState();
}

class _TeacherPanelPageState extends State<TeacherPanelPage> {
  final FirestoreService _firestoreService = FirestoreService();

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
                    // Correctly call the updated createTeam method
                    await _firestoreService.createTeam(
                        teamNameController.text, userModel);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Team created successfully!")),
                    );
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

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final teams = userProvider.teams ?? [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Teacher Panel: Manage Teams'),
          ),
          body: teams.isEmpty
              ? const Center(
                  child: Text('You are not a member of any teams yet.'))
              : ListView.builder(
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading:
                            const Icon(Icons.shield_outlined, size: 40),
                        title: Text(team.teamName),
                        // Correctly handle the nullable sport field
                        subtitle: Text(team.sport ?? 'General'),
                        trailing:
                            Text('${team.members.length} members'),
                        onTap: () { // Make the list tile tappable
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TeamDetailPage(team: team),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showCreateTeamDialog,
            label: const Text('New Team'),
            icon: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

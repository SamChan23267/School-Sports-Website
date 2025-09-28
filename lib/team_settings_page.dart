// lib/team_settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_model.dart';
import '../services/firestore_service.dart';

class TeamSettingsPage extends StatefulWidget {
  final TeamModel team;
  const TeamSettingsPage({super.key, required this.team});

  @override
  State<TeamSettingsPage> createState() => _TeamSettingsPageState();
}

class _TeamSettingsPageState extends State<TeamSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _teamNameController;

  @override
  void initState() {
    super.initState();
    _teamNameController = TextEditingController(text: widget.team.teamName);
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _updateTeamName() async {
    if (_formKey.currentState!.validate()) {
      final firestoreService = context.read<FirestoreService>();
      try {
        await firestoreService.updateTeamName(widget.team.id, _teamNameController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team name updated successfully!')),
        );
        // Pop back to the detail page, which will now show the new name
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating team name: $e')),
        );
      }
    }
  }

  Future<void> _deleteTeam() async {
     final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team?'),
        content: Text('Are you sure you want to permanently delete ${widget.team.teamName}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<FirestoreService>().deleteTeam(widget.team.id);
        // Pop twice to go back past the detail page to the "My Teams" list
        Navigator.of(context)..pop()..pop();
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.team.teamName} has been deleted.')),
        );
      } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting team: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings: ${widget.team.teamName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // General Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('General Settings', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _teamNameController,
                        decoration: const InputDecoration(labelText: 'Team Name'),
                        validator: (value) => value!.isEmpty ? 'Team name cannot be empty' : null,
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _updateTeamName,
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            // Danger Zone
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Danger Zone',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                      title: const Text('Delete this Team'),
                      subtitle: const Text('Once you delete a team, there is no going back.'),
                      onTap: _deleteTeam,
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

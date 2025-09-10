// lib/student_panel_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_model.dart';
import '../providers/user_provider.dart';

class StudentPanelPage extends StatelessWidget {
  const StudentPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Get the list of teams from the provider
        final List<TeamModel> teams = userProvider.teams ?? [];

        return Scaffold(
          // The AppBar is implicitly handled by the main LandingPage scaffold
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "My Teams",
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: teams.isEmpty
                    ? const Center(
                        child: Text('You are not a member of any teams yet.'),
                      )
                    : ListView.builder(
                        itemCount: teams.length,
                        itemBuilder: (context, index) {
                          final team = teams[index];
                          // Get the user's role for this specific team
                          final userRole = team.members[userProvider.userModel?.uid] ?? 'member';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: const Icon(Icons.shield_outlined, size: 40),
                              title: Text(team.teamName),
                              trailing: Chip(
                                label: Text(
                                  // Capitalize the first letter of the role
                                  '${userRole[0].toUpperCase()}${userRole.substring(1)}',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

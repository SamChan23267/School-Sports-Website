// lib/student_panel_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_model.dart';
import '../providers/user_provider.dart';
import 'team_detail_page.dart'; // Import the new detail page

class StudentPanelPage extends StatelessWidget {
  const StudentPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final userModel = userProvider.userModel;
        // **FIX**: Ensure userModel is not null before proceeding
        if (userModel == null) {
          return const Center(child: Text("Loading user data..."));
        }
        
        final List<TeamModel> classroomTeams = userProvider.teams ?? [];
        final List<String> followedTeams = userModel.followedTeams;

        // **FIX**: Add a client-side filter as a safeguard.
        final List<TeamModel> memberTeams = classroomTeams
            .where((team) => team.members.containsKey(userModel.uid))
            .toList();

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  "My Teams & Follows",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              if (memberTeams.isEmpty && followedTeams.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                        'You are not a member of any teams and are not following any public teams yet.'),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      if (memberTeams.isNotEmpty)
                        _buildSectionHeader("Classroom Teams"),
                      ...memberTeams.map((team) {
                        final userRole =
                            team.members[userModel.uid] ?? 'member';
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.group, size: 40),
                            title: Text(team.teamName),
                            subtitle: Text(team.sport ?? 'General'),
                            trailing: Chip(
                              label: Text(
                                '${userRole[0].toUpperCase()}${userRole.substring(1)}',
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TeamDetailPage(team: team),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                      if (followedTeams.isNotEmpty)
                        _buildSectionHeader("Followed Public Teams"),
                      ...followedTeams.map((uniqueId) {
                        final parts = uniqueId.split('::');
                        final sportName = parts[0];
                        final teamName = parts.length > 1 ? parts[1] : uniqueId;
                        return Card(
                           margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.star, size: 40, color: Colors.amber),
                            title: Text(teamName),
                            subtitle: Text(sportName),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey),
      ),
    );
  }
}


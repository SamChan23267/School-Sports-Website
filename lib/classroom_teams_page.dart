// lib/classroom_teams_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/team_model.dart';
import 'models/user_model.dart';
import 'providers/user_provider.dart';
import 'team_detail_page.dart';

class ClassroomTeamsPage extends StatelessWidget {
  const ClassroomTeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Classroom Teams"),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final userModel = userProvider.userModel;
          if (userModel == null) {
            return const Center(child: Text("Please log in to see your teams."));
          }

          final List<TeamModel> classroomTeams = userProvider.teams ?? [];
          final List<TeamModel> memberTeams = classroomTeams
              .where((team) => team.members.containsKey(userModel.uid))
              .toList();

          if (memberTeams.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'You are not a member of any classroom teams yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            children: memberTeams.map((team) {
              final userRole = team.members[userModel.uid] ?? 'member';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                        builder: (context) => TeamDetailPage(team: team),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

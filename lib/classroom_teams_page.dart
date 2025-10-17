// lib/classroom_teams_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_model.dart';
import '../providers/user_provider.dart';
import 'team_detail_page.dart';

class ClassroomTeamsPage extends StatefulWidget {
  const ClassroomTeamsPage({super.key});

  @override
  State<ClassroomTeamsPage> createState() => _ClassroomTeamsPageState();
}

class _ClassroomTeamsPageState extends State<ClassroomTeamsPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final userModel = userProvider.userModel;
        final List<TeamModel> classroomTeams = userProvider.teams ?? [];

        final memberTeams = userModel != null
            ? classroomTeams
                .where((team) => team.members.containsKey(userModel.uid))
                .toList()
            : <TeamModel>[];

        return memberTeams.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'You are not a member of any teams yet. Click the "Join Team" button to join with a code.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: memberTeams.length,
                itemBuilder: (context, index) {
                  final team = memberTeams[index];
                  final userRole = team.members[userModel?.uid] ?? 'member';
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
                        if (team.members.containsKey(userModel!.uid)) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TeamDetailPage(team: team),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              );
      },
    );
  }
}


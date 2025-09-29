import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class FollowedTeamsPage extends StatelessWidget {
  final Function(String sport, String team) onTeamSelected;

  const FollowedTeamsPage({super.key, required this.onTeamSelected});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final followedTeams = userProvider.userModel?.followedTeams ?? [];

        if (followedTeams.isEmpty) {
          return const Center(
            child: Text(
                'You are not following any teams yet. Find a team to follow in the "Select Team" page.'),
          );
        }

        return ListView.builder(
          itemCount: followedTeams.length,
          itemBuilder: (context, index) {
            final uniqueId = followedTeams[index];
            final parts = uniqueId.split('::');
            final sportName = parts[0];
            final teamName = parts.length > 1 ? parts[1] : uniqueId;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.star, size: 40, color: Colors.amber),
                title: Text(teamName),
                subtitle: Text(sportName),
                onTap: () {
                  // This now calls the function passed from the LandingPage
                  onTeamSelected(sportName, teamName);
                },
              ),
            );
          },
        );
      },
    );
  }
}


// lib/followed_teams_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart'; // Needed for SportsListColumn
import 'providers/user_provider.dart';

class FollowedTeamsPage extends StatelessWidget {
  const FollowedTeamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Followed Public Teams"),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final userModel = userProvider.userModel;
          if (userModel == null) {
            return const Center(child: Text("Please log in to see followed teams."));
          }

          final List<String> followedTeams = userModel.followedTeams;

          if (followedTeams.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'You are not following any public teams yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            children: followedTeams.map((uniqueId) {
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
                    // Navigate to a new page that displays the specific team's public details
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: Text(teamName),
                          ),
                          body: SportsListColumn(
                            initialSport: sportName,
                            initialTeam: teamName,
                          ),
                        ),
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

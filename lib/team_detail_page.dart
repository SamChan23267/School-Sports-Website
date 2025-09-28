// lib/team_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/team_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../models/announcement_model.dart';

class TeamDetailPage extends StatefulWidget {
  final TeamModel team;

  const TeamDetailPage({super.key, required this.team});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userModel = userProvider.userModel;
    if (userModel == null) {
      return const Scaffold(
          body: Center(child: Text("Please log in to view team details.")));
    }

    final userTeamRole = widget.team.members[userModel.uid] ?? 'member';
    final canManageTeam = userTeamRole == 'owner' || userTeamRole == 'headCoach';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.teamName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.announcement), text: 'Announcements'),
            Tab(icon: Icon(Icons.list_alt), text: 'Fixtures'),
            Tab(icon: Icon(Icons.people), text: 'Roster'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnnouncementsTab(canManageTeam),
          _buildFixturesTab(canManageTeam),
          _buildRosterTab(canManageTeam),
        ],
      ),
    );
  }

  // A placeholder for the announcements tab
  Widget _buildAnnouncementsTab(bool canManage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Announcements coming soon.'),
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement "Post Announcement" dialog
                },
                icon: const Icon(Icons.add),
                label: const Text('Post Announcement'),
              ),
            ),
        ],
      ),
    );
  }

  // A placeholder for the linked fixtures tab
  Widget _buildFixturesTab(bool canManage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Linked public fixtures coming soon.'),
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement "Link Fixture" functionality
                },
                icon: const Icon(Icons.link),
                label: const Text('Link a Public Fixture'),
              ),
            ),
        ],
      ),
    );
  }

  // A placeholder for the team roster tab
  Widget _buildRosterTab(bool canManage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Team roster coming soon.'),
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement "Add Member" dialog
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add Member'),
              ),
            ),
        ],
      ),
    );
  }
}

// lib/team_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/announcement_model.dart';
import '../models/event_model.dart';
import '../models/team_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import 'team_settings_page.dart';
import 'event_detail_page.dart'; // Import the new event detail page

class TeamDetailPage extends StatefulWidget {
  final TeamModel team;
  final bool isAdminOverride;
  final String? initialEventId; // New
  final int initialTabIndex; // New

  const TeamDetailPage({
    super.key,
    required this.team,
    this.isAdminOverride = false,
    this.initialEventId,
    this.initialTabIndex = 0,
  });

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);

    if (widget.initialEventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailPage(
              team: widget.team,
              eventId: widget.initialEventId!,
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final userModel = context.watch<UserProvider>().userModel;

    if (userModel == null) {
      return const Scaffold(
          body: Center(child: Text("Please log in to view team details.")));
    }

    return StreamBuilder<TeamModel>(
        stream: firestoreService.getTeamStream(widget.team.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Scaffold(
                body: Center(
                    child: Text("Error loading team data or team not found.")));
          }

          final team = snapshot.data!;

          if (!team.members.containsKey(userModel.uid) && !widget.isAdminOverride) {
            return Scaffold(
              appBar: AppBar(title: const Text("Access Denied")),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "You are not a member of this team and cannot view its details.",
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final userTeamRole = team.members[userModel.uid] ?? 'member';
          final isOwner = userTeamRole == 'owner';
          final isManager = userTeamRole == 'manager';
          final isCoach = userTeamRole == 'coach';
          
          final canManageEvents = (isOwner || isManager || isCoach) && team.members.containsKey(userModel.uid);
          final canManageRoster = (isOwner || isManager) && team.members.containsKey(userModel.uid);
          final canAccessSettings = (isOwner || isManager) && team.members.containsKey(userModel.uid);

          return Scaffold(
            appBar: AppBar(
              title: Text(team.teamName),
              actions: [
                if (canAccessSettings)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Team Settings',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeamSettingsPage(
                            team: team,
                            isOwner: isOwner,
                          ),
                        ),
                      );
                    },
                  ),
              ],
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.announcement), text: 'Announcements'),
                  Tab(icon: Icon(Icons.event), text: 'Events'),
                  Tab(icon: Icon(Icons.people), text: 'Roster'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _AnnouncementsTab(team: team),
                _EventsTab(team: team, canManage: canManageEvents),
                _RosterTab(
                    team: team, canManage: canManageRoster, isOwner: isOwner),
              ],
            ),
          );
        });
  }
}

// --- Announcements Tab ---
class _AnnouncementsTab extends StatelessWidget {
  final TeamModel team;
  const _AnnouncementsTab({required this.team});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<AnnouncementModel>>(
        stream:
            context.read<FirestoreService>().getAnnouncementsStream(team.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final announcements = snapshot.data ?? [];
          if (announcements.isEmpty) {
            return const Center(child: Text("No announcements yet."));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return _AnnouncementCard(
                  team: team, announcement: announcement);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    _AnnouncementComposerPage(team: team))),
        tooltip: 'Post Announcement',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final TeamModel team;
  final AnnouncementModel announcement;
  const _AnnouncementCard({required this.team, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProvider>().userModel!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => _AnnouncementDetailPage(
                    team: team, announcement: announcement))),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(announcement.title,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                "Posted by ${announcement.authorName} on ${DateFormat.yMd().format(announcement.timestamp.toDate())}",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                announcement.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ReactionButtons(
                      team: team, announcement: announcement, user: user),
                  Row(
                    children: [
                      const Icon(Icons.reply, size: 16),
                      const SizedBox(width: 4),
                      Text('${announcement.replyCount}'),
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionButtons extends StatelessWidget {
  final TeamModel team;
  final AnnouncementModel announcement;
  final UserModel user;
  const _ReactionButtons(
      {required this.team, required this.announcement, required this.user});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final reactions = ['👍', '❤️', '🎉', '🤔'];

    return Row(
      children: reactions.map((emoji) {
        final reactors = announcement.reactions[emoji] ?? [];
        final isReacted = reactors.contains(user.uid);
        final count = reactors.length;

        return Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              backgroundColor: isReacted
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
            ),
            onPressed: () {
              firestoreService.toggleReaction(
                  team.id, announcement.id, user.uid, emoji);
            },
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Text('$count'),
                ]
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AnnouncementDetailPage extends StatelessWidget {
  final TeamModel team;
  final AnnouncementModel announcement;

  const _AnnouncementDetailPage(
      {required this.team, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProvider>().userModel!;
    final firestoreService = context.read<FirestoreService>();
    final replyController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: Text(announcement.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(announcement.title,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  "Posted by ${announcement.authorName} on ${DateFormat.yMd().format(announcement.timestamp.toDate())}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 24),
                Text(announcement.content,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                _ReactionButtons(
                    team: team, announcement: announcement, user: user),
                const Divider(height: 24),
                Text("Replies", style: Theme.of(context).textTheme.titleLarge),
                StreamBuilder<List<ReplyModel>>(
                  stream: firestoreService.getRepliesStream(
                      team.id, announcement.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final replies = snapshot.data ?? [];
                    if (replies.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text("No replies yet."),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: replies.length,
                      itemBuilder: (context, index) {
                        final reply = replies[index];
                        return ListTile(
                          title: Text(reply.authorName),
                          subtitle: Text(reply.content),
                          trailing: Text(DateFormat.yMd()
                              .format(reply.timestamp.toDate())),
                        );
                      },
                    );
                  },
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: replyController,
                    decoration: const InputDecoration(
                      hintText: 'Write a reply...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (replyController.text.isNotEmpty) {
                      firestoreService.addReplyToAnnouncement(
                          team.id, announcement.id, user, replyController.text);
                      replyController.clear();
                    }
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _AnnouncementComposerPage extends StatefulWidget {
  final TeamModel team;
  const _AnnouncementComposerPage({required this.team});

  @override
  State<_AnnouncementComposerPage> createState() =>
      _AnnouncementComposerPageState();
}

class _AnnouncementComposerPageState extends State<_AnnouncementComposerPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProvider>().userModel!;
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Announcement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await firestoreService.postAnnouncement(widget.team.id, user,
                    _titleController.text, _contentController.text);
                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter content' : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Events Tab ---
class _EventsTab extends StatelessWidget {
  final TeamModel team;
  final bool canManage;
  const _EventsTab({required this.team, required this.canManage});

  void _showCreateEventDialog(BuildContext context) {
    final userModel = context.read<UserProvider>().userModel;
    if (userModel == null) return;
    showDialog(
      context: context,
      builder: (dialogContext) => EventDialog(
        team: team,
        author: userModel,
      ),
    );
  }

  String _formatEventTime(EventModel event) {
    final start = event.eventDate.toDate();
    if (event.eventEndDate == null) {
      return DateFormat.yMMMEd().add_jm().format(start);
    }
    final end = event.eventEndDate!.toDate();
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '${DateFormat.yMMMEd().format(start)}, ${DateFormat.jm().format(start)} - ${DateFormat.jm().format(end)}';
    }
    return '${DateFormat.yMMMEd().add_jm().format(start)} - ${DateFormat.yMMMEd().add_jm().format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final userModel = context.read<UserProvider>().userModel!;
    final userTeamRole = team.members[userModel.uid] ?? 'member';
    final canManageEvents = ['owner', 'manager', 'coach'].contains(userTeamRole);

    return Scaffold(
      body: StreamBuilder<List<EventModel>>(
        stream: firestoreService.getEventsStream(team.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return const Center(child: Text("No upcoming events."));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final going =
                  event.responses.values.where((r) => r == 'going').length;
              final maybe =
                  event.responses.values.where((r) => r == 'maybe').length;

              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  title: Text(event.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatEventTime(event)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text('$going'),
                          const SizedBox(width: 12),
                          const Icon(Icons.help,
                              color: Colors.orange, size: 16),
                          const SizedBox(width: 4),
                          Text('$maybe'),
                        ],
                      )
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EventDetailPage(
                                team: team,
                                eventId: event.id)));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _showCreateEventDialog(context),
              tooltip: 'Create Event',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// --- Roster Tab ---
class _RosterTab extends StatelessWidget {
  final TeamModel team;
  final bool canManage;
  final bool isOwner;
  const _RosterTab(
      {required this.team, required this.canManage, required this.isOwner});

  void _showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AddMemberDialog(team: team),
    );
  }

  void _showChangeRoleDialog(
      BuildContext context, TeamModel team, UserModel member) {
    String selectedRole = team.members[member.uid] ?? 'member';
    final availableRoles =
        isOwner ? ['member', 'coach', 'manager'] : ['member', 'coach'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Change Role for ${member.displayName}'),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            decoration: const InputDecoration(labelText: 'Role'),
            items: availableRoles
                .map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role[0].toUpperCase() + role.substring(1)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                selectedRole = value;
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final firestoreService = context.read<FirestoreService>();
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                try {
                  await firestoreService.updateTeamMemberRole(
                      team.id, member.uid, selectedRole);
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(
                            '${member.displayName}\'s role updated to $selectedRole.'),
                        backgroundColor: Colors.green),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text('Failed to update role: $e'),
                        backgroundColor: Colors.red),
                  );
                }
                navigator.pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showTransferOwnershipDialog(
      BuildContext context, UserModel newOwner) {
    showDialog(
        context: context,
        builder: (dialogContext) =>
            _TransferOwnershipDialog(team: team, newOwner: newOwner));
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final currentUserId = context.read<UserProvider>().userModel?.uid;

    return Scaffold(
      body: ListView(
        children: team.members.entries.map((entry) {
          final userId = entry.key;
          final role = entry.value;

          return StreamBuilder<UserModel>(
            stream: firestoreService.getUserStream(userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(title: LinearProgressIndicator());
              }
              final user = snapshot.data!;
              final memberRole = team.members[user.uid] ?? 'member';

              bool canManageThisMember = false;
              if (canManage && user.uid != currentUserId) {
                if (isOwner) {
                  canManageThisMember = true;
                } else if (memberRole != 'owner' && memberRole != 'manager') {
                  canManageThisMember = true;
                }
              }
              
              bool showTransferButton = isOwner && user.uid != currentUserId;

              return ListTile(
                leading:
                    CircleAvatar(backgroundImage: NetworkImage(user.photoURL)),
                title: Text(user.displayName),
                subtitle: Text(user.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if(showTransferButton)
                      TextButton(
                        onPressed: () => _showTransferOwnershipDialog(context, user),
                        child: const Text('Make Owner'),
                      ),
                    Chip(label: Text(role)),
                    if (canManageThisMember)
                      IconButton(
                        icon: const Icon(Icons.edit_note),
                        tooltip: 'Change ${user.displayName}\'s role',
                        onPressed: () {
                          _showChangeRoleDialog(context, team, user);
                        },
                      ),
                    if (canManageThisMember)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        tooltip: 'Remove ${user.displayName}',
                        onPressed: () async {
                          await firestoreService.removeTeamMember(
                              team.id, user.uid);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  '${user.displayName} removed from team.')));
                        },
                      ),
                  ],
                ),
              );
            },
          );
        }).toList(),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => _showAddMemberDialog(context),
              tooltip: 'Add Member',
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final TeamModel team;
  const _AddMemberDialog({required this.team});

  @override
  _AddMemberDialogState createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  UserModel? _selectedUser;
  String _selectedRole = 'member';
  Timer? _debounce;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);
    final firestoreService = context.read<FirestoreService>();
    final results = await firestoreService.searchUsers(_searchController.text);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  void _addSelectedMember() async {
    if (_selectedUser == null) return;

    final firestoreService = context.read<FirestoreService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (widget.team.members.containsKey(_selectedUser!.uid)) {
      messenger.showSnackBar(SnackBar(
        content: Text('${_selectedUser!.displayName} is already in the team.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    try {
      await firestoreService.addTeamMember(
          widget.team.id, _selectedUser!.uid, _selectedRole);
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Successfully added ${_selectedUser!.displayName} to the team.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Failed to add member: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Member'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedUser == null)
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search by name or email',
                  suffixIcon: Icon(Icons.search),
                ),
              ),
            if (_selectedUser != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                    backgroundImage: NetworkImage(_selectedUser!.photoURL)),
                title: Text(_selectedUser!.displayName),
                subtitle: Text(_selectedUser!.email),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedUser = null;
                      _searchController.clear();
                      _performSearch();
                    });
                  },
                ),
              ),
            if (_selectedUser == null)
              SizedBox(
                height: 200,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? const Center(child: Text('No users found.'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return ListTile(
                                leading: CircleAvatar(
                                    backgroundImage:
                                        NetworkImage(user.photoURL)),
                                title: Text(user.displayName),
                                subtitle: Text(user.email),
                                onTap: () {
                                  setState(() {
                                    _selectedUser = user;
                                    _searchResults = [];
                                  });
                                },
                              );
                            },
                          ),
              ),
            if (_selectedUser != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: ['member', 'coach', 'manager']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child:
                              Text(role[0].toUpperCase() + role.substring(1)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedUser != null ? _addSelectedMember : null,
          child: const Text('Add Member'),
        ),
      ],
    );
  }
}

class _TransferOwnershipDialog extends StatefulWidget {
  final TeamModel team;
  final UserModel newOwner;
  const _TransferOwnershipDialog(
      {required this.team, required this.newOwner});

  @override
  State<_TransferOwnershipDialog> createState() =>
      _TransferOwnershipDialogState();
}

class _TransferOwnershipDialogState extends State<_TransferOwnershipDialog> {
  final _confirmController = TextEditingController();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _confirmController.addListener(() {
      setState(() {
        _isButtonEnabled = _confirmController.text == widget.team.teamName;
      });
    });
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  void _confirmTransfer() async {
    final firestoreService = context.read<FirestoreService>();
    final currentUserId = context.read<UserProvider>().userModel!.uid;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await firestoreService.transferOwnership(
          widget.team.id, widget.newOwner.uid, currentUserId);
      navigator.pop();
      messenger.showSnackBar(SnackBar(
          content:
              Text('Ownership successfully transferred to ${widget.newOwner.displayName}'),
          backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Failed to transfer ownership: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer Team Ownership?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'You are about to make ${widget.newOwner.displayName} the new owner of ${widget.team.teamName}.'),
          const SizedBox(height: 8),
          const Text(
              'You will be demoted to a manager and will lose the ability to delete the team or transfer ownership again.'),
          const SizedBox(height: 16),
          Text(
              'To confirm, please type the team name below: "${widget.team.teamName}"'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmController,
            decoration:
                const InputDecoration(labelText: 'Confirm Team Name'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isButtonEnabled ? _confirmTransfer : null,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Confirm Transfer'),
        ),
      ],
    );
  }
}


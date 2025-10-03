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

class TeamDetailPage extends StatefulWidget {
  final TeamModel team;

  const TeamDetailPage({super.key, required this.team});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        // Listen to live updates for the team
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

          // Check for membership before showing content
          if (!team.members.containsKey(userModel.uid)) {
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

          // Define granular permissions based on the user's role
          final isOwner = userTeamRole == 'owner';
          final isManager = userTeamRole == 'manager';
          final isCoach = userTeamRole == 'coach';

          final canManageEvents = isOwner || isManager || isCoach;
          final canManageRoster = isOwner || isManager;
          final canAccessSettings = isOwner || isManager;

          return Scaffold(
            appBar: AppBar(
              title: Text(team.teamName), // Use live team name
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
                            isOwner: isOwner, // Pass owner status
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
                  Tab(icon: Icon(Icons.photo_library), text: 'Gallery'),
                  Tab(icon: Icon(Icons.people), text: 'Roster'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _AnnouncementsTab(team: team),
                _EventsTab(team: team, canManage: canManageEvents),
                const _FeatureComingSoonTab(featureName: 'Gallery'),
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
    // Per requirements, all members can post announcements.
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
      builder: (dialogContext) => _EventDialog(
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
                            builder: (context) => _EventDetailPage(
                                team: team,
                                eventId: event.id,
                                canManageEvents: canManageEvents)));
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

// --- New Event Detail Page ---
class _EventDetailPage extends StatelessWidget {
  final TeamModel team;
  final String eventId;
  final bool canManageEvents;

  const _EventDetailPage(
      {required this.team,
      required this.eventId,
      required this.canManageEvents});

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

  Future<void> _deleteEvent(BuildContext context, EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text(
            'Are you sure you want to permanently delete this event?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final firestoreService = context.read<FirestoreService>();
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      try {
        await firestoreService.deleteEvent(team.id, event.id);
        navigator.pop(); // Go back from the detail page
        messenger
            .showSnackBar(const SnackBar(content: Text('Event deleted.')));
      } catch (e) {
        messenger.showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userModel = context.read<UserProvider>().userModel!;
    final firestoreService = context.read<FirestoreService>();

    return StreamBuilder<EventModel>(
        stream: firestoreService.getEventStream(team.id, eventId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                  child: Text("Event not found or an error occurred.")),
            );
          }

          final event = snapshot.data!;

          return Scaffold(
            appBar: AppBar(
              title: Text(event.title),
              actions: [
                if (canManageEvents)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => _EventDialog(
                          team: team,
                          author: userModel,
                          eventToEdit: event,
                        ),
                      );
                    },
                  ),
                if (canManageEvents)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteEvent(context, event),
                  ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(_formatEventTime(event)),
                  ),
                  if (event.description != null &&
                      event.description!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.short_text),
                      title: Text(event.description!),
                    ),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('Created by ${event.authorName}'),
                  ),
                  const Divider(height: 32),
                  Text('Your Availability',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _AvailabilityButtons(
                    currentResponse: event.responses[userModel.uid],
                    onRespond: (status) {
                      firestoreService.respondToEvent(
                          team.id, event.id, userModel.uid, status);
                    },
                  ),
                  const Divider(height: 32),
                  Text('Responses',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _ResponseList(responses: event.responses),
                ],
              ),
            ),
          );
        });
  }
}

class _AvailabilityButtons extends StatelessWidget {
  final String? currentResponse;
  final Function(String) onRespond;

  const _AvailabilityButtons({this.currentResponse, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildButton(
            context, 'going', 'Going', Icons.check_circle, Colors.green),
        _buildButton(context, 'maybe', 'Maybe', Icons.help, Colors.orange),
        _buildButton(
            context, 'not_going', 'Not Going', Icons.cancel, Colors.red),
      ],
    );
  }

  Widget _buildButton(BuildContext context, String status, String label,
      IconData icon, Color color) {
    final isSelected = currentResponse == status;
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: () => onRespond(status),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : null,
        foregroundColor: isSelected ? Colors.white : null,
      ),
    );
  }
}

class _ResponseList extends StatelessWidget {
  final Map<String, String> responses;
  const _ResponseList({required this.responses});

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) {
      return const Text('No one has responded yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResponseCategory(
            context, 'going', 'Going', Icons.check_circle, Colors.green),
        _buildResponseCategory(
            context, 'maybe', 'Maybe', Icons.help, Colors.orange),
        _buildResponseCategory(
            context, 'not_going', 'Not Going', Icons.cancel, Colors.red),
      ],
    );
  }

  Widget _buildResponseCategory(BuildContext context, String status,
      String title, IconData icon, Color color) {
    final userIds = responses.entries
        .where((e) => e.value == status)
        .map((e) => e.key)
        .toList();
    if (userIds.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text('$title (${userIds.length})',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  userIds.map((uid) => _UserResponseTile(uid: uid)).toList(),
            ),
          )
        ],
      ),
    );
  }
}

class _UserResponseTile extends StatelessWidget {
  final String uid;
  const _UserResponseTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel>(
      stream: context.read<FirestoreService>().getUserStream(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Loading...');
        final user = snapshot.data!;
        return Text(user.displayName);
      },
    );
  }
}

// --- Event Create/Edit Dialog ---
class _EventDialog extends StatefulWidget {
  final TeamModel team;
  final UserModel author;
  final EventModel? eventToEdit;

  const _EventDialog(
      {required this.team, required this.author, this.eventToEdit});

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isAllDay = true;

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;
    if (event != null) {
      _titleController = TextEditingController(text: event.title);
      _descriptionController = TextEditingController(text: event.description);
      _startDate = event.eventDate.toDate();
      _endDate = event.eventEndDate?.toDate();
      _isAllDay = _endDate == null;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    setState(() {
      final newDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _startDate = newDateTime;
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(hours: 1));
        }
      } else {
        _endDate = newDateTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.eventToEdit == null ? 'Create New Event' : 'Edit Event'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Event Title'),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration:
                    const InputDecoration(labelText: 'Description (Optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Start: ${DateFormat.yMMMEd().add_jm().format(_startDate)}'),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () => _pickDate(true),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All-day or single time event'),
                value: _isAllDay,
                onChanged: (value) => setState(() {
                  _isAllDay = value;
                  if (value) {
                    _endDate = null;
                  } else {
                    _endDate = _startDate.add(const Duration(hours: 1));
                  }
                }),
              ),
              if (!_isAllDay)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'End: ${DateFormat.yMMMEd().add_jm().format(_endDate!)}'),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () => _pickDate(false),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final firestoreService = context.read<FirestoreService>();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              try {
                if (widget.eventToEdit == null) {
                  await firestoreService.createEvent(
                    widget.team.id,
                    _titleController.text,
                    _descriptionController.text,
                    _startDate,
                    _isAllDay ? null : _endDate,
                    widget.author,
                  );
                } else {
                  await firestoreService.updateEvent(
                    widget.team.id,
                    widget.eventToEdit!.id,
                    _titleController.text,
                    _descriptionController.text,
                    _startDate,
                    _isAllDay ? null : _endDate,
                  );
                }

                navigator.pop(); // Close the dialog
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(widget.eventToEdit == null
                        ? 'Event created!'
                        : 'Event updated!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to save event: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
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
    final firestoreService = context.read<FirestoreService>();
    final currentUserId = context.read<UserProvider>().userModel!.uid;

    String selectedRole = team.members[member.uid] ?? 'member';
    final availableRoles = isOwner
        ? ['member', 'coach', 'manager', 'owner']
        : ['member', 'coach', 'manager'];

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
                      // Disable owner option if target user is the current owner
                      enabled: !(role == 'owner' && member.uid == currentUserId),
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
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                try {
                  if (selectedRole == 'owner') {
                    // Handle ownership transfer
                    await firestoreService.transferOwnership(
                        team.id, member.uid, currentUserId);
                     messenger.showSnackBar(
                      SnackBar(
                          content: Text(
                              'Ownership transferred to ${member.displayName}.'),
                          backgroundColor: Colors.green),
                    );
                  } else {
                    // Handle normal role update
                    await firestoreService.updateTeamMemberRole(
                        team.id, member.uid, selectedRole);
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text(
                              '${member.displayName}\'s role updated to $selectedRole.'),
                          backgroundColor: Colors.green),
                    );
                  }
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

              // Determine if the current user can manage this specific member
              bool canManageThisMember = false;
              if(canManage) {
                if (isOwner && user.uid != currentUserId) {
                  canManageThisMember = true;
                } else if (!isOwner && memberRole != 'owner' && memberRole != 'manager') {
                  // A manager can't manage another manager or the owner
                  canManageThisMember = true;
                }
              }

              return ListTile(
                leading:
                    CircleAvatar(backgroundImage: NetworkImage(user.photoURL)),
                title: Text(user.displayName),
                subtitle: Text(user.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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

// --- New Add Member Dialog with Search ---
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
    _performSearch(); // Perform initial search for all users
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
    // The searchUsers function now handles both empty and non-empty queries
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
                      _performSearch(); // Re-fetch all users
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

// --- Placeholder Tab ---
class _FeatureComingSoonTab extends StatelessWidget {
  final String featureName;
  const _FeatureComingSoonTab({required this.featureName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '$featureName Feature Coming Soon!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

// lib/event_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/event_model.dart';
import '../models/team_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';

class EventDetailPage extends StatelessWidget {
  final TeamModel team;
  final String eventId;

  const EventDetailPage({
    super.key,
    required this.team,
    required this.eventId,
  });

  String _formatEventTime(EventModel event) {
    final start = event.eventDate.toDate();
    if (event.eventEndDate == null) {
      return DateFormat.yMMMEd().add_jm().format(start);
    }
    final end = event.eventEndDate!.toDate();
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return '${DateFormat.yMMMEd().format(start)}, ${DateFormat.jm().format(start)} - ${DateFormat.jm().format(end)}';
    }
    return '${DateFormat.yMMMEd().add_jm().format(start)} - ${DateFormat.yMMMEd().add_jm().format(end)}';
  }

  Future<void> _deleteEvent(BuildContext context, EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text('Are you sure you want to permanently delete this event?'),
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
      final firestoreService = context.read<FirestoreService>();
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      try {
        await firestoreService.deleteEvent(team.id, event.id);
        navigator.pop();
        messenger.showSnackBar(const SnackBar(content: Text('Event deleted.')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userModel = context.read<UserProvider>().userModel!;
    final firestoreService = context.read<FirestoreService>();
    final userTeamRole = team.members[userModel.uid] ?? 'member';
    final canManageEvents = ['owner', 'manager', 'coach'].contains(userTeamRole);

    return StreamBuilder<EventModel>(
      stream: firestoreService.getEventStream(team.id, eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text("Event not found or an error occurred.")));
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
                      builder: (dialogContext) => EventDialog(
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
                Text(event.title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(_formatEventTime(event)),
                ),
                if (event.description != null && event.description!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.short_text),
                    title: Text(event.description!),
                  ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text('Created by ${event.authorName}'),
                ),
                const Divider(height: 32),
                Text('Your Availability', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _AvailabilityButtons(
                  currentResponse: event.responses[userModel.uid],
                  onRespond: (status) {
                    firestoreService.respondToEvent(team.id, event.id, userModel.uid, status);
                  },
                ),
                const Divider(height: 32),
                Text('Responses', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _ResponseList(responses: event.responses),
              ],
            ),
          ),
        );
      },
    );
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
        _buildButton(context, 'going', 'Going', Icons.check_circle, Colors.green),
        _buildButton(context, 'maybe', 'Maybe', Icons.help, Colors.orange),
        _buildButton(context, 'not_going', 'Not Going', Icons.cancel, Colors.red),
      ],
    );
  }

  Widget _buildButton(BuildContext context, String status, String label, IconData icon, Color color) {
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
        _buildResponseCategory(context, 'going', 'Going', Icons.check_circle, Colors.green),
        _buildResponseCategory(context, 'maybe', 'Maybe', Icons.help, Colors.orange),
        _buildResponseCategory(context, 'not_going', 'Not Going', Icons.cancel, Colors.red),
      ],
    );
  }

  Widget _buildResponseCategory(BuildContext context, String status, String title, IconData icon, Color color) {
    final userIds = responses.entries.where((e) => e.value == status).map((e) => e.key).toList();
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
              Text('$title (${userIds.length})', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: userIds.map((uid) => _UserResponseTile(uid: uid)).toList(),
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
class EventDialog extends StatefulWidget {
  final TeamModel team;
  final UserModel author;
  final EventModel? eventToEdit;

  const EventDialog(
      {super.key, required this.team, required this.author, this.eventToEdit});

  @override
  State<EventDialog> createState() => EventDialogState();
}

class EventDialogState extends State<EventDialog> {
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


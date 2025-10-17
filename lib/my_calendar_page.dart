// lib/my_calendar_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart';
import '../models/calendar_event_model.dart';
import '../models/team_model.dart';
import '../models/event_model.dart';
import '../models.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import 'fixture_detail_screen.dart';
import 'team_detail_page.dart';
import 'event_detail_page.dart'; // Import the new event detail page

class MyCalendarPage extends StatefulWidget {
  const MyCalendarPage({super.key});

  @override
  State<MyCalendarPage> createState() => _MyCalendarPageState();
}

class _MyCalendarPageState extends State<MyCalendarPage> {
  late final ValueNotifier<List<CalendarEvent>> _selectedEvents;
  Map<DateTime, List<CalendarEvent>> _allEvents = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;
  String? _error;
  String? _loadedForUserId;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.userModel;

    if (user != null && user.uid != _loadedForUserId) {
      _loadedForUserId = user.uid;
      _loadAllEvents(userProvider);
    }
  }

  Future<void> _loadAllEvents(UserProvider userProvider) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final firestoreService = context.read<FirestoreService>();
      final apiService = context.read<ApiService>();
      final user = userProvider.userModel!;

      final Map<DateTime, List<CalendarEvent>> events = {};

      final teamEvents = await firestoreService.getAllEventsForUser(user);
      for (final event in teamEvents) {
        final eventDate = event.eventDate.toDate();
        final day = DateTime.utc(eventDate.year, eventDate.month, eventDate.day);

        TeamModel? team = userProvider.teams?.firstWhereOrNull((t) => t.id == event.teamId);
        if (team == null) {
          team = await firestoreService.getTeamById(event.teamId);
        }
        final teamName = team?.teamName ?? 'Unknown Team';

        final calendarEvent = CalendarEvent.fromTeamEvent(event, teamName);
        (events[day] ??= []).add(calendarEvent);
      }

      final followedTeams = user.followedTeams;
      if (followedTeams.isNotEmpty) {
        final teamNames = followedTeams.map((e) => e.split('::')[1]).toSet();
        final allFixtures = await apiService.getFixtures(
            dateRange: DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 90)),
                end: DateTime.now().add(const Duration(days: 90))));

        final followedFixtures = allFixtures.where(
            (f) => teamNames.contains(f.homeTeam) || teamNames.contains(f.awayTeam));

        for (final fixture in followedFixtures) {
          try {
            final fixtureDate = DateTime.parse(fixture.dateTime);
            final day =
                DateTime.utc(fixtureDate.year, fixtureDate.month, fixtureDate.day);
            final calendarEvent = CalendarEvent.fromFixture(fixture);
            (events[day] ??= []).add(calendarEvent);
          } catch (e) {
            print("Skipping fixture with invalid date: ${fixture.dateTime}");
          }
        }
      }

      if (mounted) {
        setState(() {
          _allEvents = events;
          _selectedEvents.value = _getEventsForDay(_selectedDay!);
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print("Error loading calendar items: $e");
      print("Stack trace: $stackTrace");
      if (mounted) {
        setState(() {
          _error = "Failed to load calendar items. Please check the browser console (F12) for details.";
          _isLoading = false;
        });
      }
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _allEvents[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().userModel;
    if (user == null) {
      return const Center(child: Text("Please log in to see your calendar."));
    }

    return Column(
      children: [
        TableCalendar<CalendarEvent>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: _onDaySelected,
          eventLoader: _getEventsForDay,
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
          ),
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : ValueListenableBuilder<List<CalendarEvent>>(
                      valueListenable: _selectedEvents,
                      builder: (context, value, _) {
                        return ListView.builder(
                          itemCount: value.length,
                          itemBuilder: (context, index) {
                            final event = value[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 4.0),
                              child: ListTile(
                                leading: Icon(
                                  event.type == CalendarEventType.fixture
                                      ? Icons.sports_soccer
                                      : Icons.event,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(event.title),
                                subtitle: Text(event.subtitle),
                                onTap: () async {
                                  if (event.type == CalendarEventType.fixture &&
                                      event.fixture != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            FixtureDetailScreen(
                                                fixture: event.fixture!),
                                      ),
                                    );
                                  } else if (event.type ==
                                          CalendarEventType.teamEvent &&
                                      event.teamEvent != null) {
                                    final userProvider =
                                        context.read<UserProvider>();
                                    final firestoreService =
                                        context.read<FirestoreService>();

                                    TeamModel? team = userProvider.teams
                                        ?.firstWhereOrNull((t) =>
                                            t.id == event.teamEvent!.teamId);

                                    if (team == null) {
                                      team = await firestoreService
                                          .getTeamById(event.teamEvent!.teamId);
                                    }

                                    if (team != null) {
                                      // **FIX**: Implement desired navigation flow
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              TeamDetailPage(
                                                team: team!,
                                                initialTabIndex: 1, // Go to events tab
                                                initialEventId: event.teamEvent!.id,
                                              ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  "Could not find the team for this event.")));
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }
}


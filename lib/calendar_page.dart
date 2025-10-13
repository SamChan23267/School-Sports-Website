// lib/calendar_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'models.dart';
import 'services/api_service.dart';
import 'fixture_detail_screen.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final ApiService _apiService = ApiService();
  Map<DateTime, List<Fixture>> _fixturesByDate = {};
  List<Fixture> _selectedDayFixtures = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadFixtures();
  }

  Future<void> _loadFixtures() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dateRange = DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 365)),
        end: DateTime.now().add(const Duration(days: 365)),
      );
      final allFixtures = await _apiService.getFixtures(dateRange: dateRange);
      final Map<DateTime, List<Fixture>> fixturesMap = {};

      for (final fixture in allFixtures) {
        try {
          final date = DateTime.parse(fixture.dateTime).toLocal();
          final dayOnly = DateTime.utc(date.year, date.month, date.day);
          if (fixturesMap[dayOnly] == null) {
            fixturesMap[dayOnly] = [];
          }
          fixturesMap[dayOnly]!.add(fixture);
        } catch (e) {
          // Ignore fixtures with invalid date format
        }
      }
      
      // Sort fixtures within each day
      fixturesMap.forEach((key, value) {
        value.sort((a, b) => DateTime.parse(a.dateTime).compareTo(DateTime.parse(b.dateTime)));
      });


      setState(() {
        _fixturesByDate = fixturesMap;
        _selectedDayFixtures = _getFixturesForDay(_selectedDay!);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading fixtures: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Fixture> _getFixturesForDay(DateTime day) {
    final dayOnly = DateTime.utc(day.year, day.month, day.day);
    return _fixturesByDate[dayOnly] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedDayFixtures = _getFixturesForDay(selectedDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        TableCalendar<Fixture>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: _onDaySelected,
          eventLoader: _getFixturesForDay,
          calendarStyle: CalendarStyle(
            markerDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: Theme.of(context).textTheme.titleLarge ?? const TextStyle(),
          ),
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: _selectedDayFixtures.isEmpty
              ? const Center(child: Text('No fixtures for this day.'))
              : ListView.builder(
                  itemCount: _selectedDayFixtures.length,
                  itemBuilder: (context, index) {
                    final fixture = _selectedDayFixtures[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      child: ListTile(
                        title: Text('${fixture.homeTeam} vs ${fixture.awayTeam}'),
                        subtitle: Text('${fixture.sport} - ${fixture.competition}'),
                        trailing: Text(DateFormat.jm().format(DateTime.parse(fixture.dateTime).toLocal())),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FixtureDetailScreen(fixture: fixture),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// lib/models/calendar_event_model.dart
import 'package:flutter/material.dart';
import '../fixture_detail_screen.dart';
import '../team_detail_page.dart';
import '../models.dart';
import 'event_model.dart';
import 'team_model.dart';


enum CalendarEventType { fixture, teamEvent }

class CalendarEvent {
  final String title;
  final DateTime date;
  final String subtitle;
  final CalendarEventType type;

  // Optional original objects for navigation
  final Fixture? fixture;
  final EventModel? teamEvent;

  CalendarEvent({
    required this.title,
    required this.date,
    required this.subtitle,
    required this.type,
    this.fixture,
    this.teamEvent,
  });

  factory CalendarEvent.fromFixture(Fixture fixture) {
    return CalendarEvent(
      title: "${fixture.homeTeam} vs ${fixture.awayTeam}",
      date: DateTime.parse(fixture.dateTime),
      subtitle: fixture.competition,
      type: CalendarEventType.fixture,
      fixture: fixture,
      teamEvent: null,
    );
  }

  factory CalendarEvent.fromTeamEvent(EventModel event, String teamName) {
    return CalendarEvent(
      title: event.title,
      date: event.eventDate.toDate(),
      subtitle: "Team Event for $teamName",
      type: CalendarEventType.teamEvent,
      fixture: null,
      teamEvent: event,
    );
  }
}


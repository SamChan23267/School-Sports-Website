import 'dart:convert';
import 'package:flutter/services.dart';

class Fixture {
  final String sport;
  final String competition;
  final bool premier;
  final String dateTime;
  final String venue;
  final String homeOrg;
  final String awayOrg;

  Fixture({
    required this.sport,
    required this.competition,
    required this.premier,
    required this.dateTime,
    required this.venue,
    required this.homeOrg,
    required this.awayOrg,
  });

  factory Fixture.fromJson(Map<String, dynamic> json) {
    return Fixture(
      sport: json['sport'] ?? '',
      competition: json['competition'] ?? '',
      premier: json['premier'] ?? true, // default to true if missing
      dateTime: json['date_time'] ?? '',
      venue: json['venue'] ?? '',
      homeOrg: json['home_org'] ?? '',
      awayOrg: json['away_org'] ?? '',
    );
  }
}

class FixtureLoader {
  static Future<List<Fixture>> loadFixtures() async {
    final String jsonString = await rootBundle.loadString('assets/fixtures.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => Fixture.fromJson(json)).toList();
  }
}
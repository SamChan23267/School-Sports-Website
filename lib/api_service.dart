// lib/api_service.dart

import 'package:flutter/material.dart';
import 'models.dart';
import 'services/collegesport_api_service.dart';
import 'services/rugbyunion_api_service.dart';

class ApiService {
  final CollegeSportApiService _collegeSportApi = CollegeSportApiService();
  final RugbyUnionApiService _rugbyUnionApi = RugbyUnionApiService();

  static const Map<String, String> _sportIcons = {
    'Football': '⚽', 'Basketball': '🏀', 'Tennis': '🎾', 'Cricket': '🏏',
    'Hockey': '🏒', 'Rugby Union': '🏉', 'Volleyball': '🏐', 'Netball': '🥅',
    'Default': '🏅',
  };

  Future<List<Sport>> getSportsForSacredHeart() async {
    final List<Fixture> allFixtures = await getFixtures();
    final Set<String> sportNames = allFixtures.map((f) => f.sport).toSet();
    
    final List<Sport> sports = sportNames.map((name) {
      final icon = _sportIcons[name] ?? _sportIcons['Default']!;
      final id = name.hashCode; 
      final source = name == 'Rugby Union' ? DataSource.rugbyUnion : DataSource.collegeSport;
      return Sport(id: id, name: name, icon: icon, source: source);
    }).toList();

    sports.sort((a, b) => a.name.compareTo(b.name));
    return sports;
  }

  Future<List<Fixture>> getFixtures({DateTimeRange? dateRange}) async {
    final results = await Future.wait([
      _collegeSportApi.getFixtures(dateRange: dateRange),
      _rugbyUnionApi.getFixtures(dateRange: dateRange),
    ]);

    final allFixtures = results.expand((fixtures) => fixtures).toList();
    return allFixtures;
  }

  Future<List<String>> getTeamsForSport(String sportName) async {
    const String schoolName = "Sacred Heart College";
    final List<Fixture> fixtures = await getFixtures();

    final teams = fixtures
        .where((f) => f.sport == sportName && (f.homeSchool.contains(schoolName) || f.awaySchool.contains(schoolName)))
        .map((f) {
            if (f.homeSchool.contains(schoolName)) return f.homeTeam;
            return f.awayTeam;
        })
        .toSet()
        .toList()
      ..sort();

    return teams;
  }

  Future<List<Fixture>> getFixturesForTeam(String teamName) async {
    final allFixtures = await getFixtures(
        dateRange: DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 90)),
      end: DateTime.now().add(const Duration(days: 90)),
    ));
    return allFixtures
        .where((f) => f.homeTeam == teamName || f.awayTeam == teamName)
        .toList();
  }

  Future<List<StandingsTable>> getStandings(String competitionId, int gradeId, DataSource source) async {
    if (source == DataSource.collegeSport) {
      return _collegeSportApi.getStandings(int.parse(competitionId), gradeId);
    } else {
      return _rugbyUnionApi.getStandings(competitionId);
    }
  }
}

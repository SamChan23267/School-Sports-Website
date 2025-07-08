// lib/api_service.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models.dart';

class ApiService {
  static const String _baseUrl = "http://localhost:9999/api/v2/competition/widget";
  
  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36',
  };

  Map<String, dynamic>? _cachedMetadata;
  List<Fixture>? _cachedFixtures;

  static final List<String> _initialCompIdsPayload = [
    "10362", "10180", "10181", "10182", "10183", "10184", "10113", "10114", "10115", "10116", "10286", "10288", "10394", "10395", "10396", "10401", "10402", "10403", "10045", "10033", "10034", "10041", "11769", "11109", "11110", "11226", "11227", "10197", "10333", "10334", "10335", "10336", "10337", "10340", "10202", "10203", "10204", "10205", "10206", "10821", "9982", "9983", "9995", "9996", "9974", "9975", "9976", "9977", "9978", "9979", "9980", "9981", "10017", "10046", "10047", "10005", "10006", "10124", "10125", "10126", "10292", "10296", "11261", "10121", "10025", "10026", "10035", "10147", "10148", "10341", "10342", "10343", "10137", "10138", "10185", "10186", "10140", "10141", "10190", "10191", "10207", "10208", "10209", "10200", "10257", "10192", "10193", "10194", "10195", "10196", "10305"
  ];
  
  static const Map<String, String> _sportIcons = {
    'Football': '⚽', 'Basketball': '🏀', 'Tennis': '🎾', 'Cricket': '🏏',
    'Hockey': '🏒', 'Rugby Union': '🏉', 'Volleyball': '🏐', 'Netball': '🥅',
    'Default': '🏅',
  };

  Future<Map<String, dynamic>> _getCompetitionMetadata() async {
    if (_cachedMetadata != null) {
      return _cachedMetadata!;
    }
    
    final response = await http.post(
      Uri.parse('$_baseUrl/metadata/'),
      headers: _headers,
      body: json.encode(_initialCompIdsPayload),
    );

    if (response.statusCode == 200) {
      _cachedMetadata = json.decode(response.body);
      return _cachedMetadata!;
    } else {
      throw Exception('Failed to load competition metadata');
    }
  }

  Future<List<Sport>> getSports() async {
    final metadata = await _getCompetitionMetadata();
    final List<dynamic> sportsData = metadata['Sports'] ?? [];
    
    return sportsData
        .map((s) => Sport.fromJson(s, _sportIcons[s['Name']] ?? _sportIcons['Default']!))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<Sport>> getSportsForSacredHeart() async {
    final List<Fixture> fixtures = await getFixtures();
    final Set<String> sacredHeartSportNames = fixtures.map((f) => f.sport).toSet();
    final metadata = await _getCompetitionMetadata();
    final List<dynamic> allSportsData = metadata['Sports'] ?? [];

    final filteredSportsData = allSportsData
        .where((s) => sacredHeartSportNames.contains(s['Name']))
        .toList();

    return filteredSportsData
        .map((s) => Sport.fromJson(s, _sportIcons[s['Name']] ?? _sportIcons['Default']!))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // --- NEW METHOD ---
  Future<List<String>> getTeamsForSport(String sportName) async {
    const String schoolName = "Sacred Heart College (Auckland)";
    final List<Fixture> fixtures = await getFixtures();

    final teams = fixtures
        .where((f) => f.sport == sportName)
        .map((f) => f.homeSchool == schoolName ? f.homeTeam : f.awayTeam)
        .toSet() // Use a Set to get unique team names
        .toList()
      ..sort(); // Sort the list alphabetically

    return teams;
  }

  Future<List<Fixture>> getFixtures({DateTimeRange? dateRange}) async {
    if (_cachedFixtures != null && dateRange == null) {
      return _cachedFixtures!;
    }

    final metadata = await _getCompetitionMetadata();
    
    final List<int> allCompIds = (metadata['Competitions'] as List).map<int>((c) => c['Id']).toList();
    final allGradeIds = (metadata['GradesPerComp'].values as Iterable).expand<dynamic>((e) => e as List).map<int>((g) => g['Id'] as int).toSet().toList();
    final allOrgIds = (metadata['OrgsPerComp'].values as Iterable).expand<dynamic>((e) => e as List).map<int>((o) => o['Id'] as int).toSet().toList();

    final fromDate = (dateRange?.start ?? DateTime.now()).toIso8601String().substring(0, 10);
    final toDate = (dateRange?.end ?? DateTime.now().add(const Duration(days: 20))).toIso8601String().substring(0, 10);

    final payload = {
      "CompIds": allCompIds, "OrgIds": allOrgIds, "GradeIds": allGradeIds,
      "From": "${fromDate}T00:00:00", "To": "${toDate}T23:59:00"
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/fixture/Dates'),
      headers: _headers,
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> decodedData = json.decode(response.body);
      final List<dynamic> fixtureData = decodedData['Fixtures'] as List<dynamic>? ?? [];
      
      const String schoolToFilter = "Sacred Heart College (Auckland)";

      final fixtures = fixtureData
          .where((data) => 
              data['HomeOrgName'] == schoolToFilter || 
              data['AwayOrgName'] == schoolToFilter)
          .map((data) => Fixture.fromJson(data, metadata))
          .toList();

      if (dateRange == null) {
        _cachedFixtures = fixtures;
      }
      
      return fixtures;
    } else {
      throw Exception('Failed to load fixtures');
    }
  }
}

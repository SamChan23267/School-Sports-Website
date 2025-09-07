// lib/services/collegesport_api_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models.dart';
import '../api_exception.dart';

class CollegeSportApiService {
  static final CollegeSportApiService _instance = CollegeSportApiService._internal();
  factory CollegeSportApiService() => _instance;
  CollegeSportApiService._internal();

  static const String _proxyBaseUrl = "https://shc-proxy-server.onrender.com";
  static const String _collegeSportBaseUrl = "$_proxyBaseUrl/collegesport/api/v2/competition/widget";
  
  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  };

  Map<String, dynamic>? _cachedMetadata;
  Map<String, dynamic>? _cachedAvailablePhases;
  List<Fixture>? _cachedFixtures;

  Future<List<Fixture>> getFixtures({DateTimeRange? dateRange}) async {
    try {
      if (_cachedFixtures != null && dateRange == null) {
        return _cachedFixtures!;
      }

      final metadata = await _getMetadata();
      if (metadata['Competitions'].isEmpty) return [];

      final allCompIds = (metadata['Competitions'] as List).map<int>((c) => c['Id']).toList();
      final allGradeIds = (metadata['GradesPerComp'].values as Iterable).expand<dynamic>((e) => e as List).map<int>((g) => g['Id'] as int).toSet().toList();
      final allOrgIds = (metadata['OrgsPerComp'].values as Iterable).expand<dynamic>((e) => e as List).map<int>((o) => o['Id'] as int).toSet().toList();

      final fromDate = (dateRange?.start ?? DateTime.now().subtract(const Duration(days: 30))).toIso8601String().substring(0, 10);
      final toDate = (dateRange?.end ?? DateTime.now().add(const Duration(days: 30))).toIso8601String().substring(0, 10);

      final payload = {
        "CompIds": allCompIds, "OrgIds": allOrgIds, "GradeIds": allGradeIds,
        "From": "${fromDate}T00:00:00", "To": "${toDate}T23:59:00"
      };

      final response = await http.post(
        Uri.parse('$_collegeSportBaseUrl/fixture/Dates'),
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
            .map((data) => Fixture.fromCollegeSportJson(data, metadata))
            .toList();

        if (dateRange == null) _cachedFixtures = fixtures;
        return fixtures;
      } else {
        throw http.ClientException('Failed to load fixtures with status code: ${response.statusCode}');
      }
    } catch (e) {
      print("CollegeSport Fixtures Error: $e");
      throw ApiException('Could not load CollegeSport fixtures. Please check your connection.');
    }
  }

  Future<List<StandingsTable>> getStandings(int competitionId, int gradeId) async {
    try {
      // Fetch the map of all available phases for standings.
      final availablePhases = await _getAvailablePhases();
      // Get the list of phases specifically for our competitionId.
      final phasesForComp = availablePhases[competitionId.toString()] as List<dynamic>?;

      if (phasesForComp == null || phasesForComp.isEmpty) {
        print("No available phases found for competitionId: $competitionId");
        return [];
      }
      
      // Iterate through all available phases for the competition, as standings might be in any of them.
      for (final phase in phasesForComp) {
        final phaseId = phase['Id'];
        if (phaseId == null) continue;

        final payload = {"GradeId": gradeId, "PhaseId": phaseId};

        final response = await http.post(
          Uri.parse('$_collegeSportBaseUrl/standings/Phase'),
          headers: _headers,
          body: json.encode(payload),
        );

        if (response.statusCode == 200) {
          final List<dynamic> decodedData = json.decode(response.body);
          // If the response for this phase contains standings, we've found them.
          if (decodedData.isNotEmpty && (decodedData.first['Standings'] as List).isNotEmpty) {
            print("Found standings in phaseId: $phaseId for gradeId: $gradeId");
            return decodedData.map((tableData) => StandingsTable.fromCollegeSportJson(tableData)).toList();
          }
        } else {
          // Log the error but continue to try the next phase, as this is not a fatal error.
          print('Failed to load standings for phase $phaseId with status code: ${response.statusCode}');
        }
      }
      
      // If we loop through all phases and find no standings, return an empty list.
      return [];
    } catch (e) {
      print("CollegeSport Standings Error: $e");
      throw ApiException('Could not load CollegeSport standings. Please check your connection.');
    }
  }

  Future<Map<String, dynamic>> _getMetadata() async {
    if (_cachedMetadata != null) return _cachedMetadata!;

    final payload = [ "10362", "10180", "10181", "10182", "10183", "10184", "10113", "10114", "10115", "10116", "10286", "10288", "10394", "10395", "10396", "10401", "10402", "10403", "10045", "10033", "10034", "10041", "11769", "11109", "11110", "11226", "11227", "10197", "10333", "10334", "10335", "10336", "10337", "10340", "10202", "10203", "10204", "10205", "10206", "10821", "9982", "9983", "9995", "9996", "9974", "9975", "9976", "9977", "9978", "9979", "9980", "9981", "10017", "10046", "10047", "10005", "10006", "10124", "10125", "10126", "10292", "10296", "11261", "10121", "10025", "10026", "10035", "10147", "10148", "10341", "10342", "10343", "10137", "10138", "10185", "10186", "10140", "10141", "10190", "10191", "10207", "10208", "10209", "10200", "10257", "10192", "10193", "10194", "10195", "10196", "10305" ];
    
    final response = await http.post(
      Uri.parse('$_collegeSportBaseUrl/metadata/'),
      headers: _headers,
      body: json.encode(payload),
    );
    if (response.statusCode == 200) {
      _cachedMetadata = json.decode(response.body);
      return _cachedMetadata!;
    }
    throw http.ClientException('Failed to load CollegeSport metadata.');
  }

  Future<Map<String, dynamic>> _getAvailablePhases() async {
    if (_cachedAvailablePhases != null) return _cachedAvailablePhases!;

    final metadata = await _getMetadata();
    // The API expects a list of competition IDs as strings.
    final allCompIds = (metadata['Competitions'] as List).map<int>((c) => c['Id']).toList();
    final payload = {"CompIds": allCompIds};

    final response = await http.post(
        Uri.parse('$_collegeSportBaseUrl/standings/availablePhases'),
        headers: _headers,
        body: json.encode(payload),
    );

    if (response.statusCode == 200) {
        _cachedAvailablePhases = json.decode(response.body);
        return _cachedAvailablePhases!;
    }
    throw http.ClientException('Failed to load available phases for standings.');
  }
}

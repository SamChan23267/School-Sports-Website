// lib/services/playhq_api_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models.dart';
import '../api_exception.dart';

class PlayHQApiService {
  static final PlayHQApiService _instance = PlayHQApiService._internal();
  factory PlayHQApiService() => _instance;
  PlayHQApiService._internal();

  // --- CONFIGURATION ---
  static const String _apiKey = "65d6d135-a94c-4f7f-ae63-68392c5bca1d";
  static const String _tenant = "nzc";
  static const String _sacredHeartOrgId = "a2aeb720-88f2-4887-94ee-9de630679dc3";
  static const String _baseUrl = "https://api.playhq.com/v1";

  static final Map<String, String> _headers = {
    "x-api-key": _apiKey,
    "x-phq-tenant": _tenant,
    "Accept": "application/json",
    'User-Agent': 'Flutter Sports Fixtures App/1.0',
  };

  List<Map<String, dynamic>>? _cachedTeams;

  // --- PUBLIC METHODS ---

  Future<List<String>> getTeamNames() async {
    try {
      final teams = await _fetchAllSacredHeartTeams();
      final teamNames = teams.map((team) => team['name'] as String).toSet().toList();
      teamNames.sort();
      return teamNames;
    } catch (e) {
      print("PlayHQ getTeamNames Error: $e");
      throw ApiException('Could not load Cricket teams. Please check your connection and try again.');
    }
  }

  Future<List<Fixture>> getFixturesForTeam(String teamName) async {
    try {
      final allTeams = await _fetchAllSacredHeartTeams();
      
      final team = allTeams.firstWhere(
        (t) => t['name'] == teamName,
        orElse: () => {},
      );

      if (team.isEmpty || team['id'] == null) {
        throw ApiException("Could not find details for team '$teamName'");
      }

      final teamId = team['id'];
      final fixturesData = await _fetchFixtureForTeam(teamId);
      return fixturesData.map((fix) => Fixture.fromPlayHQJson(fix)).toList();
    } catch (e) {
       print("PlayHQ getFixturesForTeam Error: $e");
       throw ApiException('Could not load fixtures for $teamName. Please check your connection.');
    }
  }

  Future<List<Fixture>> getFixtures({DateTimeRange? dateRange}) async {
    try {
      final allTeams = await _fetchAllSacredHeartTeams();

      List<Fixture> allFixtures = [];
      for (final team in allTeams) {
          final teamId = team['id'];
          if (teamId == null) continue;
          
          final fixturesData = await _fetchFixtureForTeam(teamId);
          allFixtures.addAll(fixturesData.map((fix) => Fixture.fromPlayHQJson(fix)));
          
          await Future.delayed(const Duration(milliseconds: 100)); 
      }

      if (dateRange != null) {
        return allFixtures.where((f) {
          if (f.dateTime.isEmpty) return false;
          try {
            final fixtureDate = DateTime.parse(f.dateTime);
            return !fixtureDate.isBefore(dateRange.start) && !fixtureDate.isAfter(dateRange.end);
          } catch (e) {
            return false;
          }
        }).toList();
      }
      return allFixtures;
    } catch (e) {
      print("PlayHQ getAllFixtures Error: $e");
      throw ApiException('Could not load Cricket fixtures. Please check your connection.');
    }
  }
  
  Future<List<StandingsTable>> getStandings(String gradeId) async {
    final url = Uri.parse("https://api.playhq.com/v2/grades/$gradeId/ladder");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return [StandingsTable.fromPlayHQJson(data)];
      } else {
        throw http.ClientException('Failed to load standings with status code: ${response.statusCode}');
      }
    } catch(e) {
      print("PlayHQ Standings Error: $e");
      throw ApiException('Could not load Cricket standings. Please check your connection.');
    }
  }
  
  /// Fetches all Sacred Heart teams across all relevant seasons and caches them.
  Future<List<Map<String, dynamic>>> _fetchAllSacredHeartTeams() async {
    if (_cachedTeams != null) return _cachedTeams!;

    List<Map<String, dynamic>> allSacredHeartTeams = [];
    final allSeasons = await _fetchSeasonsForOrganisation(_sacredHeartOrgId);
    
    final currentYear = DateTime.now().year.toString();

    final targetSeasons = allSeasons.where((season) {
      final seasonName = (season['name'] as String? ?? '').toLowerCase();
      return seasonName.contains(currentYear);
    });

    for (final season in targetSeasons) {
      try {
        final seasonId = season['id'];
        if (seasonId == null) continue;

        final teams = await _fetchTeamsForSeason(seasonId);
        final sacredHeartTeams = teams
            .whereType<Map<String, dynamic>>()
            .where((team) => (team['name'] as String? ?? '').toLowerCase().contains('sacred heart'));
        
        allSacredHeartTeams.addAll(sacredHeartTeams);
        
        await Future.delayed(const Duration(milliseconds: 250));
      } catch (e) {
        print("PlayHQ Error fetching teams for season ${season['id']}: $e");
        // Continue to the next season even if one fails
      }
    }
    
    final Map<String, Map<String, dynamic>> uniqueTeams = {};
    for (var team in allSacredHeartTeams) {
      uniqueTeams[team['id']] = team;
    }
    
    _cachedTeams = uniqueTeams.values.toList();
    if (_cachedTeams!.isEmpty) {
      throw ApiException('No Sacred Heart cricket teams found for the current year.');
    }
    return _cachedTeams!;
  }

  // --- PRIVATE HELPER METHODS ---

  Future<List<dynamic>> _fetchPaginatedData(String url) async {
    List<dynamic> results = [];
    String? cursor;
    while (true) {
      final uri = cursor != null ? Uri.parse("$url?cursor=$cursor") : Uri.parse(url);
      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode >= 400) {
        throw http.ClientException('API request to $uri failed with status ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);
      final List<dynamic> pageData = data['data'] as List<dynamic>? ?? [];
      results.addAll(pageData);

      final Map<String, dynamic> meta = data['metadata'] as Map<String, dynamic>? ?? {};
      if (meta['hasMore'] == true) {
        cursor = meta['nextCursor'];
      } else {
        break;
      }
    }
    return results;
  }

  Future<List<dynamic>> _fetchSeasonsForOrganisation(String orgId) async {
    return _fetchPaginatedData("$_baseUrl/organisations/$orgId/seasons");
  }

  Future<List<dynamic>> _fetchTeamsForSeason(String seasonId) async {
    return _fetchPaginatedData("$_baseUrl/seasons/$seasonId/teams");
  }

  Future<List<dynamic>> _fetchFixtureForTeam(String teamId) async {
    return _fetchPaginatedData("$_baseUrl/teams/$teamId/fixture");
  }
}

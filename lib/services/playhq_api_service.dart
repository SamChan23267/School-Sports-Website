// lib/services/playhq_api_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models.dart';

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

  // --- PUBLIC METHODS ---

  /// Efficiently fetches only the names of Sacred Heart cricket teams.
  Future<List<String>> getTeams() async {
    List<String> teamNames = [];
    try {
      final allSeasons = await _fetchSeasonsForOrganisation(_sacredHeartOrgId);
      
      for (final season in allSeasons) {
        final seasonId = season['id'];
        if (seasonId == null) continue;

        final teams = await _fetchTeamsForSeason(seasonId);
        final sacredHeartTeams = teams
            .where((team) => (team['name'] as String? ?? '').toLowerCase().contains('sacred heart'))
            .map((team) => team['name'] as String)
            .toList();
        
        teamNames.addAll(sacredHeartTeams);
      }
    } catch (e) {
      print("PlayHQ getTeams Error: $e");
    }
    
    // Return unique team names, sorted
    return teamNames.toSet().toList()..sort();
  }

  Future<List<Fixture>> getFixtures({DateTimeRange? dateRange}) async {
    List<Fixture> allFixtures = [];
    try {
      final allSeasons = await _fetchSeasonsForOrganisation(_sacredHeartOrgId);
      
      for (final season in allSeasons) {
        final seasonId = season['id'];
        if (seasonId == null) continue;

        final teams = await _fetchTeamsForSeason(seasonId);
        final sacredHeartTeams = teams.where((team) => (team['name'] as String? ?? '').toLowerCase().contains('sacred heart'));

        for (final team in sacredHeartTeams) {
          final teamId = team['id'];
          if (teamId == null) continue;
          
          final fixtures = await _fetchFixtureForTeam(teamId);
          allFixtures.addAll(fixtures.map((fix) => Fixture.fromPlayHQJson(fix)));
        }
      }
    } catch (e) {
      print("PlayHQ Fixtures Error: $e");
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
  }
  
  Future<List<StandingsTable>> getStandings(String gradeId) async {
    final url = Uri.parse("https://api.playhq.com/v2/grades/$gradeId/ladder");
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return [StandingsTable.fromPlayHQJson(data)];
      }
    } catch(e) {
      print("PlayHQ Standings Error: $e");
    }
    return [];
  }

  // --- PRIVATE HELPER METHODS ---

  Future<List<dynamic>> _fetchPaginatedData(String url) async {
    List<dynamic> results = [];
    String? cursor;
    while (true) {
      final uri = cursor != null ? Uri.parse("$url?cursor=$cursor") : Uri.parse(url);
      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode >= 400) {
        throw http.ClientException(
          'API request to $uri failed with status ${response.statusCode}: ${response.body}',
        );
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
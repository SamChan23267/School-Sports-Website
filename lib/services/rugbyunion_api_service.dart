// lib/services/rugbyunion_api_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models.dart';
import '../api_exception.dart';

class RugbyUnionApiService {
  static final RugbyUnionApiService _instance = RugbyUnionApiService._internal();
  factory RugbyUnionApiService() => _instance;
  RugbyUnionApiService._internal();

  static const String _proxyBaseUrl = "https://shc-proxy-server.onrender.com";
  static const String _rugbyUnionApiUrl = "https://rugby-au-cms.graphcdn.app/";
  
  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  };

  Map<String, dynamic>? _cachedRugbyUnionData;
  String? _cachedRugbyBuildId;

  Future<List<Fixture>> getFixtures({DateTimeRange? dateRange}) async {
    try {
      final sacredHeartEntityId = await _getSacredHeartEntityId();
      if (sacredHeartEntityId == null) return [];

      final fixturesPayload = _getFixturesPayload(sacredHeartEntityId, "fixtures");
      final resultsPayload = _getFixturesPayload(sacredHeartEntityId, "results");

      final responses = await Future.wait([
        http.post(Uri.parse(_rugbyUnionApiUrl), headers: _headers, body: json.encode(fixturesPayload)),
        http.post(Uri.parse(_rugbyUnionApiUrl), headers: _headers, body: json.encode(resultsPayload)),
      ]);

      List<Fixture> allRugbyFixtures = [];
      const String sacredHeartName = "Sacred Heart College";

      for (final response in responses) {
        if (response.statusCode == 200) {
          final decodedData = json.decode(response.body);
          final List<dynamic> fixtureData = decodedData['data']?['getEntityFixturesAndResults'] ?? [];
          
          final sacredHeartFixtures = fixtureData
            .where((data) {
                final homeTeamName = data['homeTeam']?['name'] as String? ?? '';
                final awayTeamName = data['awayTeam']?['name'] as String? ?? '';
                return homeTeamName.contains(sacredHeartName) || awayTeamName.contains(sacredHeartName);
            })
            .map((data) => Fixture.fromRugbyUnionJson(data));

          allRugbyFixtures.addAll(sacredHeartFixtures);
        }
      }

      if (dateRange != null) {
        return allRugbyFixtures.where((f) {
          if (f.dateTime.isEmpty) return false;
          try {
            final fixtureDate = DateTime.parse(f.dateTime);
            return !fixtureDate.isBefore(dateRange.start) && !fixtureDate.isAfter(dateRange.end);
          } catch(e) { return false; }
        }).toList();
      }
      
      return allRugbyFixtures;
    } catch (e) {
      print("Rugby Union Fixtures Error: $e");
      throw ApiException('Could not load Rugby Union fixtures. Please check your connection.');
    }
  }

  Future<List<StandingsTable>> getStandings(String competitionId) async {
    final payload = {
      "operationName": "CompLadderQuery",
      "variables": {"comp": {"id": competitionId, "sourceType": "2"}},
      "query": "query CompLadderQuery(\$comp: CompInput) {\n  compLadder(comp: \$comp) {\n    ...LadderCard_ladder\n    __typename\n  }\n}\n\nfragment LadderCard_ladder on Ladder {\n  id\n  hasPools\n  ladderPools {\n    id\n    poolName\n    teams {\n      ...LadderCard_ladderTeam\n      __typename\n    }\n    __typename\n  }\n  sortingOptions\n  overallSort\n  __typename\n}\n\nfragment LadderCard_ladderTeam on LadderTeam {\n  active\n  bonusPoints3T\n  bonusPoints4T\n  bonusPoints7P\n  byes\n  crest\n  id\n  matchWinRatio\n  matchesDrawn\n  matchesLost\n  matchesPlayed\n  matchesWon\n  name\n  numberForfeitsLoss\n  numberForfeitsWin\n  numberOfForfeits\n  pointsADJ\n  pointsAgainst\n  pointsAgainstADJ\n  pointsDifference\n  pointsFor\n  pointsForADJ\n  pointsRatio\n  position\n  scoreRatio\n  totalBonusPoints\n  totalMatchPoints\n  totalTries\n  tryDifference\n  __typename\n}"
    };

    try {
      final response = await http.post(
        Uri.parse(_rugbyUnionApiUrl),
        headers: _headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        final ladderData = decodedData['data']?['compLadder'];
        if (ladderData != null) {
          return [StandingsTable.fromRugbyUnionJson(ladderData)];
        }
      } else {
        throw http.ClientException('Failed to load standings with status code: ${response.statusCode}');
      }
    } catch (e) {
      print("Rugby Union Standings Error: $e");
      throw ApiException('Could not load Rugby Union standings. Please check your connection.');
    }
    return [];
  }

  Future<int?> _getSacredHeartEntityId() async {
    final rugbyData = await _getRugbyUnionData();
    final clubs = rugbyData['pageProps']?['clubs'] as List<dynamic>? ?? [];
    final sacredHeartClub = clubs.firstWhere((c) => c['name'] == 'Sacred Heart College', orElse: () => null);
    if (sacredHeartClub == null) return null;
    return int.tryParse(sacredHeartClub['id'] ?? '');
  }

  Future<String> _getRugbyUnionBuildId() async {
    if (_cachedRugbyBuildId != null) return _cachedRugbyBuildId!;

    final url = Uri.parse("$_proxyBaseUrl/aucklandrugby/fixtures-and-results");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final body = response.body;
        final pattern = RegExp(r'"buildId":"([^"]+)"');
        final match = pattern.firstMatch(body);
        if (match != null && match.group(1) != null) {
          _cachedRugbyBuildId = match.group(1);
          print('Successfully fetched new Rugby Union Build ID: $_cachedRugbyBuildId');
          return _cachedRugbyBuildId!;
        }
      }
      throw Exception('Failed to find Rugby Union buildId in HTML response.');
    } catch (e) {
      print('Error fetching Rugby Union build ID: $e');
      return 'EYwFsoHsI7WQjAopi5hIv'; // Fallback
    }
  }

  Future<Map<String, dynamic>> _getRugbyUnionData() async {
    if (_cachedRugbyUnionData != null) return _cachedRugbyUnionData!;
    
    final buildId = await _getRugbyUnionBuildId();
    final rugbyUnionDataUrl = "$_proxyBaseUrl/aucklandrugby/_next/data/$buildId/fixtures-results.json";
    final response = await http.get(Uri.parse(rugbyUnionDataUrl));
    if (response.statusCode == 200) {
      _cachedRugbyUnionData = json.decode(response.body);
      return _cachedRugbyUnionData!;
    }
    throw http.ClientException('Failed to fetch Rugby Union data.');
  }

  Map<String, dynamic> _getFixturesPayload(int entityId, String type) {
    return {
      "operationName": "EntityFixturesAndResults",
      "variables": {"season":"","comps":[],"teams":[],"type": type,"skip":0,"limit":100,"entityId":entityId,"entityType":"club"},
      "query": "query EntityFixturesAndResults(\$entityId: Int, \$entityType: String, \$season: String, \$comps: [CompInput], \$teams: [String], \$type: String, \$skip: Int, \$limit: Int) {\n  getEntityFixturesAndResults(\n    season: \$season\n    comps: \$comps\n    teams: \$teams\n    entityId: \$entityId\n    entityType: \$entityType\n    type: \$type\n    limit: \$limit\n    skip: \$skip\n  ) {\n    ...Fixtures_fixture\n    __typename\n  }\n}\n\nfragment Fixtures_fixture on FixtureItem {\n  id\n  compId\n  compName\n  dateTime\n  group\n  isLive\n  isBye\n  round\n  roundType\n  roundLabel\n  season\n  status\n  venue\n  sourceType\n  matchLabel\n  homeTeam {\n    ...Fixtures_team\n    __typename\n  }\n  awayTeam {\n    ...Fixtures_team\n    __typename\n  }\n  fixtureMeta {\n    ...Fixtures_meta\n    __typename\n  }\n  __typename\n}\n\nfragment Fixtures_team on Team {\n  id\n  name\n  teamId\n  score\n  crest\n  __typename\n}\n\nfragment Fixtures_meta on Fixture {\n  id\n  ticketURL\n  ticketsAvailableDate\n  isSoldOut\n  radioURL\n  radioStart\n  radioEnd\n  streamURL\n  streamStart\n  streamEnd\n  broadcastPartners {\n    ...Fixtures_broadcastPartners\n    __typename\n  }\n  __typename\n}\n\nfragment Fixtures_broadcastPartners on BroadcastPartner {\n  id\n  name\n  link\n  photoId\n  __typename\n}"
    };
  }
}

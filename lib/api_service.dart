// lib/api_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'models.dart';

class ApiService {
  // --- Headers ---
  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  };

  // --- PROXY AND API URLS ---
  static const String _proxyBaseUrl = "http://localhost:9999";

  // --- CollegeSport API (via proxy) ---
  static const String _collegeSportBaseUrl = "$_proxyBaseUrl/collegesport/api/v2/competition/widget";
  Map<String, dynamic>? _cachedCollegeSportMetadata;
  List<Fixture>? _cachedCollegeSportFixtures;

  // --- Rugby Union API (partially via proxy) ---
  static const String _rugbyUnionApiUrl = "https://rugby-au-cms.graphcdn.app/"; // Direct, as it has CORS enabled
  Map<String, dynamic>? _cachedRugbyUnionData;
  String? _cachedRugbyBuildId;

  // --- Shared Data ---
  static const Map<String, String> _sportIcons = {
    'Football': '⚽', 'Basketball': '🏀', 'Tennis': '🎾', 'Cricket': '🏏',
    'Hockey': '🏒', 'Rugby Union': '🏉', 'Volleyball': '🏐', 'Netball': '🥅',
    'Default': '🏅',
  };

  // --- PUBLIC METHODS (ORCHESTRATORS) ---

  Future<List<Sport>> getSportsForSacredHeart() async {
    final List<Fixture> allFixtures = await getFixtures();
    final Set<String> sportNames = allFixtures.map((f) => f.sport).toSet();
    
    final List<Sport> sports = sportNames.map((name) {
      final icon = _sportIcons[name] ?? _sportIcons['Default']!;
      final id = name.hashCode; 
      return Sport(id: id, name: name, icon: icon, source: name == 'Rugby Union' ? DataSource.rugbyUnion : DataSource.collegeSport);
    }).toList();

    sports.sort((a, b) => a.name.compareTo(b.name));
    return sports;
  }

  Future<List<Fixture>> getFixtures({DateTimeRange? dateRange}) async {
    final results = await Future.wait([
      _getCollegeSportFixtures(dateRange: dateRange),
      _getRugbyUnionFixtures(dateRange: dateRange),
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
      return _getCollegeSportStandings(int.parse(competitionId), gradeId);
    } else {
      return _getRugbyUnionStandings(competitionId);
    }
  }

  // --- PRIVATE METHODS (COLLEGESPORT) ---

  Future<Map<String, dynamic>> _getCollegeSportMetadata() async {
    if (_cachedCollegeSportMetadata != null) return _cachedCollegeSportMetadata!;

    final payload = [ "10362", "10180", "10181", "10182", "10183", "10184", "10113", "10114", "10115", "10116", "10286", "10288", "10394", "10395", "10396", "10401", "10402", "10403", "10045", "10033", "10034", "10041", "11769", "11109", "11110", "11226", "11227", "10197", "10333", "10334", "10335", "10336", "10337", "10340", "10202", "10203", "10204", "10205", "10206", "10821", "9982", "9983", "9995", "9996", "9974", "9975", "9976", "9977", "9978", "9979", "9980", "9981", "10017", "10046", "10047", "10005", "10006", "10124", "10125", "10126", "10292", "10296", "11261", "10121", "10025", "10026", "10035", "10147", "10148", "10341", "10342", "10343", "10137", "10138", "10185", "10186", "10140", "10141", "10190", "10191", "10207", "10208", "10209", "10200", "10257", "10192", "10193", "10194", "10195", "10196", "10305" ];
    
    try {
      final response = await http.post(
        Uri.parse('$_collegeSportBaseUrl/metadata/'),
        headers: _headers,
        body: json.encode(payload),
      );
      if (response.statusCode == 200) {
        _cachedCollegeSportMetadata = json.decode(response.body);
        return _cachedCollegeSportMetadata!;
      }
    } catch (e) {
      print("CollegeSport Metadata Error: $e");
    }
    return {'Sports': [], 'Competitions': [], 'GradesPerComp': {}, 'OrgsPerComp': {}};
  }

  Future<List<Fixture>> _getCollegeSportFixtures({DateTimeRange? dateRange}) async {
    if (_cachedCollegeSportFixtures != null && dateRange == null) {
      return _cachedCollegeSportFixtures!;
    }

    final metadata = await _getCollegeSportMetadata();
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

    try {
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

        if (dateRange == null) _cachedCollegeSportFixtures = fixtures;
        return fixtures;
      }
    } catch (e) {
      print("CollegeSport Fixtures Error: $e");
    }
    return [];
  }

  Future<List<StandingsTable>> _getCollegeSportStandings(int competitionId, int gradeId) async {
    try {
      final metadata = await _getCollegeSportMetadata();
      final phasesForComp = metadata['PhasesPerComp']?[competitionId.toString()] as List<dynamic>?;

      if (phasesForComp == null || phasesForComp.isEmpty) {
         return [];
      }
      
      final phaseId = phasesForComp.first['Id'];

      final payload = {"GradeId": gradeId, "PhaseId": phaseId};

      final response = await http.post(
        Uri.parse('$_collegeSportBaseUrl/standings/Phase'),
        headers: _headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        final List<dynamic> decodedData = json.decode(response.body);
        return decodedData.map((tableData) => StandingsTable.fromCollegeSportJson(tableData)).toList();
      }
    } catch (e) {
      print("CollegeSport Standings Error: $e");
    }
    return [];
  }

  // --- PRIVATE METHODS (RUGBY UNION) ---

  Future<String> _getRugbyUnionBuildId() async {
    if (_cachedRugbyBuildId != null) return _cachedRugbyBuildId!;

    final url = Uri.parse("$_proxyBaseUrl/aucklandrugby/fixtures-and-results");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final body = response.body;
        // Use a regex to find the buildId from the __NEXT_DATA__ script tag
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
      // Fallback to the last known working ID as a last resort
      return 'EYwFsoHsI7WQjAopi5hIv';
    }
  }

  Future<Map<String, dynamic>> _getRugbyUnionData() async {
    if (_cachedRugbyUnionData != null) return _cachedRugbyUnionData!;
    try {
      final buildId = await _getRugbyUnionBuildId();
      final rugbyUnionDataUrl = "$_proxyBaseUrl/aucklandrugby/_next/data/$buildId/fixtures-results.json";
      final response = await http.get(Uri.parse(rugbyUnionDataUrl));
      if (response.statusCode == 200) {
        _cachedRugbyUnionData = json.decode(response.body);
        return _cachedRugbyUnionData!;
      }
    } catch (e) {
      print("Rugby Union Data Error: $e");
    }
    return {'pageProps': {'competitions': [], 'clubs': []}};
  }

  Future<List<Fixture>> _getRugbyUnionFixtures({DateTimeRange? dateRange}) async {
    final rugbyData = await _getRugbyUnionData();
    final clubs = rugbyData['pageProps']?['clubs'] as List<dynamic>? ?? [];
    final sacredHeartClub = clubs.firstWhere((c) => c['name'] == 'Sacred Heart College', orElse: () => null);

    if (sacredHeartClub == null) return [];

    final entityId = int.tryParse(sacredHeartClub['id'] ?? '');
    if (entityId == null) return [];

    final fixturesPayload = {
      "operationName": "EntityFixturesAndResults",
      "variables": {"season":"","comps":[],"teams":[],"type":"fixtures","skip":0,"limit":100,"entityId":entityId,"entityType":"club"},
      "query": "query EntityFixturesAndResults(\$entityId: Int, \$entityType: String, \$season: String, \$comps: [CompInput], \$teams: [String], \$type: String, \$skip: Int, \$limit: Int) {\n  getEntityFixturesAndResults(\n    season: \$season\n    comps: \$comps\n    teams: \$teams\n    entityId: \$entityId\n    entityType: \$entityType\n    type: \$type\n    limit: \$limit\n    skip: \$skip\n  ) {\n    ...Fixtures_fixture\n    __typename\n  }\n}\n\nfragment Fixtures_fixture on FixtureItem {\n  id\n  compId\n  compName\n  dateTime\n  group\n  isLive\n  isBye\n  round\n  roundType\n  roundLabel\n  season\n  status\n  venue\n  sourceType\n  matchLabel\n  homeTeam {\n    ...Fixtures_team\n    __typename\n  }\n  awayTeam {\n    ...Fixtures_team\n    __typename\n  }\n  fixtureMeta {\n    ...Fixtures_meta\n    __typename\n  }\n  __typename\n}\n\nfragment Fixtures_team on Team {\n  id\n  name\n  teamId\n  score\n  crest\n  __typename\n}\n\nfragment Fixtures_meta on Fixture {\n  id\n  ticketURL\n  ticketsAvailableDate\n  isSoldOut\n  radioURL\n  radioStart\n  radioEnd\n  streamURL\n  streamStart\n  streamEnd\n  broadcastPartners {\n    ...Fixtures_broadcastPartners\n    __typename\n  }\n  __typename\n}\n\nfragment Fixtures_broadcastPartners on BroadcastPartner {\n  id\n  name\n  link\n  photoId\n  __typename\n}"
    };
    final resultsPayload = {
      "operationName": "EntityFixturesAndResults",
      "variables": {"season":"","comps":[],"teams":[],"type":"results","skip":0,"limit":100,"entityId":entityId,"entityType":"club"},
      "query": "query EntityFixturesAndResults(\$entityId: Int, \$entityType: String, \$season: String, \$comps: [CompInput], \$teams: [String], \$type: String, \$skip: Int, \$limit: Int) {\n  getEntityFixturesAndResults(\n    season: \$season\n    comps: \$comps\n    teams: \$teams\n    entityId: \$entityId\n    entityType: \$entityType\n    type: \$type\n    limit: \$limit\n    skip: \$skip\n  ) {\n    ...Fixtures_fixture\n    __typename\n  }\n}\n\nfragment Fixtures_fixture on FixtureItem {\n  id\n  compId\n  compName\n  dateTime\n  group\n  isLive\n  isBye\n  round\n  roundType\n  roundLabel\n  season\n  status\n  venue\n  sourceType\n  matchLabel\n  homeTeam {\n    ...Fixtures_team\n    __typename\n  }\n  awayTeam {\n    ...Fixtures_team\n    __typename\n  }\n  fixtureMeta {\n    ...Fixtures_meta\n    __typename\n  }\n  __typename\n}\n\nfragment Fixtures_team on Team {\n  id\n  name\n  teamId\n  score\n  crest\n  __typename\n}\n\nfragment Fixtures_meta on Fixture {\n  id\n  ticketURL\n  ticketsAvailableDate\n  isSoldOut\n  radioURL\n  radioStart\n  radioEnd\n  streamURL\n  streamStart\n  streamEnd\n  broadcastPartners {\n    ...Fixtures_broadcastPartners\n    __typename\n  }\n  __typename\n}\n\nfragment Fixtures_broadcastPartners on BroadcastPartner {\n  id\n  name\n  link\n  photoId\n  __typename\n}"
    };

    try {
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
          try {
            final fixtureDate = DateTime.parse(f.dateTime);
            return fixtureDate.isAfter(dateRange.start.subtract(const Duration(days: 1))) && fixtureDate.isBefore(dateRange.end.add(const Duration(days: 1)));
          } catch(e) {
            return false;
          }
        }).toList();
      }
      
      return allRugbyFixtures;

    } catch (e) {
      print("Rugby Union Fixtures Error: $e");
    }
    return [];
  }

  Future<List<StandingsTable>> _getRugbyUnionStandings(String competitionId) async {
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
      }
    } catch (e) {
      print("Rugby Union Standings Error: $e");
    }
    return [];
  }
}

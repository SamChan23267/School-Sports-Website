// lib/models.dart

enum DataSource { collegeSport, rugbyUnion }

class Fixture {
  final String competitionId;
  final int? gradeId;
  final String sport;
  final String competition;
  final String dateTime;
  final String venue;
  final String homeTeam;
  final String awayTeam;
  final String homeSchool;
  final String awaySchool;
  final String? homeOrgLogo;
  final String? awayOrgLogo;
  final bool premier;
  final double? lat;
  final double? lng;
  final String? homeScore;
  final String? awayScore;
  final int resultStatus;
  final DataSource source;

  Fixture({
    required this.competitionId,
    this.gradeId,
    required this.sport,
    required this.competition,
    required this.dateTime,
    required this.venue,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeSchool,
    required this.awaySchool,
    this.homeOrgLogo,
    this.awayOrgLogo,
    required this.premier,
    this.lat,
    this.lng,
    this.homeScore,
    this.awayScore,
    required this.resultStatus,
    required this.source,
  });

  factory Fixture.fromCollegeSportJson(Map<String, dynamic> json, Map<String, dynamic> metadata) {
    final int sportId = json['SportId'] ?? 0;
    final sports = metadata['Sports'] as List<dynamic>;
    final sportMeta = sports.firstWhere(
      (s) => s['Id'] == sportId,
      orElse: () => {'Name': 'Unknown Sport'},
    );
    final String sportName = sportMeta['Name'];

    final gradeName = json['GradeName'] as String? ?? '';
    final sectionName = json['SectionName'] as String? ?? '';
    final roundName = json['RoundName'] as String? ?? '';
    
    final competitionParts = [gradeName, sectionName, roundName]
        .where((part) => part.isNotEmpty && part != "N/A")
        .toList();
    final fullCompetitionName = competitionParts.join(' - ');

    final homeTeamName = json['HomeTeamName'] ?? 'TBC';
    final awayTeamName = json['AwayTeamName'] ?? 'TBC';

    final isPremier = (json['CompetitionName'] as String? ?? '').toLowerCase().contains('premier') ||
                      gradeName.toLowerCase().contains('premier') ||
                      homeTeamName.toLowerCase().contains('premier') ||
                      awayTeamName.toLowerCase().contains('premier');

    String? homeLogo = json['HomeOrgLogo'];
    if (homeLogo != null && homeLogo.isNotEmpty) {
      homeLogo = "https://sportsgroundproduction.blob.core.windows.net/cms/${homeLogo.split('?')[0]}";
    }
    String? awayLogo = json['AwayOrgLogo'];
    if (awayLogo != null && awayLogo.isNotEmpty) {
      awayLogo = "https://sportsgroundproduction.blob.core.windows.net/cms/${awayLogo.split('?')[0]}";
    }

    return Fixture(
      competitionId: (json['CompId'] ?? 0).toString(),
      gradeId: json['GradeId'] ?? 0,
      sport: sportName,
      competition: fullCompetitionName.isNotEmpty ? fullCompetitionName : "Competition details not available",
      dateTime: json['From'] ?? '',
      venue: json['VenueName'] ?? 'TBC',
      homeTeam: homeTeamName,
      awayTeam: awayTeamName,
      homeSchool: json['HomeOrgName'] ?? '',
      awaySchool: json['AwayOrgName'] ?? '',
      homeOrgLogo: homeLogo,
      awayOrgLogo: awayLogo,
      premier: isPremier,
      lat: json['LocationLat'],
      lng: json['LocationLng'],
      homeScore: json['HomeScore'],
      awayScore: json['AwayScore'],
      resultStatus: json['ResultStatus'] ?? 0,
      source: DataSource.collegeSport,
    );
  }

  factory Fixture.fromRugbyUnionJson(Map<String, dynamic> json) {
    const String sacredHeartName = "Sacred Heart College";
    final homeTeamName = json['homeTeam']?['name'] ?? 'TBC';
    final awayTeamName = json['awayTeam']?['name'] ?? 'TBC';

    String homeSchool = homeTeamName;
    String awaySchool = awayTeamName;
    if (homeTeamName.contains(sacredHeartName)) {
        homeSchool = sacredHeartName;
    }
    if (awayTeamName.contains(sacredHeartName)) {
        awaySchool = sacredHeartName;
    }
    
    final bool isPremier = (json['compName'] as String? ?? '').toLowerCase().contains('1a');

    return Fixture(
      competitionId: json['compId'] ?? '',
      gradeId: null,
      sport: 'Rugby Union',
      competition: json['compName'] ?? 'Competition details not available',
      dateTime: json['dateTime'] ?? '',
      venue: json['venue'] ?? 'TBC',
      homeTeam: homeTeamName,
      awayTeam: awayTeamName,
      homeSchool: homeSchool,
      awaySchool: awaySchool,
      homeOrgLogo: json['homeTeam']?['crest'],
      awayOrgLogo: json['awayTeam']?['crest'],
      premier: isPremier,
      lat: null,
      lng: null,
      homeScore: json['homeTeam']?['score']?.toString(),
      awayScore: json['awayTeam']?['score']?.toString(),
      resultStatus: json['status'] == 'Result' ? 1 : 0,
      source: DataSource.rugbyUnion,
    );
  }
}

class Sport {
  final int id;
  final String name;
  final String icon;
  final DataSource source;

  Sport({required this.id, required this.name, required this.icon, required this.source});
}

class StandingsTable {
  final String gradeName;
  final String sectionName;
  final List<Standing> standings;

  StandingsTable({
    required this.gradeName,
    required this.sectionName,
    required this.standings,
  });

  factory StandingsTable.fromCollegeSportJson(Map<String, dynamic> json) {
    var standingsList = json['Standings'] as List;
    List<Standing> standings = standingsList.map((i) => Standing.fromCollegeSportJson(i)).toList();
    return StandingsTable(
      gradeName: json['GradeName'] ?? '',
      sectionName: json['SectionName'] ?? 'Standings',
      standings: standings,
    );
  }

  factory StandingsTable.fromRugbyUnionJson(Map<String, dynamic> json) {
    List<Standing> allStandings = [];
    if (json['ladderPools'] != null) {
      for (var pool in json['ladderPools']) {
        if (pool['teams'] != null) {
          var teamsList = pool['teams'] as List;
          allStandings.addAll(teamsList.map((i) => Standing.fromRugbyUnionJson(i)));
        }
      }
    }
    allStandings.sort((a, b) => a.position.compareTo(b.position));

    return StandingsTable(
      gradeName: '',
      sectionName: json['ladderPools']?[0]?['poolName'] ?? 'Standings',
      standings: allStandings,
    );
  }
}


class Standing {
  final String teamName;
  final int played;
  final int win;
  final int loss;
  final int draw;
  final int byes;
  final int bonus;
  final int pointsFor;
  final int pointsAgainst;
  final int differential;
  final int total;
  final int position;

  Standing({
    required this.teamName,
    required this.played,
    required this.win,
    required this.loss,
    required this.draw,
    required this.byes,
    required this.bonus,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.differential,
    required this.total,
    required this.position,
  });

  factory Standing.fromCollegeSportJson(Map<String, dynamic> json) {
    return Standing(
      teamName: json['TeamName'] ?? '',
      played: json['Played'] ?? 0,
      win: json['Win'] ?? 0,
      loss: json['Loss'] ?? 0,
      draw: json['Draw'] ?? 0,
      byes: json['Byes'] ?? 0,
      bonus: json['Bonus'] ?? 0,
      pointsFor: json['For'] ?? 0,
      pointsAgainst: json['Against'] ?? 0,
      differential: json['Differential'] ?? 0,
      total: json['Total'] ?? 0,
      position: json['Position'] ?? 0,
    );
  }

  factory Standing.fromRugbyUnionJson(Map<String, dynamic> json) {
    return Standing(
      teamName: json['name'] ?? '',
      played: json['matchesPlayed'] ?? 0,
      win: json['matchesWon'] ?? 0,
      loss: json['matchesLost'] ?? 0,
      draw: json['matchesDrawn'] ?? 0,
      byes: json['byes'] ?? 0,
      bonus: json['totalBonusPoints'] ?? 0,
      pointsFor: json['pointsFor'] ?? 0,
      pointsAgainst: json['pointsAgainst'] ?? 0,
      differential: json['pointsDifference'] ?? 0,
      total: json['totalMatchPoints'] ?? 0,
      position: json['position'] ?? 0,
    );
  }
}

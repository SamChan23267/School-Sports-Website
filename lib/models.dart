// lib/models.dart

class Fixture {
  final int gradeId; // Added to help with standings lookup
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


  Fixture({
    required this.gradeId,
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
  });

  factory Fixture.fromJson(Map<String, dynamic> json, Map<String, dynamic> metadata) {
    final int sportId = json['SportId'] ?? 0;
    final sports = metadata['Sports'] as List<dynamic>;
    final sportMeta = sports.firstWhere(
      (s) => s['Id'] == sportId,
      orElse: () => {'Name': 'Unknown Sport'},
    );
    final String sportName = sportMeta['Name'];

    final competitionName = json['CompetitionName'] as String? ?? '';
    final gradeName = json['GradeName'] as String? ?? '';
    final fullCompetitionName = '$competitionName - $gradeName';

    final homeTeamName = json['HomeTeamName'] ?? 'TBC';
    final awayTeamName = json['AwayTeamName'] ?? 'TBC';

    final isPremier = competitionName.toLowerCase().contains('premier') ||
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
      gradeId: json['GradeId'] ?? 0,
      sport: sportName,
      competition: fullCompetitionName,
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
    );
  }
}

class Sport {
  final int id;
  final String name;
  final String icon;

  Sport({required this.id, required this.name, required this.icon});

  factory Sport.fromJson(Map<String, dynamic> json, String icon) {
    return Sport(
      id: json['Id'],
      name: json['Name'],
      icon: icon,
    );
  }
}

// --- NEW MODELS FOR STANDINGS ---

class StandingsTable {
  final String gradeName;
  final String sectionName;
  final List<Standing> standings;

  StandingsTable({
    required this.gradeName,
    required this.sectionName,
    required this.standings,
  });

  factory StandingsTable.fromJson(Map<String, dynamic> json) {
    var standingsList = json['Standings'] as List;
    List<Standing> standings = standingsList.map((i) => Standing.fromJson(i)).toList();
    return StandingsTable(
      gradeName: json['GradeName'],
      sectionName: json['SectionName'],
      standings: standings,
    );
  }
}


class Standing {
  final String teamName;
  final int played;
  final int win;
  final int loss;
  final int draw;
  final int total;

  Standing({
    required this.teamName,
    required this.played,
    required this.win,
    required this.loss,
    required this.draw,
    required this.total,
  });

  factory Standing.fromJson(Map<String, dynamic> json) {
    return Standing(
      teamName: json['TeamName'],
      played: json['Played'],
      win: json['Win'],
      loss: json['Loss'],
      draw: json['Draw'],
      total: json['Total'],
    );
  }
}

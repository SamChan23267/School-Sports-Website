// lib/models.dart

class Fixture {
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

  Fixture({
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
    final sectionName = json['SectionName'] as String? ?? '';
    final roundName = json['RoundName'] as String? ?? '';
    
    final competitionParts = [competitionName, gradeName, sectionName, roundName]
        .where((part) => part.isNotEmpty && part != "N/A")
        .toList();
    final fullCompetitionName = competitionParts.join(' - ');

    final homeTeamName = json['HomeTeamName'] as String? ?? '';
    final awayTeamName = json['AwayTeamName'] as String? ?? '';

    final isPremier = competitionName.toLowerCase().contains('premier') ||
                      gradeName.toLowerCase().contains('premier') ||
                      homeTeamName.toLowerCase().contains('premier') ||
                      awayTeamName.toLowerCase().contains('premier');

    // Construct full logo URLs
    String? homeLogo = json['HomeOrgLogo'];
    if (homeLogo != null && homeLogo.isNotEmpty) {
      homeLogo = "https://sportsgroundproduction.blob.core.windows.net/cms/${homeLogo.split('?')[0]}";
    }
    String? awayLogo = json['AwayOrgLogo'];
    if (awayLogo != null && awayLogo.isNotEmpty) {
      awayLogo = "https://sportsgroundproduction.blob.core.windows.net/cms/${awayLogo.split('?')[0]}";
    }

    return Fixture(
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

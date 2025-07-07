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
    required this.premier,
  });

  factory Fixture.fromJson(Map<String, dynamic> json, Map<String, dynamic> metadata) {
    // Look up the Sport Name using SportId from the metadata
    final int sportId = json['SportId'] ?? 0;
    final sports = metadata['Sports'] as List<dynamic>;
    final sportMeta = sports.firstWhere(
      (s) => s['Id'] == sportId,
      orElse: () => {'Name': 'Unknown Sport'},
    );
    final String sportName = sportMeta['Name'];

    // Construct the full, detailed competition name
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

    return Fixture(
      sport: sportName,
      competition: fullCompetitionName,
      dateTime: json['From'] ?? '', // The API uses 'From' for the date
      venue: json['VenueName'] ?? 'TBC',
      homeTeam: homeTeamName,
      awayTeam: awayTeamName,
      homeSchool: json['HomeOrgName'] ?? '',
      awaySchool: json['AwayOrgName'] ?? '',
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

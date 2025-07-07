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
    // --- FIX: Look up the Sport Name using SportId from metadata ---
    final int sportId = json['SportId'] ?? 0;
    final sports = metadata['Sports'] as List<dynamic>;
    final sportMeta = sports.firstWhere(
      (s) => s['Id'] == sportId,
      orElse: () => {'Name': 'Unknown Sport'},
    );
    final String sportName = sportMeta['Name'];

    // --- FIX: Construct the full, detailed competition name ---
    final competitionName = json['CompetitionName'] as String? ?? '';
    final gradeName = json['GradeName'] as String? ?? '';
    final sectionName = json['SectionName'] as String? ?? '';
    final roundName = json['RoundName'] as String? ?? '';
    
    // Combine the parts, filtering out any empty ones.
    final competitionParts = [competitionName, gradeName, sectionName, roundName]
        .where((part) => part.isNotEmpty)
        .toList();
    final fullCompetitionName = competitionParts.join(' - ');

    final isPremier = competitionName.toLowerCase().contains('premier');

    return Fixture(
      sport: sportName,
      competition: fullCompetitionName,
      dateTime: json['From'] ?? '', // FIX: The API uses 'From' for the date
      venue: json['VenueName'] ?? 'TBC',
      homeTeam: json['HomeTeamName'] ?? 'TBC',
      awayTeam: json['AwayTeamName'] ?? 'TBC',
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

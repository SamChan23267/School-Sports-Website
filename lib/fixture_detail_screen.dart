// lib/fixture_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'models.dart';

class FixtureDetailScreen extends StatelessWidget {
  final Fixture fixture;

  const FixtureDetailScreen({super.key, required this.fixture});

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Date TBC';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      // Using a more detailed format for the detail screen
      return DateFormat('EEEE, d MMMM yyyy, h:mm a').format(dateTime);
    } catch (e) {
      // Return original string if parsing fails
      return dateTimeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fixture.sport),
      ),
      // Use a LayoutBuilder to create a responsive layout
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use a wider breakpoint for a better side-by-side experience
          if (constraints.maxWidth > 800) {
            return _buildWideLayout(context);
          } else {
            return _buildNarrowLayout(context);
          }
        },
      ),
    );
  }

  /// Layout for narrow screens (e.g., mobile phones in portrait)
  Widget _buildNarrowLayout(BuildContext context) {
    final hasLocation = fixture.lat != null && fixture.lng != null;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fixture.competition,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _TeamVsWidget(fixture: fixture),
            const SizedBox(height: 16),
            // --- NEW: Premier Chip ---
            if (fixture.premier)
              Chip(
                label: const Text('Premier'),
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.15),
                side: BorderSide.none,
              ),
            // --- END NEW ---
            const SizedBox(height: 24),
            _buildInfoCard(context),
            const SizedBox(height: 24),
            Text("Location Map", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: _buildMap(hasLocation),
            ),
          ],
        ),
      ),
    );
  }

  /// Layout for wide screens (e.g., desktop, tablets in landscape)
  Widget _buildWideLayout(BuildContext context) {
    final hasLocation = fixture.lat != null && fixture.lng != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column for fixture details
          Expanded(
            flex: 3, // Give more space to the details
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fixture.competition,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  // Use larger text and icons for the team display
                  _TeamVsWidget(
                    fixture: fixture,
                    iconSize: 40,
                    textStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  // --- NEW: Premier Chip ---
                  if (fixture.premier)
                    Chip(
                      label: const Text('Premier'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.4),
                      side: BorderSide.none,
                      labelStyle: Theme.of(context).textTheme.bodyLarge,
                    ),
                  // --- END NEW ---
                  const SizedBox(height: 32),
                  _buildInfoCard(context, isWide: true),
                ],
              ),
            ),
          ),
          const SizedBox(width: 32),
          // Right column for the map
          Expanded(
            flex: 2, // Give less space to the map to make it more square
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Location Map", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                // Expanded makes the map fill the remaining vertical space
                Expanded(
                  child: _buildMap(hasLocation),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A shared widget for displaying date and venue information.
  Widget _buildInfoCard(BuildContext context, {bool isWide = false}) {
    final textStyle = isWide
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;

    return Card(
      elevation: isWide ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatDateTime(fixture.dateTime),
                  style: textStyle,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.location_on, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fixture.venue,
                  style: textStyle,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// A shared widget for building the map display.
  Widget _buildMap(bool hasLocation) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: hasLocation
          ? FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(fixture.lat!, fixture.lng!),
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(fixture.lat!, fixture.lng!),
                      width: 80,
                      height: 80,
                      child: Icon(Icons.location_pin,
                          size: 40, color: Colors.red.shade700),
                    ),
                  ],
                ),
              ],
            )
          : Container(
              color: Colors.grey.withOpacity(0.2),
              child: const Center(child: Text('Map data not available')),
            ),
    );
  }
}

class _TeamVsWidget extends StatelessWidget {
  final Fixture fixture;
  final double iconSize;
  final TextStyle? textStyle;

  const _TeamVsWidget({
    required this.fixture,
    this.iconSize = 32, // Default icon size
    this.textStyle,     // Default text style is null, will fallback to theme
  });

  Widget _buildTeamRow(BuildContext context, String school, String team, String? logoUrl) {
    // Use the provided textStyle or fallback to the default theme
    final effectiveTextStyle = textStyle ?? Theme.of(context).textTheme.titleMedium;

    return Row(
      children: [
        if (logoUrl != null && logoUrl.isNotEmpty)
          Image.network(
            logoUrl,
            width: iconSize,
            height: iconSize,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.shield, size: iconSize),
          )
        else
          Icon(Icons.shield, size: iconSize),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '$school: $team',
            style: effectiveTextStyle,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamRow(context, fixture.homeSchool, fixture.homeTeam, fixture.homeOrgLogo),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Text('vs', style: Theme.of(context).textTheme.bodySmall),
        ),
        _buildTeamRow(context, fixture.awaySchool, fixture.awayTeam, fixture.awayOrgLogo),
      ],
    );
  }
}

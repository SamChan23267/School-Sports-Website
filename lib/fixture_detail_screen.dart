// lib/fixture_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models.dart';

class FixtureDetailScreen extends StatefulWidget {
  final Fixture fixture;

  const FixtureDetailScreen({super.key, required this.fixture});

  @override
  State<FixtureDetailScreen> createState() => _FixtureDetailScreenState();
}

class _FixtureDetailScreenState extends State<FixtureDetailScreen> {
  LatLng? _coordinates;
  bool _isLoadingMap = false;

  @override
  void initState() {
    super.initState();
    if (widget.fixture.lat != null && widget.fixture.lng != null) {
      _coordinates = LatLng(widget.fixture.lat!, widget.fixture.lng!);
    } 
    else if (widget.fixture.source == DataSource.rugbyUnion && widget.fixture.venue.isNotEmpty) {
      _fetchCoordinatesForVenue();
    }
  }

  String get _cleanedVenueName {
    return widget.fixture.venue.replaceAll(RegExp(r'\s+\d+\s*\w?$'), '').trim();
  }

  Future<void> _fetchCoordinatesForVenue() async {
    setState(() {
      _isLoadingMap = true;
    });

    final query = Uri.encodeComponent(_cleanedVenueName);
    const aucklandViewbox = '174.45,-37.2,175.15,-36.5';
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1&countrycodes=nz&viewbox=$aucklandViewbox&bounded=1');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'Flutter Sports Fixtures App'});
      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List;
        if (results.isNotEmpty) {
          final firstResult = results.first;
          final lat = double.tryParse(firstResult['lat']);
          final lon = double.tryParse(firstResult['lon']);
          if (lat != null && lon != null) {
            setState(() {
              _coordinates = LatLng(lat, lon);
            });
          }
        }
      }
    } catch (e) {
      print('Failed to fetch coordinates: $e');
    } finally {
      setState(() {
        _isLoadingMap = false;
      });
    }
  }

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'Date TBC';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('EEEE, d MMMM yyyy, h:mm a').format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  Future<void> _launchMapsUrl() async {
    Uri url;
    if (_coordinates != null) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_coordinates!.latitude},${_coordinates!.longitude}');
    } else {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_cleanedVenueName)}, Auckland');
    }
    
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fixture.sport),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return _buildWideLayout(context);
          } else {
            return _buildNarrowLayout(context);
          }
        },
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fixture.competition,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _TeamVsWidget(fixture: widget.fixture),
            const SizedBox(height: 16),
            if (widget.fixture.premier)
              Chip(
                label: const Text('Premier'),
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.15),
                side: BorderSide.none,
              ),
            const SizedBox(height: 24),
            _buildInfoCard(context),
            const SizedBox(height: 24),
            Text("Location Map", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: _buildMap(),
            ),
            const SizedBox(height: 16),
            if (widget.fixture.venue.isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                  onPressed: _launchMapsUrl,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fixture.competition,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  _TeamVsWidget(
                    fixture: widget.fixture,
                    iconSize: 40,
                    textStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (widget.fixture.premier)
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
                  const SizedBox(height: 32),
                  _buildInfoCard(context, isWide: true),
                ],
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Location Map", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildMap(),
                ),
                const SizedBox(height: 16),
                if (widget.fixture.venue.isNotEmpty)
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions),
                      label: const Text('Get Directions'),
                      onPressed: _launchMapsUrl,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                  _formatDateTime(widget.fixture.dateTime),
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
                  widget.fixture.venue,
                  style: textStyle,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.grey.withOpacity(0.2),
        child: _isLoadingMap
            ? const Center(child: CircularProgressIndicator())
            : _coordinates != null
                ? FlutterMap(
                    options: MapOptions(
                      initialCenter: _coordinates!,
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
                            point: _coordinates!,
                            width: 80,
                            height: 80,
                            child: Icon(Icons.location_pin,
                                size: 40, color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ],
                  )
                : const Center(child: Text('Map data not available')),
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
    this.iconSize = 32,
    this.textStyle,
  });

  Widget _buildTeamRow(BuildContext context, String school, String team, String? logoUrl, String? score) {
    final effectiveTextStyle = textStyle ?? Theme.of(context).textTheme.titleMedium;
    final bool isFinished = (fixture.homeScore != null && fixture.homeScore!.isNotEmpty) || 
                            (fixture.awayScore != null && fixture.awayScore!.isNotEmpty) ||
                            fixture.resultStatus != 0;
    final bool isCricket = fixture.source == DataSource.playHQ;

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
            isCricket ? team : '$school: $team',
            style: effectiveTextStyle,
          ),
        ),
        if (isFinished)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(
              score ?? '-',
              style: effectiveTextStyle?.copyWith(fontWeight: FontWeight.bold),
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
        _buildTeamRow(context, fixture.homeSchool, fixture.homeTeam, fixture.homeOrgLogo, fixture.homeScore),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Text('vs', style: Theme.of(context).textTheme.bodySmall),
        ),
        _buildTeamRow(context, fixture.awaySchool, fixture.awayTeam, fixture.awayOrgLogo, fixture.awayScore),
      ],
    );
  }
}

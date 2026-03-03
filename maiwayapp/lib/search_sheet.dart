// lib/search_sheet.dart - replaced with full engine version
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maiwayapp/services/geocoding_service.dart';
import 'package:maiwayapp/utils/geocoding_helper.dart';
import 'package:maiwayapp/city_boundary.dart';

class SearchSheet extends StatefulWidget {
  final Function(LatLng, String, bool) onLocationSelected;
  final Function(bool) onPinModeRequested;
  final LatLng currentLocation;
  final String originAddress;
  final String destinationAddress;

  const SearchSheet({
    super.key,
    required this.onLocationSelected,
    required this.onPinModeRequested,
    required this.currentLocation,
    required this.originAddress,
    required this.destinationAddress,
  });

  @override
  _SearchSheetState createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;

  bool _isSelectingOrigin = true;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  late String _originAddress;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController(text: widget.originAddress);
    _destinationController = TextEditingController(text: widget.destinationAddress);
    _originAddress = widget.originAddress;
    if (_originAddress.isEmpty && !_isFallbackLocation(widget.currentLocation)) {
      _getCurrentLocationAddress();
    }
  }

  bool _isFallbackLocation(LatLng loc) =>
      loc.latitude == 14.5995 && loc.longitude == 120.9842;

  void _debouncedSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchLocation(query);
    });
  }

  Future<void> _getCurrentLocationAddress() async {
    try {
      final address = await GeocodingService.getAddressFromLocation(widget.currentLocation);
      setState(() {
        _originAddress = address;
        _originController.text = address;
      });
    } catch (_) {}
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      // 1) Prefer Google Places Autocomplete when backend has GOOGLE_MAPS_API_KEY
      final googleResults = await GeocodingService.searchGooglePlaces(query);
      if (googleResults.isNotEmpty) {
        final boundary = getManilaBoundary();
        final list = <Map<String, dynamic>>[];
        // Resolve each prediction to lat/lng and only show if inside Manila (hard block)
        final toResolve = googleResults.take(8).toList();
        for (final p in toResolve) {
          final placeId = (p['place_id'] ?? '').toString();
          if (placeId.isEmpty) continue;
          final details = await GeocodingService.getLocationFromPlaceId(placeId);
          if (details == null || !mounted) break;
          final loc = LatLng(details['lat'] as double, details['lng'] as double);
          if (!GeocodingHelper.isWithinManila(loc, boundary)) continue;
          final desc = (p['description'] ?? '').toString();
          list.add({
            'type': 'google',
            'description': desc,
            'place_id': placeId,
            'name': desc,
            'address': desc,
            'location': loc,
            'formatted_address': (details['formatted_address'] ?? desc).toString(),
          });
        }
        if (!mounted) return;
        setState(() {
          _searchResults = list;
          _isSearching = false;
        });
        return;
      }

      // 2) Fallback: Mapbox places + Manila landmarks
      final placeResults = await GeocodingService.searchPlaces(query);
      final landmarkResults = await GeocodingService.searchLandmarks(query);

      final boundary = getManilaBoundary();
      final filteredPlaces = placeResults
          .where((p) {
            final name = (p['name'] ?? '').toString().trim();
            final latLng = LatLng(p['latitude'] ?? 0.0, p['longitude'] ?? 0.0);
            final inside = GeocodingHelper.isWithinManila(latLng, boundary);
            return name.isNotEmpty && inside;
          })
          .map((p) => {
                'type': 'address',
                'name': p['name'],
                'address': p['name'],
                'location': LatLng(p['latitude'] ?? 0.0, p['longitude'] ?? 0.0),
                'description': p['name'],
              })
          .toList();

      final filteredLandmarks = landmarkResults
          .where((p) {
            final latLng = LatLng(p['latitude'] ?? 0.0, p['longitude'] ?? 0.0);
            return GeocodingHelper.isWithinManila(latLng, boundary);
          })
          .map((p) => {
                'type': 'address',
                'name': p['name'],
                'address': p['name'],
                'location': LatLng(p['latitude'] ?? 0.0, p['longitude'] ?? 0.0),
                'description': p['name'],
              })
          .toList();

      final seen = <String>{};
      final all = [
        ...filteredLandmarks,
        ...filteredPlaces,
      ].where((item) {
        final key = '${item['name']}|${item['location'].latitude}|${item['location'].longitude}';
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      }).toList();

      setState(() {
        _searchResults = all;
        _isSearching = false;
      });
    } catch (_) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _selectLocation(Map<String, dynamic> res) async {
    LatLng loc;
    String addr;

    if (res['location'] != null && res['location'] is LatLng) {
      // Pre-resolved (Google/fallback results already filtered to Manila)
      loc = res['location'] as LatLng;
      addr = (res['formatted_address'] ?? res['description'] ?? '').toString();
    } else if (res['place_id'] != null && (res['place_id'] as String).isNotEmpty) {
      setState(() => _isSearching = true);
      final details = await GeocodingService.getLocationFromPlaceId(res['place_id'] as String);
      setState(() => _isSearching = false);
      if (details == null || !mounted) return;
      loc = LatLng(details['lat'] as double, details['lng'] as double);
      addr = (details['formatted_address'] ?? res['description'] ?? '').toString();
    } else {
      loc = res['location'] as LatLng;
      addr = (res['description'] ?? '').toString();
    }

    // Enforce red border (e.g. pin or current location can still be outside Manila)
    if (!GeocodingHelper.isWithinManila(loc, getManilaBoundary())) {
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: const Text('Location outside Manila'),
            content: const Text(
              'Please choose a location within Manila (red border on map).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (_isSelectingOrigin) {
      setState(() {
        _originAddress = addr;
        _originController.text = addr;
      });
      widget.onLocationSelected(loc, addr, true);
    } else {
      setState(() => _destinationController.text = addr);
      widget.onLocationSelected(loc, addr, false);
    }
    setState(() => _searchResults = []);
  }

  void _useCurrentLocation() {
    if (_isSelectingOrigin) {
      widget.onLocationSelected(widget.currentLocation, _originAddress, true);
    } else {
      setState(() => _destinationController.text = _originAddress);
      widget.onLocationSelected(widget.currentLocation, _originAddress, false);
    }
    setState(() => _searchResults = []);
  }

  void _pinLocationOnMap() => widget.onPinModeRequested(_isSelectingOrigin);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Gradient Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6699CC), Color(0xFF4A7BA7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6699CC).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.explore,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MAIWAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                        Text(
                          'Navigate Manila',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Where would you like to go?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Input Card
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6699CC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF6699CC).withOpacity(0.3), width: 3),
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF6699CC), Colors.grey[300]!],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red[200]!, width: 3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _originController,
                        decoration: _dec('Starting point', Icons.trip_origin, _isSelectingOrigin),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        onTap: () => setState(() => _isSelectingOrigin = true),
                        onChanged: (v) {
                          setState(() => _isSelectingOrigin = true);
                          _debouncedSearch(v);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _destinationController,
                        decoration: _dec('Where to?', Icons.location_on, !_isSelectingOrigin),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        onTap: () => setState(() => _isSelectingOrigin = false),
                        onChanged: (v) {
                          setState(() => _isSelectingOrigin = false);
                          _debouncedSearch(v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    Icons.push_pin_outlined,
                    'Pin on Map',
                    const Color(0xFF6699CC),
                    _pinLocationOnMap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    Icons.my_location_rounded,
                    'Current Location',
                    const Color(0xFF34A853),
                    _useCurrentLocation,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_searchResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Search Results',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6699CC).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_searchResults.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6699CC),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Search Results
          if (_isSearching)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6699CC)),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Searching...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _searchResults.length,
                itemBuilder: (ctx, idx) {
                  final r = _searchResults[idx];
                  final isStop = r['type'] == 'stop';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _selectLocation(r),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isStop
                                        ? [Colors.orange[400]!, Colors.orange[600]!]
                                        : [const Color(0xFF6699CC), const Color(0xFF4A7BA7)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isStop ? Colors.orange : const Color(0xFF6699CC)).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isStop ? Icons.directions_bus_rounded : Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r['address'],
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.search_rounded, size: 48, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Search for locations in Manila',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Type an address, landmark, or place',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String title, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon, bool isActive) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
        prefixIcon: Icon(
          icon,
          size: 20,
          color: isActive ? const Color(0xFF6699CC) : Colors.grey[400],
        ),
        filled: true,
        fillColor: isActive ? const Color(0xFF6699CC).withOpacity(0.05) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6699CC), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}

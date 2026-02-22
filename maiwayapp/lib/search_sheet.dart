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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              bottom: 10,
            ),
            color: const Color(0xFF6699CC),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MAIWAY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                    Container(width: 2, height: 40, color: Colors.grey[300]),
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _originController,
                        decoration: _dec('Where you start'),
                        onTap: () => setState(() => _isSelectingOrigin = true),
                        onChanged: (v) {
                          setState(() => _isSelectingOrigin = true);
                          _debouncedSearch(v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _destinationController,
                        decoration: _dec('Where to?'),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.location_pin, color: Colors.grey[600]),
                  title: const Text('Pin location on Map'),
                  onTap: _pinLocationOnMap,
                ),
                ListTile(
                  leading: const Icon(Icons.my_location, color: Colors.blue),
                  title: const Text('Use current location'),
                  onTap: _useCurrentLocation,
                ),
              ],
            ),
          ),
          if (_isSearching)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (ctx, idx) {
                  final r = _searchResults[idx];
                  return ListTile(
                    leading: Icon(
                      r['type'] == 'stop' ? Icons.directions_bus : Icons.location_on,
                      color: r['type'] == 'stop' ? Colors.orange : Colors.grey[600],
                    ),
                    title: Text(r['name']),
                    subtitle: Text(r['address']),
                    onTap: () => _selectLocation(r),
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
                    Icon(Icons.search, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Search for locations', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}

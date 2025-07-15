// lib/search_sheet.dart - replaced with full engine version
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
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
  late String _destinationAddress;

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController(text: widget.originAddress);
    _destinationController = TextEditingController(text: widget.destinationAddress);
    _originAddress = widget.originAddress;
    _destinationAddress = widget.destinationAddress;
    if (_originAddress.isEmpty && !_isFallbackLocation(widget.currentLocation)) {
      _getCurrentLocationAddress();
    }
  }

  bool _isFallbackLocation(LatLng loc) =>
      loc.latitude == 14.5995 && loc.longitude == 120.9842;

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
      // 1) Generic places via Nominatim / geocoding service
      final placeResults = await GeocodingService.searchPlaces(query);
      // 2) Manila landmarks from the bundled list
      final landmarkResults = await GeocodingService.searchLandmarks(query);

      // Convert place & landmark results into a common map format
      final filteredPlaces = placeResults
          .where((p) {
            final name = (p['name'] ?? '').toString().trim();
            final latLng = LatLng(p['latitude'] ?? 0.0, p['longitude'] ?? 0.0);
            final inside = GeocodingHelper.isWithinManila(latLng, getManilaBoundary());
            final mentions = name.toLowerCase().contains('manila');
            return name.isNotEmpty && (inside || mentions);
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
          .map((p) => {
                'type': 'address',
                'name': p['name'],
                'address': p['name'],
                'location': LatLng(p['latitude'] ?? 0.0, p['longitude'] ?? 0.0),
                'description': p['name'],
              })
          .toList();

      // Merge and deduplicate results
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

  void _selectLocation(Map<String, dynamic> res) {
    final loc = res['location'] as LatLng;
    final addr = res['description'] as String;
    if (_isSelectingOrigin) {
      setState(() {
        _originAddress = addr;
        _originController.text = addr;
      });
      widget.onLocationSelected(loc, addr, true);
    } else {
      setState(() {
        _destinationAddress = addr;
        _destinationController.text = addr;
      });
      widget.onLocationSelected(loc, addr, false);
    }
    setState(() => _searchResults = []);
  }

  void _useCurrentLocation() {
    if (_isSelectingOrigin) {
      widget.onLocationSelected(widget.currentLocation, _originAddress, true);
    } else {
      setState(() {
        _destinationController.text = _originAddress;
        _destinationAddress = _originAddress;
      });
      widget.onLocationSelected(widget.currentLocation, _originAddress, false);
    }
    setState(() => _searchResults = []);
  }

  void _pinLocationOnMap() => widget.onPinModeRequested(_isSelectingOrigin);

  void _swap() {
    setState(() {
      final tempAddr = _originAddress;
      final tempCtrl = _originController.text;
      _originAddress = _destinationAddress;
      _originController.text = _destinationController.text;
      _destinationAddress = tempAddr;
      _destinationController.text = tempCtrl;
    });
  }

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
                          _searchLocation(v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _destinationController,
                        decoration: _dec('Where to?'),
                        onTap: () => setState(() => _isSelectingOrigin = false),
                        onChanged: (v) {
                          setState(() => _isSelectingOrigin = false);
                          _searchLocation(v);
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_vert, color: Colors.blue),
                  onPressed: _swap,
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
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'services/geocoding_service.dart';
import 'routing_service.dart';
import 'utils/geocoding_helper.dart';
import 'city_boundary.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchSheet extends StatefulWidget {
  final Function(LatLng, String, bool) onLocationSelected;
  final Function(bool) onPinModeRequested;
  final LatLng currentLocation;
  final String originAddress;
  final String destinationAddress;

  SearchSheet({
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
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  
  bool _isSelectingOrigin = true;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _originAddress = '';
  String _destinationAddress = '';

  @override
  void initState() {
    super.initState();
    _originController.text = widget.originAddress;
    _destinationController.text = widget.destinationAddress;
    _originAddress = widget.originAddress;
    _destinationAddress = widget.destinationAddress;
    if (_originAddress.isEmpty && !_isFallbackLocation(widget.currentLocation)) {
      _getCurrentLocationAddress();
    }
  }

  bool _isFallbackLocation(LatLng loc) {
    return loc.latitude == 14.5995 && loc.longitude == 120.9842;
  }

  Future<void> _getCurrentLocationAddress() async {
    try {
      final address = await GeocodingService.getAddressFromLocation(widget.currentLocation);
      setState(() {
        _originAddress = address;
        _originController.text = address;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<Map<String, dynamic>> stopResults = await RoutingService.searchStops(query);
      List<Map<String, dynamic>> mapboxResults = await GeocodingService.searchPlaces(query);
      List<Map<String, dynamic>> landmarkResults = await GeocodingService.searchLandmarks(query);

      List<Map<String, dynamic>> filteredStops = stopResults.where((stop) {
        final name = (stop['name'] ?? '').toString().trim();
        return name.isNotEmpty && name.toLowerCase() != 'unknown stop';
      }).map((stop) => {
        'type': 'stop',
        'name': stop['name'],
        'address': stop['address'] ?? '',
        'location': LatLng(stop['lat'] ?? 0.0, stop['lng'] ?? 0.0),
        'description': stop['name'],
      }).toList();

      List<Map<String, dynamic>> filteredMapbox = mapboxResults.where((place) {
        final name = (place['name'] ?? '').toString().trim();
        LatLng latLng = LatLng(place['latitude'] ?? 0.0, place['longitude'] ?? 0.0);
        final isInPolygon = GeocodingHelper.isWithinManila(latLng, getManilaBoundary());
        final mentionsManila = name.toLowerCase().contains('manila');
        return name.isNotEmpty && name.toLowerCase() != 'unknown location' && (isInPolygon || mentionsManila);
      }).map((place) => {
        'type': 'address',
        'name': place['name'],
        'address': place['name'],
        'location': LatLng(place['latitude'] ?? 0.0, place['longitude'] ?? 0.0),
        'description': place['name'],
      }).toList();

      List<Map<String, dynamic>> filteredLandmarks = landmarkResults.map((place) => {
        'type': 'address',
        'name': place['name'],
        'address': place['name'],
        'location': LatLng(place['latitude'] ?? 0.0, place['longitude'] ?? 0.0),
        'description': place['name'],
      }).toList();

      Set<String> seen = {};
      List<Map<String, dynamic>> allResults = [
        ...filteredLandmarks,
        ...filteredMapbox,
        ...filteredStops,
      ].where((item) {
        final key = '${item['name']}|${item['location'].latitude}|${item['location'].longitude}';
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      }).toList();

      setState(() {
        _searchResults = allResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectLocation(Map<String, dynamic> result) {
    LatLng location = result['location'];
    String address = result['description'];
    
    if (_isSelectingOrigin) {
      setState(() {
        _originAddress = address;
        _originController.text = address;
      });
      widget.onLocationSelected(location, address, true);
    } else {
      setState(() {
        _destinationAddress = address;
        _destinationController.text = address;
      });
      widget.onLocationSelected(location, address, false);
    }
    
    setState(() {
      _searchResults = [];
    });
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
    
    setState(() {
      _searchResults = [];
    });
  }

  void _pinLocationOnMap() {
    widget.onPinModeRequested(_isSelectingOrigin);
  }

  void _swapLocations() {
    setState(() {
      String tempAddress = _originAddress;
      String tempController = _originController.text;
      
      _originAddress = _destinationAddress;
      _originController.text = _destinationController.text;
      
      _destinationAddress = tempAddress;
      _destinationController.text = tempController;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF6699CC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'MAIWAY',
                  style: GoogleFonts.notoSerif(
                    fontSize: 24,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'SEARCH',
                      style: GoogleFonts.notoSerif(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(0xFF003366),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 40,
                          color: Colors.grey[300],
                        ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          TextField(
                            controller: _originController,
                            decoration: InputDecoration(
                              hintText: 'Where you start',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: const Color(0xFF6699CC), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onTap: () {
                              setState(() {
                                _isSelectingOrigin = true;
                              });
                            },
                            onChanged: (value) {
                              setState(() {
                                _isSelectingOrigin = true;
                              });
                              _searchLocation(value);
                            },
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _destinationController,
                            decoration: InputDecoration(
                              hintText: 'Where to?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: const Color(0xFF6699CC), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onTap: () {
                              setState(() {
                                _isSelectingOrigin = false;
                              });
                            },
                            onChanged: (value) {
                              setState(() {
                                _isSelectingOrigin = false;
                              });
                              _searchLocation(value);
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.swap_vert, color: const Color(0xFF6699CC)),
                      onPressed: _swapLocations,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.location_pin, color: const Color(0xFF6699CC)),
                  title: Text(
                    'Pin location on Map',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _pinLocationOnMap,
                ),
                ListTile(
                  leading: Icon(Icons.my_location, color: const Color(0xFF6699CC)),
                  title: Text(
                    'Use current location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _useCurrentLocation,
                ),
              ],
            ),
          ),
            
          if (_isSearching)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6699CC)),
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> result = _searchResults[index];
                  return ListTile(
                    leading: Icon(
                      result['type'] == 'stop' ? Icons.directions_bus : Icons.location_on,
                      color: result['type'] == 'stop' ? Colors.orange : const Color(0xFF6699CC),
                    ),
                    title: Text(
                      result['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      result['address'],
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    onTap: () => _selectLocation(result),
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
                    Icon(
                      Icons.search,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Search for locations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
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

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}
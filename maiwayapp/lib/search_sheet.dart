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
    
    if (_originAddress.isEmpty) {
      _getCurrentLocationAddress();
    }
  }

  Future<void> _getCurrentLocationAddress() async {
    try {
      final address = await GeocodingService.getAddressFromLocation(widget.currentLocation);
      setState(() {
        _originAddress = address;
        _originController.text = address;
      });
    } catch (e) {
      print('Error getting current location address: $e');
      // Fallback to coordinates
      setState(() {
        _originAddress = 'Current Location (${widget.currentLocation.latitude.toStringAsFixed(4)}, ${widget.currentLocation.longitude.toStringAsFixed(4)})';
        _originController.text = _originAddress;
      });
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
      // First try the routing service for stops
      List<Map<String, dynamic>> stopResults = await RoutingService.searchStops(query);
      
      // Then try OpenCage API for general addresses
      List<Map<String, dynamic>> openCageResults = await GeocodingService.searchPlaces(query);

      // Combine and filter results
      List<Map<String, dynamic>> combinedResults = [];
      
      // Add stop results
      for (var stop in stopResults) {
        combinedResults.add({
          'type': 'stop',
          'name': stop['name'] ?? 'Unknown Stop',
          'address': stop['address'] ?? '',
          'location': LatLng(stop['lat'] ?? 0.0, stop['lng'] ?? 0.0),
          'description': stop['name'] ?? 'Unknown Stop',
        });
      }

      // Add OpenCage results (filter for Manila)
      for (var place in openCageResults) {
        LatLng latLng = LatLng(place['latitude'] ?? 0.0, place['longitude'] ?? 0.0);
        if (GeocodingHelper.isWithinManila(latLng, getManilaBoundary())) {
          combinedResults.add({
            'type': 'address',
            'name': place['name'] ?? 'Unknown Location',
            'address': place['name'] ?? 'Unknown Location',
            'location': latLng,
            'description': place['name'] ?? 'Unknown Location',
          });
        }
      }

      setState(() {
        _searchResults = combinedResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      print('Search error: $e');
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
      ),
      child: Column(
        children: [
          // Blue header, flush to the top, with centered DIRECTIONS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18.0),
            color: const Color(0xFF6699CC),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Center(
                  child: Text(
                    'DIRECTIONS',
                    style: GoogleFonts.notoSerif(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Origin and Destination inputs
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
                            color: Colors.blue,
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
                            color: Colors.grey[400],
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
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
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
                    borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
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
                      icon: Icon(Icons.swap_vert, color: Colors.blue),
                      onPressed: _swapLocations,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick actions
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ListTile(
                  leading: Icon(Icons.location_pin, color: Colors.grey[600]),
                  title: Text('Pin location on Map'),
                  onTap: _pinLocationOnMap,
                  ),
                  ListTile(
                  leading: Icon(Icons.my_location, color: Colors.blue),
                  title: Text('Use current location'),
                  onTap: _useCurrentLocation,
                  ),
                ],
              ),
            ),
            
          // Search results
          if (_isSearching)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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
                      color: result['type'] == 'stop' ? Colors.orange : Colors.grey[600],
                    ),
                    title: Text(result['name']),
                    subtitle: Text(result['address']),
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
                        fontSize: 16,
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
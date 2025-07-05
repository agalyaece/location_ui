// lib/screens/home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_ui/screens/login/login.dart';
import 'dart:math';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart'; // Import Position type

import '../../services/auth_service.dart';
import '../../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Historical Daily Locations (for the Drawer)
  List<dynamic> _dailyLocations = [];
  DateTime _selectedDate = DateTime.now();

  // Map Controller for the Main Map
  final MapController _mapController = MapController();

  // Live Location Data
  Position? _currentLiveLocation;
  StreamSubscription<Position>? _liveLocationSubscription;

  // Cache for addresses to avoid repeated reverse geocoding
  final Map<String, String> _addressCache = {};

  @override
  void initState() {
    super.initState();
    // Start general location tracking (which now also feeds the live stream)
    LocationService.startLocationTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentLiveLocation != null) {
        _mapController.move(
          LatLng(
            _currentLiveLocation!.latitude,
            _currentLiveLocation!.longitude,
          ),
          14.0,
        );
      }
    });
    // Listen to the live location stream
    _liveLocationSubscription = LocationService.liveLocationStream.listen((
      position,
    ) {
      setState(() {
        _currentLiveLocation = position;
        // Move the map to the live location if it's the first update or if user wants auto-follow
        // You might want a toggle for "follow me" vs. manually pan
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _mapController.camera.zoom < 14.0 ? 14.0 : _mapController.camera.zoom,
        );
      });
    });

    // Fetch initial historical summary for today to populate the sidebar
    _fetchDailySummary(_selectedDate);
  }

  @override
  void dispose() {
    _liveLocationSubscription
        ?.cancel(); // Cancel the live location stream subscription
    // LocationService.stopLocationTracking(); // This is called on logout, not just dispose
    super.dispose();
  }

  // Fetches daily location summary from the backend
  Future<void> _fetchDailySummary(DateTime date) async {
    setState(() {
      _dailyLocations = []; // Clear previous data before fetching new
    });
    final locations = await LocationService.getDailyLocationSummary(date);
    if (locations != null) {
      setState(() {
        _dailyLocations = locations;
      });
      // No need to center the *main* map here, as it's for live location.
      // The _centerMapOnLocations is more for a map inside the drawer, if you had one.
      // If the intent is to recenter the main map on historical data when date changes,
      // you could call it here, but it would override the live location view.
      // For now, it's just about getting the data.
    } else {
      // Show snackbar only if context is still valid
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load location summary for selected date.'),
          ),
        );
      }
    }
  }

  // Centers the map to show all fetched location markers (might be used internally if you add a map to the drawer)
  // For the main map, this will be called when the app starts with historical data,
  // or if explicitly triggered (e.g., a button to "show today's track").
  void _centerMapOnLocations() {
    if (_dailyLocations.isNotEmpty) {
      double minLat = _dailyLocations.first['latitude'];
      double maxLat = _dailyLocations.first['latitude'];
      double minLon = _dailyLocations.first['longitude'];
      double maxLon = _dailyLocations.first['longitude'];

      for (var loc in _dailyLocations) {
        minLat = min(minLat, loc['latitude']);
        maxLat = max(maxLat, loc['latitude']);
        minLon = min(minLon, loc['longitude']);
        maxLon = max(maxLon, loc['longitude']);
      }

      final LatLngBounds bounds = LatLngBounds(
        LatLng(minLat, minLon),
        LatLng(maxLat, maxLon),
      );

      // Add a small padding to the bounds to ensure markers aren't on the edge
      final paddedBounds = LatLngBounds.fromPoints([
        LatLng(minLat - 0.001, minLon - 0.001),
        LatLng(maxLat + 0.001, maxLon + 0.001),
      ]);

      // Move the main map camera to fit these historical points
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: paddedBounds,
          padding: EdgeInsets.only(
            top: 10.0,
            bottom: 10.0,
            left: 10.0,
            right: 10.0,
          ), // Optional padding
        ),
      );
    });
  } else {
    // If no locations, reset map to a default view (e.g., world view or last known live location)
    _mapController.move(
      _currentLiveLocation != null
          ? LatLng(
              _currentLiveLocation!.latitude,
              _currentLiveLocation!.longitude,
            )
          : LatLng(0.0, 0.0),
      _currentLiveLocation != null ? 14.0 : 2.0,
    );
  }
}

  // Opens a date picker to select a date for summary
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchDailySummary(picked); // Fetch data for the new date
    }
  }

  Future<String> _getAddress(double lat, double lon) async {
    final key = '$lat,$lon';
    if (_addressCache.containsKey(key)) {
      return _addressCache[key]!;
    }
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Prioritize street, then subLocality, then locality, etc.
        final addressParts = <String>[];
        if (place.street != null && place.street!.isNotEmpty)
          addressParts.add(place.street!);
        if (place.subLocality != null && place.subLocality!.isNotEmpty)
          addressParts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty)
          addressParts.add(place.locality!);
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty)
          addressParts.add(place.administrativeArea!);
        if (place.country != null && place.country!.isNotEmpty)
          addressParts.add(place.country!);

        final address = addressParts.join(', ');
        if (address.isNotEmpty) {
          _addressCache[key] = address;
          return address;
        }
      }
    } catch (e) {
      print('Error getting address: $e'); // Log the error for debugging
    }
    return "Lat: ${lat.toStringAsFixed(6)}, Lon: ${lon.toStringAsFixed(6)}";
  }

  // Helper to group consecutive locations by lat/lon (for summary in drawer)
  List<Map<String, dynamic>> _groupLocationsByAddress(List<dynamic> locations) {
    if (locations.isEmpty) return [];
    List<Map<String, dynamic>> grouped = [];
    var current = {
      'lat': locations[0]['latitude'],
      'lon': locations[0]['longitude'],
      'from': DateTime.parse(locations[0]['timestamp']).toLocal(),
      'to': DateTime.parse(locations[0]['timestamp']).toLocal(),
      'count': 1,
    };

    for (int i = 1; i < locations.length; i++) {
      final lat = locations[i]['latitude'];
      final lon = locations[i]['longitude'];
      final time = DateTime.parse(locations[i]['timestamp']).toLocal();
      // Consider a small epsilon for float comparison if needed, e.g., (lat - current['lat']).abs() < 0.0001
      if (lat == current['lat'] && lon == current['lon']) {
        current['to'] = time;
        current['count'] = (current['count'] as int) + 1; // Ensure type safety
      } else {
        grouped.add({...current});
        current = {
          'lat': lat,
          'lon': lon,
          'from': time,
          'to': time,
          'count': 1,
        };
      }
    }
    grouped.add({...current});
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    // Determine initial map center and zoom for the main map
    // Based on live location if available, otherwise a default
    final LatLng initialMapCenter =
        _currentLiveLocation != null
            ? LatLng(
              _currentLiveLocation!.latitude,
              _currentLiveLocation!.longitude,
            )
            : LatLng(
              20.5937,
              78.9629,
            ); // Default to India if no live location yet
    final double initialMapZoom =
        _currentLiveLocation != null
            ? 14.0
            : 5.0; // Zoom in for live, out for default

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Location Tracker'),
        leading: Builder(
          // Use Builder to get the correct context for Scaffold.of
          builder:
              (context) => IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {
                  Scaffold.of(context).openDrawer(); // Open the sidebar
                },
              ),
        ),
        actions: [
          // Button to recenter map on live location
          IconButton(
            icon: Icon(Icons.my_location),
            tooltip: 'Center on Live Location',
            onPressed: () {
              if (_currentLiveLocation != null) {
                _mapController.move(
                  LatLng(
                    _currentLiveLocation!.latitude,
                    _currentLiveLocation!.longitude,
                  ),
                  16.0, // Zoom level for current location
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Live location not yet available.')),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.map),
            tooltip: 'View Daily Summary on Map',
            onPressed: () {
              // This button would center the map on the historical daily locations
              _centerMapOnLocations();
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await AuthService.removeToken();
              LocationService.stopLocationTracking();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(), // The new sidebar drawer
      body: Stack(
        // Using Stack to allow placing overlays if needed later
        children: [
          // Main Map View Area for Live Location
          _currentLiveLocation == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Waiting for live location...'),
                    Text(
                      'Ensure location services are enabled and permissions granted.',
                    ),
                  ],
                ),
              )
              : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialMapCenter,
                  initialZoom: initialMapZoom,
                  minZoom: 1.0,
                  maxZoom: 18.0,
                  // Optionally disable panning if you always want it centered on live location
                  // interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.location_ui_app', // Replace with your app's package name
                  ),
                  // Marker for the current live location
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80.0,
                        height: 80.0,
                        point: LatLng(
                          _currentLiveLocation!.latitude,
                          _currentLiveLocation!.longitude,
                        ),
                        child: Tooltip(
                          message:
                              'Your Live Location\nLat: ${_currentLiveLocation!.latitude.toStringAsFixed(6)}\nLon: ${_currentLiveLocation!.longitude.toStringAsFixed(6)}\nTime: ${_currentLiveLocation!.timestamp.toLocal().hour}:${_currentLiveLocation!.timestamp.toLocal().minute.toString().padLeft(2, '0')}',
                          child: Icon(
                            Icons.my_location,
                            color:
                                Colors.red, // Distinct color for live location
                            size: 45.0,
                          ),
                        ),
                      ),
                      // Add markers for daily summary if you want to see them on the main map too
                      // This might clutter the live map, so generally kept separate in drawer view
                    ],
                  ),
                ],
              ),
        ],
      ),
    );
  }

  // NEW: Build the Drawer widget
  Widget _buildDrawer() {
    final groupedLocations = _groupLocationsByAddress(_dailyLocations);

    String formatTime(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Location History',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'View your past tracks',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Summary for: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
          ),
          // Option to view all points on map (This will make the main map jump)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(Icons.map_outlined),
                label: Text('Fit Daily Track on Map'),
                onPressed: () {
                  _centerMapOnLocations(); // Center the *main* map on the daily track
                  Navigator.of(context).pop(); // Close the drawer
                },
              ),
            ),
          ),
          SizedBox(height: 10),
          // Raw Location Points List Title
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              'Raw Location Points',
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            flex: 1, // List takes less vertical space than grouped list
            child:
                _dailyLocations.isEmpty
                    ? Center(child: Text('No raw location data for this day.'))
                    : ListView.builder(
                      itemCount: _dailyLocations.length,
                      itemBuilder: (context, index) {
                        final location = _dailyLocations[index];
                        final timestamp =
                            DateTime.parse(location['timestamp']).toLocal();
                        final lat = location['latitude'];
                        final lon = location['longitude'];

                        return Card(
                          margin: EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 16,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Time: ${formatTime(timestamp)}'),
                                FutureBuilder<String>(
                                  future: _getAddress(lat, lon),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Text('Resolving address...');
                                    }
                                    if (snapshot.hasError ||
                                        !snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return Text(
                                        'Address not found: Lat: ${lat.toStringAsFixed(6)}, Lon: ${lon.toStringAsFixed(6)}',
                                      );
                                    }
                                    return Text(snapshot.data!);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          SizedBox(height: 10),
          // Grouped Locations List Title
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              'Grouped Locations (Places Visited)',
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            flex: 2, // Grouped list takes more vertical space
            child:
                groupedLocations.isEmpty
                    ? Center(
                      child: Text('No grouped location data for this day.'),
                    )
                    : ListView.builder(
                      itemCount: groupedLocations.length,
                      itemBuilder: (context, index) {
                        final group = groupedLocations[index];
                        final lat = group['lat'];
                        final lon = group['lon'];
                        final from = group['from'];
                        final to = group['to'];
                        final count =
                            group['count']; // How many points at this location

                        return Card(
                          margin: EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 16,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'From: ${formatTime(from)} - To: ${formatTime(to)}',
                                ),
                                Text(
                                  'Duration: ${Duration(seconds: to.difference(from).inSeconds).toString().split('.').first}',
                                ),
                                Text('Points Recorded: $count'),
                                FutureBuilder<String>(
                                  future: _getAddress(lat, lon),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Text('Resolving address...');
                                    }
                                    if (snapshot.hasError ||
                                        !snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return Text(
                                        'Address not found: Lat: ${lat.toStringAsFixed(6)}, Lon: ${lon.toStringAsFixed(6)}',
                                      );
                                    }
                                    return Text(snapshot.data!);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

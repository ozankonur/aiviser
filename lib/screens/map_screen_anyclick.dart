
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:aiviser/services/location_service.dart';
import 'package:aiviser/services/places_service.dart';
import 'package:aiviser/services/invitation_service.dart';
import 'package:aiviser/widgets/custom_marker_builder.dart';
import 'package:aiviser/widgets/map_view.dart';
import 'package:aiviser/widgets/place_details_sheet.dart';
import 'package:aiviser/widgets/error_dialog.dart';
import 'package:aiviser/widgets/place_type_list.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:aiviser/services/fcm_token_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final PlacesService _placesService = PlacesService(dotenv.env['PLACE_API_KEY'] ?? '');
  final InvitationService _invitationService = InvitationService();
  final Set<Marker> _markers = {};
  Set<Marker> _eventMarkers = {};

  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  LatLng? _userLocation;
  String _selectedPlaceType = '';
  String _errorMessage = '';
  GoogleMapController? _mapController;
  bool _hasShownLocationModal = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _initializeLocation();
    _subscribeToLocationChanges();
    FCMTokenManager.initializeFirebaseMessaging();
  }

  @override
  void dispose() {
    _locationService.dispose();
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _initializeLocation() async {
    try {
      LatLng? cachedLocation = await _locationService.getLastKnownLocation();
      if (cachedLocation != null) {
        setState(() {
          _userLocation = cachedLocation;
        });
        _zoomToLocation(cachedLocation);
        _loadNearbyEvents(); // Call _loadNearbyEvents with cached location
      }

      final location = await _locationService.getCurrentLocation();
      setState(() {
        _userLocation = location;
      });
      _zoomToLocation(location);
      _loadNearbyEvents(); // Call _loadNearbyEvents again with current location
      _animationController.forward();
    } catch (e) {
      print('Error getting location: $e');
      if (_userLocation == null) {
        _showLocationPermissionModal();
      }
    }
  }

  Future<void> _showLocationPermissionModal() async {
    if (_hasShownLocationModal) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasShownBefore = prefs.getBool('has_shown_location_modal') ?? false;
    if (hasShownBefore) return;

    setState(() {
      _hasShownLocationModal = true;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services'),
          content: const Text(
              'Enable location services for a better app experience. You can change this later in your device settings.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Not Now'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Enable'),
              onPressed: () {
                Navigator.of(context).pop();
                _initializeLocation();
              },
            ),
          ],
        );
      },
    );

    await prefs.setBool('has_shown_location_modal', true);
  }

  void _zoomToLocation(LatLng location) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  void _subscribeToLocationChanges() {
    _locationService.locationStream.listen((newLocation) {
      setState(() {
        _userLocation = newLocation;
        _errorMessage = '';
      });
      _zoomToLocation(newLocation);
      _loadNearbyEvents();
    });
  }

  Future<void> _loadNearbyEvents() async {
    print('Loading nearby events');
    if (_userLocation == null) return;

    final eventMarker = await CustomMarkerBuilder.getCustomMarker('event', context);
    _invitationService.getNearbyEvents(_userLocation!, 10).listen((events) {
      print('Received ${events.length} events');
      if (mounted) {
        setState(() {
          _eventMarkers = events.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final double latitude = data['placeLatitude'] ?? 0.0;
            final double longitude = data['placeLongitude'] ?? 0.0;
            return Marker(
              markerId: MarkerId('event_${doc.id}'),
              position: LatLng(latitude, longitude),
              icon: eventMarker,
              onTap: () => _showPlaceDetails(
                context,
                {
                  'place_id': doc.id,
                  'name': data['placeName'] ?? 'Unnamed Event',
                  'location': LatLng(latitude, longitude),
                  'vicinity': data['placeAddress'] ?? 'No address provided',
                },
                isEventPlace: true,
                eventId: doc.id,
              ),
            );
          }).toSet();
          _updateAllMarkers();
        });
      }
    });
  }

  void _updateAllMarkers() {
    setState(() {
      _markers.addAll(_eventMarkers);
    });
  }

  void _fitMarkersOnMap({bool shouldAdjustCamera = false}) {
    if (_mapController == null || _markers.isEmpty) return;

    if (!shouldAdjustCamera) return; // Early return if we shouldn't adjust the camera

    double southwestLat = 90.0;
    double southwestLng = 180.0;
    double northeastLat = -90.0;
    double northeastLng = -180.0;

    for (Marker marker in _markers) {
      if (marker.position.latitude < southwestLat) southwestLat = marker.position.latitude;
      if (marker.position.longitude < southwestLng) southwestLng = marker.position.longitude;
      if (marker.position.latitude > northeastLat) northeastLat = marker.position.latitude;
      if (marker.position.longitude > northeastLng) northeastLng = marker.position.longitude;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(southwestLat, southwestLng),
      northeast: LatLng(northeastLat, northeastLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
  }

  Future<void> _searchNearbyPlaces(String placeType) async {
    if (_userLocation == null) return;

    setState(() {
      _selectedPlaceType = placeType;
      _markers.clear();
    });

    try {
      final places = await _placesService.searchNearbyPlaces(_userLocation!, placeType);
      await _updatePlaceMarkers(places);
      _fitMarkersOnMap();
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _updatePlaceMarkers(List<Map<String, dynamic>> places) async {
    final customMarker = await CustomMarkerBuilder.getCustomMarker(_selectedPlaceType, context);

    setState(() {
      _markers.clear();
      for (var place in places) {
        _markers.add(
          Marker(
            markerId: MarkerId(place['place_id']),
            position: place['location'],
            infoWindow: InfoWindow(title: place['name']),
            onTap: () => _showPlaceDetails(context, place, isEventPlace: false),
            icon: customMarker,
          ),
        );
      }
    });
  }

  void _clearFiltersAndAdvice() {
    setState(() {
      _selectedPlaceType = '';
      _markers.clear();
    });
    _loadNearbyEvents();
  }

  void _showPlaceDetails(BuildContext context, Map<String, dynamic> place,
      {bool isEventPlace = false, String? eventId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bottomSheetContext) => PlaceDetailsSheet(
        place: place,
        isEventPlace: isEventPlace,
        eventId: eventId,
        userLocation: _userLocation,
        showSnackBar: (String message) {
          Navigator.of(bottomSheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapView(
            userLocation: _userLocation,
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_userLocation != null) {
                _zoomToLocation(_userLocation!);
              }
              _fitMarkersOnMap(shouldAdjustCamera: true);
            },
            onMapTap: _onMapTap,
          ),
          if (_errorMessage.isNotEmpty)
            ErrorDialog(
              errorMessage: _errorMessage,
              onRetry: () {
                setState(() {
                  _errorMessage = '';
                });
                _initializeLocation();
              },
            ),
          PlaceTypeList(
            onPlaceTypeSelected: _searchNearbyPlaces,
            selectedPlaceType: _selectedPlaceType,
            offsetAnimation: _offsetAnimation,
          ),
          if (_selectedPlaceType.isNotEmpty)
            Positioned(
              top: 140,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: _clearFiltersAndAdvice,
                label: const Text('Clear'),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                icon: const Icon(Icons.cancel),
              ),
            ),
        ],
      ),
    );
  }

  void _onMapTap(LatLng tappedPoint) async {
    bool canCreateEvent = await _invitationService.canCreateEvent();
    if (!canCreateEvent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have reached the maximum number of events for today.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bottomSheetContext) => PlaceDetailsSheet(
        place: {
          'name': 'Custom Location',
          'vicinity':
              'Lat: ${tappedPoint.latitude.toStringAsFixed(6)}, Lng: ${tappedPoint.longitude.toStringAsFixed(6)}',
          'location': tappedPoint,
          'place_id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
        },
        isEventPlace: false,
        userLocation: _userLocation,
        showSnackBar: (String message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      ),
    );
  }
}

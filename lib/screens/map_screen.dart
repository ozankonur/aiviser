import 'package:aiviser/screens/profile_screen.dart';
import 'package:aiviser/services/fcm_token_manager.dart';
import 'package:aiviser/services/invitation_service.dart';
import 'package:aiviser/widgets/custom_marker_builder.dart';
import 'package:aiviser/widgets/invitations_list.dart';
import 'package:aiviser/widgets/map_view.dart';
import 'package:aiviser/widgets/place_details_sheet.dart';
import 'package:aiviser/widgets/recommendation_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/error_dialog.dart';
import '../widgets/place_type_list.dart';
import '../widgets/recommendation_fab.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../services/ai_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final PlacesService _placesService = PlacesService(dotenv.env['PLACE_API_KEY'] ?? '');
  final AIService _aiService = AIService();
  final Set<Marker> _markers = {};
  final InvitationService _invitationService = InvitationService();
  bool _hasUnreadInvitations = false;

  late AnimationController _animationController;
  late Animation<Offset> _offsetAnimation;

  LatLng? _userLocation;
  String _selectedPlaceType = '';
  String _errorMessage = '';
  bool _isLoadingRecommendation = false;
  bool _showRecommendation = false;
  bool _isLocationFetched = true;
  List<Map<String, dynamic>> _aiRecommendations = [];
  GoogleMapController? _mapController;
  Set<Marker> _eventMarkers = {};

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _initializeLocation();
    _subscribeToLocationChanges();
    FCMTokenManager.initializeFirebaseMessaging();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForInvitationUpdates();
      _loadEventMarkers();
    });
  }

  @override
  void dispose() {
    _locationService.dispose();
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _listenForInvitationUpdates() {
    _invitationService.getPendingInvitations().listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasUnreadInvitations = snapshot.docs.isNotEmpty;
        });
      }
    });
  }

  Future<void> _loadEventMarkers() async {
    final eventMarker = await CustomMarkerBuilder.getCustomMarker('invitation', context);
    _invitationService.getUserEvents().listen((snapshot) {
      if (mounted) {
        setState(() {
          _eventMarkers = snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final DateTime scheduledTime = (data['scheduledTime'] as Timestamp).toDate();
                final DateTime now = DateTime.now();

                if (scheduledTime.isAfter(now)) {
                  return Marker(
                    markerId: MarkerId('event_${doc.id}'),
                    position: LatLng(data['placeLatitude'], data['placeLongitude']),
                    icon: eventMarker,
                    onTap: () => _showPlaceDetails(
                        context,
                        {
                          'place_id': data['placeId'],
                          'name': data['placeName'],
                          'location': LatLng(data['placeLatitude'], data['placeLongitude']),
                          'vicinity': data['placeAddress'],
                        },
                        isEventPlace: true,
                        eventId: doc.id),
                  );
                } else {
                  return null;
                }
              })
              .where((marker) => marker != null)
              .cast<Marker>()
              .toSet();
          _fitMarkersOnMap();
        });
      }
    });
  }

  void _fitMarkersOnMap() {
    if (_mapController == null) return;

    Set<Marker> allMarkers = {..._markers, ..._eventMarkers};
    if (allMarkers.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (Marker marker in allMarkers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }
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

  void _subscribeToLocationChanges() {
    _locationService.startLocationUpdates();
    _locationService.locationStream.listen((newLocation) {
      setState(() {
        _userLocation = newLocation;
      });
    });
  }

  Future<void> _initializeLocation() async {
    try {
      // First, try to get the last known location
      LatLng? cachedLocation = await _locationService.getLastKnownLocation();
      if (cachedLocation != null) {
        setState(() {
          _userLocation = cachedLocation;
          _isLocationFetched = true;
        });
        _zoomToUserLocation();
      }

      // Then, get the current location
      final location = await _locationService.getCurrentLocation();
      setState(() {
        _userLocation = location;
        _isLocationFetched = true;
      });
      _zoomToUserLocation();
      _animationController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  void _zoomToUserLocation() {
    if (_userLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _userLocation!,
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  Future<void> _searchNearbyPlaces(String placeType) async {
    if (_userLocation == null) return;

    setState(() {
      _selectedPlaceType = placeType;
      _isLoadingRecommendation = true;
      _showRecommendation = true;
      _markers.clear();
    });

    try {
      final places = await _placesService.searchNearbyPlaces(_userLocation!, placeType);
      await _updateMarkers(places);
      final recommendations = await _aiService.getRecommendations(places, placeType);

      setState(() {
        _aiRecommendations = recommendations;
        _isLoadingRecommendation = false;
        _showRecommendation = true;
      });
      _fitMarkersOnMap();
    } catch (e) {
      setState(() {
        _isLoadingRecommendation = false;
        _showRecommendation = false;
      });
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _updateMarkers(List<Map<String, dynamic>> places) async {
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
      _showRecommendation = false;
      _isLoadingRecommendation = false;
      _markers.clear();
    });
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
        showSnackBar: (String message) {
          Navigator.of(bottomSheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      ),
    );
  }

  void _showRecommendationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecommendationSheet(recommendations: _aiRecommendations),
    );
  }

  void _showInvitationsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: InvitationsList(),
        ),
      ),
    ).then((_) {
      setState(() {
        _hasUnreadInvitations = false;
      });
    });
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
            markers: {..._markers, ..._eventMarkers},
            onMapCreated: (controller) {
              _mapController = controller;
              _fitMarkersOnMap();
            },
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
          if (_isLocationFetched)
            PlaceTypeList(
              onPlaceTypeSelected: _searchNearbyPlaces,
              selectedPlaceType: _selectedPlaceType,
              offsetAnimation: _offsetAnimation,
            ),
          if ((_selectedPlaceType.isNotEmpty || _showRecommendation) && !_isLoadingRecommendation)
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
          Positioned(
            bottom: 53,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'profile',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  child: const Icon(Icons.person),
                ),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    FloatingActionButton(
                      heroTag: 'invitations',
                      onPressed: _showInvitationsList,
                      tooltip: 'Show Invitations',
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      child: const Icon(Icons.mail),
                    ),
                    if (_hasUnreadInvitations)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _showRecommendation
          ? RecommendationFAB(
              isLoading: _isLoadingRecommendation,
              onPressed: _isLoadingRecommendation ? () {} : _showRecommendationSheet)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

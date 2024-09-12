import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapView extends StatefulWidget {
  final LatLng? userLocation;
  final Set<Marker> markers;
  final Function(GoogleMapController) onMapCreated;
  final Function(LatLng)? onMapTap; // Add this line

  const MapView({
    Key? key,
    required this.userLocation,
    required this.markers,
    required this.onMapCreated,
    this.onMapTap, // Add this line
  }) : super(key: key);

  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;
  static const double _defaultZoom = 13.0;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(
        target: widget.userLocation ?? const LatLng(0, 0),
        zoom: _defaultZoom,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      markers: widget.markers,
      onTap: widget.onMapTap, // Add this line
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    widget.onMapCreated(controller);
    _zoomToUserLocation();
  }

  void _zoomToUserLocation() {
    if (widget.userLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: widget.userLocation!,
            zoom: _defaultZoom,
          ),
        ),
      );
    }
  }
}

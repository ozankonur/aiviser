import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;

class CustomMarkerBuilder {
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> getCustomMarker(String placeType, BuildContext context) async {
    if (_cache.containsKey(placeType)) {
      return _cache[placeType]!;
    }
    final marker = await _createCustomMarkerBitmap(context, _getIconForPlaceType(placeType));
    _cache[placeType] = marker;
    return marker;
  }

  static Future<BitmapDescriptor> _createCustomMarkerBitmap(BuildContext context, IconData iconData) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(80, 80); // Increased size from 60x60 to 100x100

    final paint = Paint()..color = Theme.of(context).colorScheme.primary;
    canvas.drawCircle(size.center(Offset.zero), 40, paint); // Increased radius from 30 to 50

    TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 40, // Increased font size from 30 to 50
        fontFamily: iconData.fontFamily,
        color: Colors.white,
      ),
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset(
        size.width / 2 - painter.width / 2,
        size.height / 2 - painter.height / 2,
      ),
    );

    final image = await pictureRecorder.endRecording().toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  static IconData _getIconForPlaceType(String type) {
    switch (type) {
      case 'restaurant':
        return Icons.restaurant;
      case 'cafe':
        return Icons.local_cafe;
      case 'bar':
        return Icons.local_bar;
      case 'park':
        return Icons.park;
      case 'museum':
        return Icons.museum;
      case 'shopping_mall':
        return Icons.shopping_bag;
      case 'hospital':
        return Icons.local_hospital;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'school':
        return Icons.school;
      case 'library':
        return Icons.local_library;
      case 'gym':
        return Icons.fitness_center;
      case 'supermarket':
        return Icons.local_grocery_store;
      case 'bus_station':
        return Icons.directions_bus;
      case 'train_station':
        return Icons.train;
      case 'airport':
        return Icons.local_airport;
      case 'hotel':
        return Icons.hotel;
      case 'theater':
        return Icons.theaters;
      case 'gas_station':
        return Icons.local_gas_station;
      case 'invitation':
        return Icons.groups;
      default:
        return Icons.place;
    }
  }
}

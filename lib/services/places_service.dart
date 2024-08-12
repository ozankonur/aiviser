import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PlacesService {
  final String apiKey;
  PlacesService(this.apiKey);

  Future<List<Map<String, dynamic>>> searchNearbyPlaces(LatLng location, String placeType) async {
    String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${location.latitude},${location.longitude}&radius=5000&type=$placeType&key=$apiKey';
    try {
      var response = await http.get(Uri.parse(url));
      var json = jsonDecode(response.body);
      if (json['status'] == 'OK') {
        List<Map<String, dynamic>> places = [];
        for (var place in json['results']) {
          places.add({
            'name': place['name'],
            'rating': place['rating'] ?? 'N/A',
            'user_ratings_total': place['user_ratings_total'] ?? 0,
            'location': LatLng(place['geometry']['location']['lat'], place['geometry']['location']['lng']),
            'place_id': place['place_id'],
            'vicinity': place['vicinity'],
          });
        }
        if (places.isEmpty) {
          throw NoResultsException('No results found for $placeType');
        }
        return places;
      } else if (json['status'] == 'ZERO_RESULTS') {
        throw NoResultsException('No results found for $placeType');
      } else {
        throw Exception('Failed to fetch nearby places: ${json['status']}');
      }
    } catch (e) {
      if (e is NoResultsException) {
        rethrow;
      }
      throw Exception('Error fetching nearby places: $e');
    }
  }
}

class NoResultsException implements Exception {
  final String message;

  NoResultsException(this.message);

  @override
  String toString() => message;
}

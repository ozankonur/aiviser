import 'package:flutter/material.dart';

class PlaceTypeList extends StatelessWidget {
  final Function(String) onPlaceTypeSelected;
  final String selectedPlaceType;
  final Animation<Offset> offsetAnimation;

  const PlaceTypeList({
    Key? key,
    required this.onPlaceTypeSelected,
    required this.selectedPlaceType,
    required this.offsetAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.075,
      left: 16,
      right: 16,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          children: _placeTypes.map((type) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => onPlaceTypeSelected(type['type']!),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor:
                      selectedPlaceType == type['type'] ? Theme.of(context).colorScheme.primary : Colors.white,
                  elevation: selectedPlaceType == type['type'] ? 8 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: Icon(_getIconForPlaceType(type['type']!),
                    color: selectedPlaceType == type['type'] ? Colors.white : Colors.black),
                label: Text(type['name']!,
                    style: selectedPlaceType == type['type']
                        ? const TextStyle(color: Colors.white)
                        : const TextStyle(color: Colors.black)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _getIconForPlaceType(String type) {
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
      default:
        return Icons.place;
    }
  }
}

final List<Map<String, String>> _placeTypes = [
  {'name': 'Restaurants', 'type': 'restaurant'},
  {'name': 'Cafes', 'type': 'cafe'},
  {'name': 'Hotels', 'type': 'hotel'},
  {'name': 'Parks', 'type': 'park'},
  {'name': 'Museums', 'type': 'museum'},
  {'name': 'Shopping Malls', 'type': 'shopping_mall'},
  {'name': 'Hospitals', 'type': 'hospital'},
  {'name': 'Pharmacies', 'type': 'pharmacy'},
  {'name': 'Gas Stations', 'type': 'gas_station'},
  {'name': 'Libraries', 'type': 'library'},
  {'name': 'Schools', 'type': 'school'},
  {'name': 'Gyms', 'type': 'gym'},
  {'name': 'Supermarkets', 'type': 'supermarket'},
  {'name': 'Bus Stations', 'type': 'bus_station'},
  {'name': 'Train Stations', 'type': 'train_station'},
  {'name': 'Airports', 'type': 'airport'},
  {'name': 'Theaters', 'type': 'theater'},
  {'name': 'Bars', 'type': 'bar'},
];

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MapServices {
  final String apiKey;

  MapServices(this.apiKey);

  Future<List<PlacePrediction>> getPlacePredictions(String query) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey&components=country:in'); // Restricting to India for now, can be removed
    
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return (data['predictions'] as List)
            .map((p) => PlacePrediction.fromJson(p))
            .toList();
      }
    }
    return [];
  }

  Future<LatLng?> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey');
    
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final loc = data['result']['geometry']['location'];
        return LatLng(loc['lat'], loc['lng']);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> getDirections(LatLng origin, LatLng destination) async {
    final polylinePoints = PolylinePoints();
    
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: apiKey,
      request: PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.status == 'OK' && result.points.isNotEmpty) {
      return {
        'points': result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      };
    }
    return {};
  }
}

class PlacePrediction {
  final String placeId;
  final String description;

  PlacePrediction({required this.placeId, required this.description});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'],
      description: json['description'],
    );
  }
}

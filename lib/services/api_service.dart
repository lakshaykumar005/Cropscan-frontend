import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiService {
  // Update this to your local IP address if testing on a physical device
  // For Android emulator: 'http://10.0.2.2:5001'
  // For iOS simulator / macOS: 'http://127.0.0.1:5001'
  static String get baseUrl {
    // Return the live AWS Elastic Beanstalk backend URL
    return 'http://cropscan-backend-env.eba-sj7s2zta.ap-south-2.elasticbeanstalk.com';
  }

  /// Fetch real-time weather (temp, humidity) + NDVI from the backend
  /// which in turn calls Open-Meteo and NASA MODIS
  static Future<Map<String, dynamic>?> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/weather?lat=$latitude&lon=$longitude',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Weather fetch error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> predict({
    required XFile imageFile,
    double temperature = 30.0,
    double humidity = 60.0,
    double ndvi = 0.45,
    // Default OFF so online predictions go through the same minimal pipeline
    // as the standalone notebook (Resize -> ToTensor -> Normalize). Aggressive
    // BG removal + sharpness/contrast/saturation enhancements push images far
    // from the training distribution and hurt accuracy.
    bool bgRemoval = false,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/predict'),
      );

      // Add text fields
      request.fields['temperature'] = temperature.toString();
      request.fields['humidity'] = humidity.toString();
      request.fields['ndvi'] = ndvi.toString();
      request.fields['bg_removal'] = bgRemoval.toString();

      // Add image file
      var multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      );
      request.files.add(multipartFile);

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Network Error: $e');
      return null;
    }
  }
}

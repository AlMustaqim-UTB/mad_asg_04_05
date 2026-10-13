import 'dart:convert';

import 'package:http/http.dart' as http;

class PredictionRecord {
  const PredictionRecord({
    required this.imageId,
    required this.imageName,
    required this.prediction,
    required this.confidence,
    required this.dateTime,
  });

  final int imageId;
  final String imageName;
  final String prediction;
  final double confidence;
  final DateTime dateTime;

  factory PredictionRecord.fromJson(Map<String, dynamic> json) {
    return PredictionRecord(
      imageId: (json['imageId'] as num).toInt(),
      imageName: json['imageName'] as String,
      prediction: json['prediction'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      dateTime: DateTime.parse(json['dateTime'] as String),
    );
  }
}

class PredictionApi {
  // Android emulator URL.
  static const String baseUrl = 'http://10.0.2.2/app_api/api.php';

  Future<void> savePrediction({
    required String imageName,
    required String prediction,
    required double confidence,
    required DateTime dateTime,
  }) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'imageName': imageName,
        'prediction': prediction,
        'confidence': confidence,
        'dateTime': dateTime.toUtc().toIso8601String(),
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
        'Failed to save prediction: '
        '${response.statusCode} ${response.body}',
      );
    }
  }

  Future<List<PredictionRecord>> getPredictions() async {
    final response = await http.get(Uri.parse(baseUrl));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to retrieve predictions: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final records = decoded['records'] as List<dynamic>;

    return records
        .map(
          (record) => PredictionRecord.fromJson(
            record as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
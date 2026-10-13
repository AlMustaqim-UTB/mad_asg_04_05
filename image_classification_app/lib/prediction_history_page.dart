import 'package:flutter/material.dart';

import 'prediction_api.dart';

class PredictionHistoryPage extends StatefulWidget {
  const PredictionHistoryPage({
    required this.predictionApi,
    super.key,
  });

  final PredictionApi predictionApi;

  @override
  State<PredictionHistoryPage> createState() => _PredictionHistoryPageState();
}

class _PredictionHistoryPageState extends State<PredictionHistoryPage> {
  late Future<List<PredictionRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = widget.predictionApi.getPredictions();
  }

  void _reload() {
    setState(() {
      _recordsFuture = widget.predictionApi.getPredictions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Predictions')),
      body: FutureBuilder<List<PredictionRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to load saved predictions.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(
              child: Text('No saved predictions found.'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Image')),
                  DataColumn(label: Text('Prediction')),
                  DataColumn(label: Text('Confidence')),
                  DataColumn(label: Text('Date')),
                ],
                rows: records.map((record) {
                  return DataRow(
                    cells: [
                      DataCell(Text(record.imageId.toString())),
                      DataCell(Text(record.imageName)),
                      DataCell(Text(record.prediction)),
                      DataCell(
                        Text(
                          '${(record.confidence * 100).toStringAsFixed(1)}%',
                        ),
                      ),
                      DataCell(Text(record.dateTime.toLocal().toString())),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'prediction_history_page.dart';
import 'prediction_api.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AircraftClassifier(),
    );
  }
}

class AircraftClassifier extends StatefulWidget {
  const AircraftClassifier({super.key});

  @override
  State<AircraftClassifier> createState() => _AircraftClassifierState();
}

class _AircraftClassifierState extends State<AircraftClassifier> {
  static const _imageSize = 224;
  static const _classCount = 15;

  final PredictionApi predictionApi = PredictionApi();

  bool isSaving = false;
  String? saveMessage;

  Interpreter? interpreter;
  File? imageFile;
  List<String> labels = [];
  String prediction = '';
  double confidence = 0.0;
  String scoreDetails = '';

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> saveCurrentPrediction() async {
    if (imageFile == null || prediction.isEmpty) {
      return;
    }

    setState(() {
      isSaving = true;
      saveMessage = null;
    });

    try {
      await predictionApi.savePrediction(
        imageName: imageFile!.path.split(RegExp(r'[/\\]')).last,
        prediction: prediction,
        confidence: confidence,
        dateTime: DateTime.now(),
      );

      if (!mounted) return;

      setState(() {
        saveMessage = 'Prediction saved successfully';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        saveMessage = 'Unable to save prediction: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset('assets/model_unquant.tflite');
    final labelsData = await rootBundle.loadString('assets/labels.txt');

    labels = labelsData
        .split(RegExp(r'\r?\n'))
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList();

    final inputTensor = interpreter!.getInputTensor(0);
    final outputTensor = interpreter!.getOutputTensor(0);

    print('INPUT SHAPE: ${inputTensor.shape}');
    print('INPUT TYPE: ${inputTensor.type}');
    print('OUTPUT SHAPE: ${outputTensor.shape}');
    print('OUTPUT TYPE: ${outputTensor.type}');
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage == null) return;

    setState(() {
      imageFile = File(pickedImage.path);
      prediction = '';
      confidence = 0.0;
      scoreDetails = '';
    });
  }

  List<List<List<List<double>>>> prepareImage(img.Image image) {
    final cropSize = image.width < image.height ? image.width : image.height;
    final cropX = (image.width - cropSize) ~/ 2;
    final cropY = (image.height - cropSize) ~/ 2;
    final squareImage = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropSize,
      height: cropSize,
    );
    final resizedImage = img.copyResize(
      squareImage,
      width: _imageSize,
      height: _imageSize,
      interpolation: img.Interpolation.linear,
    );

    return [
      List.generate(_imageSize, (y) {
        return List.generate(_imageSize, (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [
            (pixel.r / 127.5) - 1.0,
            (pixel.g / 127.5) - 1.0,
            (pixel.b / 127.5) - 1.0,
          ];
        });
      }),
    ];
  }

  Future<void> classifyImage() async {
    if (imageFile == null || interpreter == null) return;

    final bytes = await imageFile!.readAsBytes();
    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) return;

    final image = img.bakeOrientation(decodedImage);
    final input = prepareImage(image);

    final output = [List<double>.filled(_classCount, 0.0)];

    interpreter!.run(input, output);

    final scores = output[0];

    if (labels.length != _classCount || scores.length != labels.length) {
      throw StateError(
        'Expected $_classCount labels and output values, '
        'but received ${labels.length} labels and ${scores.length} values.',
      );
    }

    var highestIndex = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[highestIndex]) {
        highestIndex = i;
      }
    }

    final rankedIndexes = List<int>.generate(scores.length, (index) => index)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final topScores = rankedIndexes
        .take(3)
        .map((index) {
          return '${labels[index]} ${(scores[index] * 100).toStringAsFixed(2)}%';
        })
        .join('\n');

    debugPrint('Model scores:\n$topScores');

    setState(() {
      prediction = labels[highestIndex];
      confidence = scores[highestIndex];
      scoreDetails = topScores;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aircraft Classifier')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (imageFile != null) Image.file(imageFile!, height: 250),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: pickImage,
              child: const Text('Select Image'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: classifyImage,
              child: const Text('Classify'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PredictionHistoryPage(
                      predictionApi: predictionApi,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('View Saved Predictions'),
            ),
            const SizedBox(height: 30),
            if (prediction.isNotEmpty) ...[
              Text(
                'Prediction: $prediction',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Top results:\n$scoreDetails',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isSaving ? null : saveCurrentPrediction,
                child: Text(isSaving ? 'Saving...' : 'Save Prediction'),
              ),
              if (saveMessage != null) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: SingleChildScrollView(
                    child: Text(
                      saveMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    interpreter?.close();
    super.dispose();
  }
}

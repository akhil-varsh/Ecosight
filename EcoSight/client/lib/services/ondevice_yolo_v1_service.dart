library;

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class OnDeviceHazardDetection {
  final String hazard;
  final String direction;
  final double distance;
  final double confidence;
  final List<int> box;

  const OnDeviceHazardDetection({
    required this.hazard,
    required this.direction,
    required this.distance,
    required this.confidence,
    required this.box,
  });
}

class OnDeviceYoloV1Service {
  static const String modelAssetPath = 'assets/models/detect.tflite';
  static const double _confidenceThreshold = 0.35;
  static const int _maxDetections = 20;
  static const double _focalConstant = 200.0;

  static const Set<String> _hazardAllowList = {
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'bus',
    'truck',
    'traffic light',
    'fire hydrant',
    'stop sign',
    'bench',
    'cat',
    'dog',
    'backpack',
    'handbag',
    'suitcase',
    'bottle',
    'cup',
    'chair',
    'couch',
    'potted plant',
    'dining table',
    'laptop',
    'mouse',
    'keyboard',
    'cell phone',
    'book',
  };

  static const List<String> _cocoLabels = [
    'background',
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'airplane',
    'bus',
    'train',
    'truck',
    'boat',
    'traffic light',
    'fire hydrant',
    'stop sign',
    'parking meter',
    'bench',
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'elephant',
    'bear',
    'zebra',
    'giraffe',
    'backpack',
    'umbrella',
    'handbag',
    'tie',
    'suitcase',
    'frisbee',
    'skis',
    'snowboard',
    'sports ball',
    'kite',
    'baseball bat',
    'baseball glove',
    'skateboard',
    'surfboard',
    'tennis racket',
    'bottle',
    'wine glass',
    'cup',
    'fork',
    'knife',
    'spoon',
    'bowl',
    'banana',
    'apple',
    'sandwich',
    'orange',
    'broccoli',
    'carrot',
    'hot dog',
    'pizza',
    'donut',
    'cake',
    'chair',
    'couch',
    'potted plant',
    'bed',
    'dining table',
    'toilet',
    'tv',
    'laptop',
    'mouse',
    'remote',
    'keyboard',
    'cell phone',
    'microwave',
    'oven',
    'toaster',
    'sink',
    'refrigerator',
    'book',
    'clock',
    'vase',
    'scissors',
    'teddy bear',
    'hair drier',
    'toothbrush',
  ];

  Interpreter? _interpreter;
  int _inputSize = 300;
  int _debugInputLogCounter = 0;

  bool get isLoaded => _interpreter != null;

  Future<void> load() async {
    if (_interpreter != null) {
      return;
    }

    final options = InterpreterOptions()..threads = 2;
    _interpreter = await Interpreter.fromAsset(modelAssetPath, options: options);

    final inputShape = _interpreter!.getInputTensor(0).shape;
    if (inputShape.length >= 3) {
      _inputSize = inputShape[1];
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  Future<List<OnDeviceHazardDetection>> detectFromJpeg(
    Uint8List jpegBytes,
  ) async {
    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) {
      return const [];
    }

    return detectFromImage(decoded);
  }

  Future<List<OnDeviceHazardDetection>> detectFromImage(img.Image source) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('On-device SSD model is not loaded');
    }

    final srcW = source.width;
    final srcH = source.height;
    final resized = img.copyResize(
      source,
      width: _inputSize,
      height: _inputSize,
    );

    final input = _buildInput(resized);
    if ((_debugInputLogCounter++ % 30) == 0) {
      debugPrint(
        'TFLite input -> dtype=uint8, shape=[1,$_inputSize,$_inputSize,3]',
      );
    }

    final boxes = List.generate(1, (_) => List.generate(10, (_) => List.filled(4, 0.0)));
    final classes = List.generate(1, (_) => List.filled(10, 0.0));
    final scores = List.generate(1, (_) => List.filled(10, 0.0));
    final numDetections = List.filled(1, 0.0);

    final outputs = <int, Object>{
      0: boxes,
      1: classes,
      2: scores,
      3: numDetections,
    };

    interpreter.runForMultipleInputs([input], outputs);

    final count = math.min(numDetections.first.round(), 10);
    final detections = <OnDeviceHazardDetection>[];

    for (var i = 0; i < count; i++) {
      final score = (scores[0][i] as num).toDouble();
      if (score < _confidenceThreshold) {
        continue;
      }

      final classId = (classes[0][i] as num).round();
      final label = _labelForClassId(classId);
      if (!_hazardAllowList.contains(label)) {
        continue;
      }

      final yMin = ((boxes[0][i][0] as num).toDouble() * srcH).clamp(0, srcH - 1).round();
      final xMin = ((boxes[0][i][1] as num).toDouble() * srcW).clamp(0, srcW - 1).round();
      final yMax = ((boxes[0][i][2] as num).toDouble() * srcH).clamp(0, srcH - 1).round();
      final xMax = ((boxes[0][i][3] as num).toDouble() * srcW).clamp(0, srcW - 1).round();

      final box = [xMin, yMin, xMax, yMax];
      detections.add(
        OnDeviceHazardDetection(
          hazard: label,
          direction: _directionForBox(box, srcW),
          distance: _distanceForBox(box),
          confidence: double.parse(score.toStringAsFixed(2)),
          box: box,
        ),
      );
    }

    detections.sort((a, b) => a.distance.compareTo(b.distance));
    return detections.take(_maxDetections).toList();
  }

  List<List<List<List<int>>>> _buildInput(img.Image image) {
    final tensor = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (_) => List.generate(_inputSize, (_) => List.filled(3, 0)),
      ),
    );

    for (var y = 0; y < _inputSize; y++) {
      for (var x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);
        tensor[0][y][x][0] = pixel.r.toInt();
        tensor[0][y][x][1] = pixel.g.toInt();
        tensor[0][y][x][2] = pixel.b.toInt();
      }
    }

    return tensor;
  }

  String _labelForClassId(int classId) {
    if (classId < 0 || classId >= _cocoLabels.length) {
      return 'object';
    }
    return _cocoLabels[classId];
  }

  String _directionForBox(List<int> box, int width) {
    final centerX = (box[0] + box[2]) / 2.0;
    final ratio = centerX / math.max(width, 1);
    if (ratio < 0.33) {
      return 'left';
    }
    if (ratio > 0.66) {
      return 'right';
    }
    return 'center';
  }

  double _distanceForBox(List<int> box) {
    final pixelHeight = math.max(1, box[3] - box[1]).toDouble();
    final distance = _focalConstant / pixelHeight;
    return double.parse(math.max(distance, 0.3).toStringAsFixed(1));
  }
}

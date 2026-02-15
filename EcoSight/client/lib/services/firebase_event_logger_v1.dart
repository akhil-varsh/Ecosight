library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseEventLoggerV1 {
  FirebaseEventLoggerV1._();

  static final FirebaseEventLoggerV1 instance = FirebaseEventLoggerV1._();

  FirebaseFirestore? get _db {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseFirestore.instance;
  }

  Future<void> logDetection({
    required String source,
    required int latencyMs,
    required Map<String, dynamic> detection,
  }) async {
    final db = _db;
    if (db == null) {
      return;
    }

    try {
      await db.collection('v1_detections').add({
        'source': source,
        'latencyMs': latencyMs,
        'hazard': detection['hazard'],
        'direction': detection['direction'],
        'distance': detection['distance'],
        'confidence': detection['confidence'],
        'box': detection['box'],
        'clientTs': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Firebase] logDetection failed: $e');
    }
  }

  Future<void> logSceneDescription({
    required String text,
    required String baseUrl,
    required bool success,
    Uint8List? imageBytes,
    String? error,
  }) async {
    final db = _db;
    if (db == null) {
      return;
    }

    try {
      final imageTooLarge =
          imageBytes != null && imageBytes.length > 700 * 1024;
      final imageBase64 =
          imageBytes == null || imageTooLarge
              ? null
              : base64Encode(imageBytes);

      await db.collection('v1_scene_descriptions').add({
        'text': text,
        'baseUrl': baseUrl,
        'success': success,
        'error': error,
        'imageBase64': imageBase64,
        'imageBytes': imageBytes?.length,
        'imageStored': imageBase64 != null,
        'imageDroppedReason': imageTooLarge ? 'too_large' : null,
        'clientTs': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Firebase] logSceneDescription failed: $e');
    }
  }
}

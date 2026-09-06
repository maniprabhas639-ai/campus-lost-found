import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationApiService {
  NotificationApiService({
    FirebaseAuth? auth,
    http.Client? client,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  static const String _baseUrl =
      'https://campus-lost-found-cqfe.onrender.com';

  Future<bool> sendMessageNotification({
    required String itemId,
    required String conversationId,
    required String title,
    required String body,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      debugPrint(
        'NOTIFICATION API: No authenticated user.',
      );
      return false;
    }

    try {
      final String? idToken = await currentUser.getIdToken();

      if (idToken == null || idToken.trim().isEmpty) {
        debugPrint(
          'NOTIFICATION API: Firebase ID token unavailable.',
        );
        return false;
      }

      final Uri uri = Uri.parse(
        '$_baseUrl/send-message-notification',
      );

      final http.Response response = await _client.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${idToken.trim()}',
        },
        body: jsonEncode(<String, String>{
          'itemId': itemId.trim(),
          'conversationId': conversationId.trim(),
          'title': title.trim(),
          'body': body.trim(),
        }),
      );

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        debugPrint(
          'NOTIFICATION API: Notification request successful.',
        );
        return true;
      }

      debugPrint(
        'NOTIFICATION API: Server returned '
        '${response.statusCode}: ${response.body}',
      );

      return false;
    } catch (error) {
      debugPrint(
        'NOTIFICATION API ERROR: $error',
      );
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}
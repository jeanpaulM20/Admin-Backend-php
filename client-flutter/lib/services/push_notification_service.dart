import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'push_notification_stub.dart' if (dart.library.html) 'push_notification_web.dart';
import 'api_client.dart';

/// Push notification service — coordinates JS push API with backend registration.
/// Delegates JS calls to platform-specific implementation (web vs stub).
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  bool _initialized = false;
  String? _vapidPublicKey;

  /// Initialise: fetch VAPID key from backend, check existing subscription.
  Future<void> init(String clientId) async {
    if (_initialized) return;
    if (!kIsWeb) return;

    try {
      final data = await apiClient.get('api/client/push/vapid-key');
      _vapidPublicKey = data?['publicKey'];
      if (_vapidPublicKey == null || _vapidPublicKey!.isEmpty) {
        debugPrint('Push: No VAPID key configured on server');
        return;
      }

      // Re-register existing subscription with backend
      final existing = await getExistingPushSubscription();
      if (existing != null) {
        await _registerWithBackend(clientId, existing);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Push init error: $e');
    }
  }

  /// Request permission and subscribe to push notifications.
  Future<bool> subscribe(String clientId) async {
    if (!kIsWeb) return false;
    if (_vapidPublicKey == null) {
      // Try fetching key again
      try {
        final data = await apiClient.get('api/client/push/vapid-key');
        _vapidPublicKey = data?['publicKey'];
      } catch (_) {}
      if (_vapidPublicKey == null) return false;
    }

    try {
      final permission = await requestNotificationPermission();
      if (permission != 'granted') {
        debugPrint('Push: Permission = $permission');
        return false;
      }

      final subJson = await subscribeToPush(_vapidPublicKey!);
      if (subJson == null) return false;

      await _registerWithBackend(clientId, subJson);
      return true;
    } catch (e) {
      debugPrint('Push subscribe error: $e');
      return false;
    }
  }

  /// Unsubscribe from push notifications.
  Future<void> unsubscribe(String clientId) async {
    if (!kIsWeb) return;
    try {
      final existing = await getExistingPushSubscription();
      if (existing != null) {
        final sub = jsonDecode(existing);
        await apiClient.post(
          'api/client/push/$clientId/unsubscribe',
          body: {'endpoint': sub['endpoint']},
        );
      }
      await unsubscribeFromPush();
    } catch (e) {
      debugPrint('Push unsubscribe error: $e');
    }
  }

  /// Register subscription with the backend.
  Future<void> _registerWithBackend(String clientId, String subJson) async {
    final sub = jsonDecode(subJson);
    await apiClient.post(
      'api/client/push/$clientId/subscribe',
      body: {
        'endpoint': sub['endpoint'],
        'keys': {
          'p256dh': sub['keys']['p256dh'],
          'auth': sub['keys']['auth'],
        },
      },
    );
  }
}

// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
import 'dart:html' as html;

/// Check if push notifications are supported in this browser.
bool isPushSupported() {
  try {
    final fn = js_util.getProperty(html.window, 'isPushSupported');
    if (fn == null) return false;
    return js_util.callMethod<bool>(html.window, 'isPushSupported', []);
  } catch (_) {
    return false;
  }
}

/// Get current notification permission: 'granted', 'denied', 'default'.
Future<String> getNotificationPermission() async {
  try {
    final fn = js_util.getProperty(html.window, 'getNotificationPermission');
    if (fn == null) return 'unsupported';
    final result = js_util.callMethod<String>(html.window, 'getNotificationPermission', []);
    return result;
  } catch (_) {
    return 'unsupported';
  }
}

/// Request notification permission. Returns 'granted', 'denied', or 'default'.
Future<String> requestNotificationPermission() async {
  try {
    final promise = js_util.callMethod(html.window, 'requestNotificationPermission', []);
    final result = await js_util.promiseToFuture<String>(promise);
    return result;
  } catch (_) {
    return 'denied';
  }
}

/// Subscribe to push notifications with the given VAPID public key.
/// Returns the subscription as a JSON string, or null on failure.
Future<String?> subscribeToPush(String vapidPublicKey) async {
  try {
    final promise = js_util.callMethod(html.window, 'subscribeToPush', [vapidPublicKey]);
    final result = await js_util.promiseToFuture(promise);
    if (result == null) return null;
    return result.toString();
  } catch (_) {
    return null;
  }
}

/// Unsubscribe from push notifications. Returns true on success.
Future<bool> unsubscribeFromPush() async {
  try {
    final promise = js_util.callMethod(html.window, 'unsubscribeFromPush', []);
    final result = await js_util.promiseToFuture<bool>(promise);
    return result;
  } catch (_) {
    return false;
  }
}

/// Get existing push subscription (if any). Returns JSON string or null.
Future<String?> getExistingPushSubscription() async {
  try {
    final promise = js_util.callMethod(html.window, 'getExistingPushSubscription', []);
    final result = await js_util.promiseToFuture(promise);
    if (result == null) return null;
    return result.toString();
  } catch (_) {
    return null;
  }
}

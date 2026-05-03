/// Stub implementations for non-web platforms.
/// All functions are no-ops since push notifications only work on web.

bool isPushSupported() => false;

Future<String> getNotificationPermission() async => 'unsupported';

Future<String> requestNotificationPermission() async => 'unsupported';

Future<String?> subscribeToPush(String vapidPublicKey) async => null;

Future<bool> unsubscribeFromPush() async => false;

Future<String?> getExistingPushSubscription() async => null;

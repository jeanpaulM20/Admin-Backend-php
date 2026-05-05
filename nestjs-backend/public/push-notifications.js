/**
 * Push notification helper functions for Flutter JS interop.
 * Called from Dart via dart:js_interop / dart:js_util.
 */

// Global state
window._pushSubscription = null;

/**
 * Check if push notifications are supported in this browser.
 */
window.isPushSupported = function() {
  return ('serviceWorker' in navigator) && ('PushManager' in window) && ('Notification' in window);
};

/**
 * Get current notification permission state: 'granted', 'denied', 'default'.
 */
window.getNotificationPermission = function() {
  if (!('Notification' in window)) return 'unsupported';
  return Notification.permission;
};

/**
 * Request notification permission. Returns the permission result.
 */
window.requestNotificationPermission = async function() {
  if (!('Notification' in window)) return 'unsupported';
  const result = await Notification.requestPermission();
  return result;
};

/**
 * Register the push service worker and subscribe to push notifications.
 * @param {string} vapidPublicKey - Base64-encoded VAPID public key from server
 * @returns {string} JSON string of the push subscription (endpoint + keys)
 */
window.subscribeToPush = async function(vapidPublicKey) {
  try {
    // Register the push service worker
    const registration = await navigator.serviceWorker.register('push-sw.js', { scope: '/client/' });
    await navigator.serviceWorker.ready;

    // Convert VAPID key from base64 to Uint8Array
    const padding = '='.repeat((4 - vapidPublicKey.length % 4) % 4);
    const base64 = (vapidPublicKey + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = atob(base64);
    const applicationServerKey = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; i++) {
      applicationServerKey[i] = rawData.charCodeAt(i);
    }

    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: applicationServerKey
    });

    window._pushSubscription = subscription;
    return JSON.stringify(subscription.toJSON());
  } catch (err) {
    console.error('Push subscription failed:', err);
    return null;
  }
};

/**
 * Unsubscribe from push notifications.
 */
window.unsubscribeFromPush = async function() {
  try {
    if (window._pushSubscription) {
      await window._pushSubscription.unsubscribe();
      window._pushSubscription = null;
      return true;
    }
    // Try to find existing subscription
    const registration = await navigator.serviceWorker.getRegistration('/client/');
    if (registration) {
      const subscription = await registration.pushManager.getSubscription();
      if (subscription) {
        await subscription.unsubscribe();
        return true;
      }
    }
    return false;
  } catch (err) {
    console.error('Push unsubscribe failed:', err);
    return false;
  }
};

/**
 * Get existing push subscription (if any).
 * @returns {string|null} JSON string of subscription or null
 */
window.getExistingPushSubscription = async function() {
  try {
    const registration = await navigator.serviceWorker.getRegistration('/client/');
    if (!registration) return null;
    const subscription = await registration.pushManager.getSubscription();
    if (!subscription) return null;
    window._pushSubscription = subscription;
    return JSON.stringify(subscription.toJSON());
  } catch (err) {
    return null;
  }
};

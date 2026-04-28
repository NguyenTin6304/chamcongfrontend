// Firebase Messaging Service Worker
// Handles push notifications when the app is in the background or closed.

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: "AIzaSyB14n5rnaDTqxdXb0_HZ3KRqObnphYt5nc",
  authDomain: "chamcongfcm.firebaseapp.com",
  projectId: "chamcongfcm",
  storageBucket: "chamcongfcm.firebasestorage.app",
  messagingSenderId: "926798360325",
  appId: "1:926798360325:web:648064645cce7275c2116c",
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = (payload.notification && payload.notification.title) || 'Thông báo';
  const body = (payload.notification && payload.notification.body) || '';
  const route = (payload.data && payload.data.route) || '';

  self.registration.showNotification(title, {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { route },
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = (event.notification.data && event.notification.data.route) || '/home';
  const targetUrl = self.location.origin + '/#' + route;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('navigate' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      return clients.openWindow(targetUrl);
    }),
  );
});

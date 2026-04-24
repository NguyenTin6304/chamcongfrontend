// Firebase Messaging Service Worker
// Handles push notifications when the app is in the background or closed.
//
// IMPORTANT: Replace the placeholder values below with your actual Firebase
// project config from the Firebase Console → Project Settings → Your apps.
// These values are public and safe to commit.

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

  self.registration.showNotification(title, {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  });
});

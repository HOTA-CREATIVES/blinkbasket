// Firebase Messaging Service Worker for Web Push Notifications

importScripts('https://www.gstatic.com/firebasejs/11.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker.
firebase.initializeApp({
  apiKey: "AIzaSyB6Q_MKCeZqJX586nHwKTw6qr7EM9nCrs0",
  appId: "1:855090552291:web:a4d79e2f35811e016a54d6",
  messagingSenderId: "855090552291",
  projectId: "hypermart-ee8ef",
  authDomain: "hypermart-ee8ef.firebaseapp.com",
  storageBucket: "hypermart-ee8ef.firebasestorage.app"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'JC Mart Notification';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

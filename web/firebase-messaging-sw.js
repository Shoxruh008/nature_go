importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDn_1-ffF7Qon2n4QKXpdNv16OCuZJc2ys",
  authDomain: "nature-go-c188e.firebaseapp.com",
  projectId: "nature-go-c188e",
  storageBucket: "nature-go-c188e.firebasestorage.app",
  messagingSenderId: "225052370906",
  appId: "1:225052370906:web:a45f608a746ecc97fa42e3"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png',
  });
});
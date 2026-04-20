# 🥾 NatureGo

**NatureGo** — Markaziy Osiyodagi tabiiy joylarga sayohat va trekking rejalashtirishga mo'ljallangan Flutter ilovasi. Tog'ga chiqmoqchimisiz? Sharsharani ko'rmoqchimisiz? Ko'l bo'yida dam olmoqchimisiz? NatureGo orqali yaqin atrofdagi yoki maqsadli joyni topib, barcha kerakli ma'lumotlarni bir joyda olasiz — manzil, koordinatlar, marshrut, masofa va boshqalar.

---

## 🎯 Ilova kimlar uchun?

| Foydalanuvchi | Imkoniyat |
|---|---|
| 🧗 **Trekkingchilar** | Marshrut uzunligi, qiyinlik darajasi, balandlik ma'lumotlari |
| 🚶 **Sayyohlar** | Yaqin joylarni masofasi bo'yicha topish |
| 🏕️ **Lager quruvchilar** | Camping, piknik uchun mos joylar |
| 📍 **Yangi joylarni kashf etuvchilar** | Fasl va joy turiga qarab filtrlash |
| 🗺️ **Rejalashtiruvchilar** | Xaritada ko'rish, GPX/KML marshrut fayllari |

---

## ✨ Asosiy imkoniyatlar

### 📍 Joylashuvga asoslangan qidiruv
- Foydalanuvchining GPS koordinatlarini aniqlab, **eng yaqin joylarni masofasi bo'yicha saralaydi**
- Shahar nomi avtomatik aniqlanadi
- Masofa limiti (masalan, 50 km ichidagi joylar) qo'yish mumkin

### 🔍 Kuchli filtrlash
- **Joy turi bo'yicha**: tog', cho'qqi, sharsara, ko'l, g'or, sahro va boshqalar
- **Fasl bo'yicha**: bahor, yoz, kuz, qish — qaysi faslda borishni aniqlash
- **Matn qidiruvi**: joy nomi, viloyat yoki teg bo'yicha

### 🗺️ Marshrut va navigatsiya
- Joyning aniq **koordinatlarini** ko'rish
- **GPX, KML, GeoJSON** formatidagi marshrut fayllarini yuklab olish
- Xaritada joylashuvni ko'rish va yo'lni rejalashtirish

### 🏔️ Trekking ma'lumotlari
- Marshrut **uzunligi** (km)
- **Qiyinlik darajasi** (oson / o'rta / qiyin)
- Eng yuqori **balandlik** (m)
- Bog'lanish uchun **telefon raqami**

### 📸 Joy tafsilotlari
- Bir nechta **fotosuratlar**
- **Video** ko'rish
- **Tavsif** va faoliyat **teglari** (piyoda, suzish, lager, chang'i va h.k.)
- Boshqa foydalanuvchilar **izohlari va reytingi**

### ❤️ Sevimlilar
- Bormoqchi bo'lgan joylarni saqlab qo'yish
- Alohida **sevimlilar ekrani**

### ➕ Yangi joy taklif qilish
- Foydalanuvchilar xaritadan joylashuvni belgilab yangi joy qo'sha oladi
- Admin tasdiqlashidan so'ng ilova katalogiga kiritiladi
- Tasdiqlangan joylar uchun **pul mukofoti** beriladi

---

## 🗂️ Loyiha tuzilmasi

```
lib/
├── main.dart                  # Kirish nuqtasi, AppTheme ranglari va uslublari
├── firebase_options.dart      # Firebase platformaga xos konfiguratsiya
├── constants/
│   └── regions.dart           # Markaziy Osiyo viloyatlari (5 davlat, 40+ viloyat)
├── models/
│   ├── place_model.dart       # Joy modeli: koordinatlar, marshrut, trekking ma'lumotlari
│   └── review_model.dart      # Izoh va reyting modeli
├── screens/
│   ├── home_screen.dart       # Bosh sahifa: yaqin joylar, filtrlash, qidiruv
│   ├── detail_screen.dart     # Joy tafsiloti: manzil, marshrut, trekking, izohlar
│   ├── add_place_screen.dart  # Yangi joy qo'shish (xaritadan joylashuv tanlash bilan)
│   ├── comments_sheet.dart    # Izohlar va reytinglar paneli
│   ├── favourites_screen.dart # Saqlangan (bormoqchi bo'lgan) joylar
│   ├── map_picker_page.dart   # Interaktiv xaritadan nuqta tanlash
│   └── donate_page.dart       # Ilovani qo'llab-quvvatlash
├── services/
│   ├── firebase_service.dart       # Firestore/Storage: joylarni o'qish, rasm/fayl yuklash
│   ├── auth_service.dart           # Anonim kirish (ro'yxatdan o'tmasdan ishlaydi)
│   ├── favourites_service.dart     # Sevimlilarni qurilmada saqlash
│   ├── review_service.dart         # Izoh qo'shish va o'qish
│   ├── location_service.dart       # GPS, masofa hisoblash, shahar nomi
│   ├── image_compress_service.dart # Yuklashdan oldin rasmni siqish
│   ├── video_service_stub.dart     # Mobil uchun video ko'rish
│   └── video_service_web.dart      # Veb uchun video ko'rish
└── widgets/
    ├── place_card.dart         # Joy kartasi (rasm, nom, masofa, reyting)
    ├── favourite_button.dart   # Saqlash/olib tashlash tugmasi
    ├── star_rating.dart        # Yulduzli reyting
    └── webmap/
        ├── web_map_stub.dart   # Mobil xarita
        └── web_map_web.dart    # Veb xarita
```

---

## 🏔️ Joy turlari va faoliyatlar

| Tur | Belgisi | Mos faoliyat |
|---|---|---|
| Tog'lar | ⛰️ | Trekking, suratga olish |
| Cho'qqilar | 🏔️ | Alpinizm, chang'i |
| Adirlar | 🌄 | Piyoda yurish, piknik |
| Sharsharalar | 💧 | Ko'rishga borish, suzish |
| Ko'llar | 🏞️ | Qayiq, baliq ovi, lager |
| Orollar | 🏝️ | Dam olish, suzish |
| Sohillar | 🌊 | Suzish, qayiq |
| Cho'llar | 🏜️ | Safari, lager |
| G'orlar | 🪨 | Speologiya, ko'rishga borish |

---

## 🔥 Firebase ma'lumotlar bazasi

### `places` kolleksiyasi — joy ma'lumotlari

| Maydon | Tur | Maqsad |
|---|---|---|
| `name` | String | Joy nomi |
| `region` | String | Viloyat/hudud |
| `type` | String | Joy turi ID |
| `seasonTypes` | List\<String\> | Mos fasllar |
| `lat` / `lng` | double | **GPS koordinatlar** — navigatsiya uchun asosiy |
| `images` | List\<String\> | Fotosuratlar (Firebase Storage URL) |
| `description` | String | Batafsil tavsif |
| `tags` | List\<String\> | Faoliyat teglari (hiking, camping, swimming...) |
| `baseRating` | double | Asosiy reyting |
| `isPublished` | bool | Admin tasdiqlagan |
| `routeFileUrl` | String? | **GPX/KML/GeoJSON marshrut fayli** |
| `videoUrl` | String? | Video |
| `phone` | String? | **Aloqa raqami** |
| `trekDifficulty` | String? | **Qiyinlik darajasi** |
| `trekLength` | String? | **Marshrut uzunligi** |
| `trekElevation` | String? | **Balandlik** |
| `submittedBy` | String | Taklif qilgan foydalanuvchi |

### `reviews` kolleksiyasi — foydalanuvchi izohlari

| Maydon | Tur | Maqsad |
|---|---|---|
| `placeId` | String | Joy ID |
| `rating` | double | Reyting 1–5 |
| `text` | String | Izoh matni |
| `images` | List\<String\> | Borib kelgan foydalanuvchi rasmlari |
| `isPublished` | bool | Moderatsiyadan o'tgan |

---

## 🚀 O'rnatish

### Talablar

- Flutter 3.x+
- Dart 3.x+
- Firebase loyihasi (Firestore, Storage, Auth, Messaging yoqilgan)

### Bosqichlar

```bash
# 1. Reponi klonlash
git clone <repo-url>
cd nature_go

# 2. Paketlarni o'rnatish
flutter pub get

# 3. Firebase sozlash
flutterfire configure

# 4. Ishga tushirish
flutter run              # mobil
flutter run -d chrome   # veb
```

---

## 📦 Asosiy paketlar

| Paket | Maqsad |
|---|---|
| `cloud_firestore` | Joy ma'lumotlari real-vaqt oqimi |
| `firebase_storage` | Rasm va marshrut fayllari saqlash |
| `firebase_auth` | Anonim foydalanuvchi sessiyasi |
| `firebase_messaging` | Yangi joy haqida push xabar |
| `geolocator` | GPS joylashuv va masofa hisoblash |
| `geocoding` | Koordinatdan shahar/viloyat nomi |
| `cached_network_image` | Fotosuratlarni tezkor yuklash |
| `image_picker` | Galereya/kamera'dan rasm |
| `file_picker` | GPX/KML marshrut fayli tanlash |

---

## 🏗️ Texnik arxitektura

- **Singleton servislar** — `FirebaseService.instance`, `AuthService.instance`, `LocationService.instance`
- **Real-vaqt yangilanish** — Firestore `Stream` orqali joylar avtomatik yangilanadi
- **Ikki darajali kesh** — `Map<String, PlaceModel>` (ID bo'yicha) + `List<PlaceModel>` (umumiy) — ortiqcha so'rovlarni kamaytiradi
- **Cross-platform video/xarita** — veb va mobil uchun alohida implementatsiya (stub pattern)
- **Anonim autentifikatsiya** — ro'yxatdan o'tmasdan ishlaydi, UID orqali kuzatiladi

---

## ⚙️ Muhim eslatmalar

> 🔒 **Moderatsiya**: Foydalanuvchi qo'shgan joylar `isPublished: false` holida saqlanadi. Admin tasdiqlashidan keyingina katalogda ko'rinadi.

> 📡 **Oflayn**: Hozirgi versiya internet talab qiladi.

> 🏆 **Mukofot tizimi**: Admin tomonidan tasdiqlangan joy uchun uni taklif qilgan foydalanuvchiga pul mukofoti berilishi ko'zda tutilgan.

---

*NatureGo — Manzilni top, yo'lni reja qil, sayohatni boshla!* 🥾🌄

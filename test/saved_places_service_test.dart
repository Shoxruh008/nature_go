import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nature_go/services/saved_places_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late SavedPlacesService favourites;
  late SavedPlacesService visited;
  late SavedPlacesService wishlist;

  Future<bool> exists(String list, String placeId) async => (await db
          .collection('users')
          .doc('u1')
          .collection(list)
          .doc(placeId)
          .get())
      .exists;

  setUp(() {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', isAnonymous: false),
    );
    favourites = SavedPlacesService('favourites', db: db, auth: auth);
    visited = SavedPlacesService('visited', db: db, auth: auth);
    wishlist = SavedPlacesService('wishlist', db: db, auth: auth);
  });

  test("toggle: qo'shadi va olib tashlaydi", () async {
    expect(await favourites.toggle('p1'), isTrue);
    await pumpEventQueue();
    expect(await exists('favourites', 'p1'), isTrue);
    expect(favourites.isSavedSync('p1'), isTrue);

    expect(await favourites.toggle('p1'), isFalse);
    await pumpEventQueue();
    expect(await exists('favourites', 'p1'), isFalse);
    expect(favourites.isSavedSync('p1'), isFalse);
  });

  test("ro'yxatlar bir-biridan mustaqil", () async {
    await favourites.toggle('p1');
    await pumpEventQueue();

    expect(await visited.isSaved('p1'), isFalse);
    expect(await wishlist.getAll(), isEmpty);
  });

  test("getAll saqlangan ID'larni qaytaradi", () async {
    await wishlist.toggle('a');
    await wishlist.toggle('b');
    await pumpEventQueue();

    expect(await wishlist.getAll(), {'a', 'b'});
  });

  test("moveTo: bitta batch'da ko'chiradi", () async {
    await wishlist.toggle('p1');
    await pumpEventQueue();

    await wishlist.moveTo(visited, 'p1');
    await pumpEventQueue();

    expect(await exists('wishlist', 'p1'), isFalse);
    expect(await exists('visited', 'p1'), isTrue);
    expect(wishlist.isSavedSync('p1'), isFalse);
    expect(await visited.isSaved('p1'), isTrue);
  });

  test("moveTo: allaqachon borganlarda bo'lsa ham xato bermaydi", () async {
    await wishlist.toggle('p1');
    await visited.toggle('p1');
    await pumpEventQueue();

    await wishlist.moveTo(visited, 'p1');
    await pumpEventQueue();

    expect(await exists('wishlist', 'p1'), isFalse);
    expect(await exists('visited', 'p1'), isTrue);
  });

  test("remove: ro'yxatdan olib tashlaydi", () async {
    await favourites.toggle('p1');
    await pumpEventQueue();
    await favourites.remove('p1');
    await pumpEventQueue();

    expect(await exists('favourites', 'p1'), isFalse);
  });

  test('chiqib ketganda kesh tozalanadi', () async {
    await favourites.toggle('p1');
    await pumpEventQueue();
    expect(favourites.isSavedSync('p1'), isTrue);

    await auth.signOut();
    await pumpEventQueue();

    expect(favourites.isSavedSync('p1'), isFalse);
    expect(await favourites.getAll(), isEmpty);
  });

  test('anonim foydalanuvchi uchun hech narsa yozilmaydi', () async {
    final anonAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'anon', isAnonymous: true),
    );
    final service = SavedPlacesService('favourites', db: db, auth: anonAuth);

    expect(await service.toggle('p1'), isFalse);
    expect(await service.isSaved('p1'), isFalse);
    final snap =
        await db.collection('users').doc('anon').collection('favourites').get();
    expect(snap.docs, isEmpty);
  });
}

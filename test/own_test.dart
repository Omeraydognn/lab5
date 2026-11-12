// Part 7: my own tests. They test real code from lib/ with in-memory fakes.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lab05_study_notes/data/auth_repository.dart';
import 'package:lab05_study_notes/data/notes_repository.dart';
import 'package:lab05_study_notes/models/note.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  // Create one fake first: it makes FieldValue.serverTimestamp() work in tests.
  setUpAll(FakeFirebaseFirestore.new);

  test('example: messageFor maps weak-password', () {
    expect(AuthRepository.messageFor('weak-password'), contains('6 characters'));
  });

  group('AuthRepository', () {
    test('messageFor maps the remaining codes', () {
      expect(AuthRepository.messageFor('network-request-failed'), 'No connection. Check your network.');
      expect(AuthRepository.messageFor('wrong-password'), 'Wrong email or password.');
      expect(AuthRepository.messageFor('user-not-found'), 'Wrong email or password.');
    });

    test('signUp failure (email-already-in-use) becomes a friendly AuthFailure', () async {
      final auth = MockFirebaseAuth();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      final repo = AuthRepository(auth);
      await expectLater(
        repo.signUp('ada@agu.edu.tr', 'secret123'),
        throwsA(isA<AuthFailure>()
            .having((f) => f.message, 'message', 'An account already exists for this email.')),
      );
      expect(repo.currentUser, isNull, reason: 'a failed sign-up must not sign anybody in');
    });
  });

  group('NotesRepository', () {
    test('a title of exactly 100 characters is accepted (boundary)', () async {
      final repo = NotesRepository(FakeFirebaseFirestore());
      await repo.addNote('u1', 'a' * 100, 'x');
      final notes = await repo.watchNotes('u1').first;
      expect(notes.single.title, hasLength(100));
    });

    test('the stored document has a createdAt timestamp and no id field', () async {
      final db = FakeFirebaseFirestore();
      await NotesRepository(db).addNote('u1', 'Lab 5', '  rules  ');
      final doc = (await db.collection('users').doc('u1').collection('notes').get()).docs.single;
      expect(doc.data()['body'], 'rules');
      expect(doc.data()['createdAt'], isA<Timestamp>());
      expect(doc.data().containsKey('id'), isFalse);
    });

    test('deleteNote only removes the given note', () async {
      final db = FakeFirebaseFirestore();
      final repo = NotesRepository(db);
      await repo.addNote('u1', 'keep', '');
      await repo.addNote('u1', 'remove', '');
      final toRemove = (await repo.watchNotes('u1').first).firstWhere((n) => n.title == 'remove');
      await repo.deleteNote('u1', toRemove.id);
      final left = await repo.watchNotes('u1').first;
      expect(left.map((n) => n.title), ['keep']);
    });
  });

  group('Note', () {
    test('a body that is not a String is a FormatException', () {
      expect(() => Note.fromFirestore('n1', {'title': 'A', 'body': 42}), throwsFormatException);
    });
  });
}

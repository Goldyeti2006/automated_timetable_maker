import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _fire = FirebaseFirestore.instance;

  // Try sign in, if not exist create user and set role
  static Future<User?> signInOrRegister(String email, String password, String role, String name) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      final user = cred.user!;
      // Ensure user doc exists
      final doc = _fire.collection('users').doc(user.uid);
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        await doc.set({
          'email': email,
          'role': role,
          'name': name,
          'registeredCourses': [],
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // register
        final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        final user = cred.user!;
        await _fire.collection('users').doc(user.uid).set({
          'email': email,
          'role': role,
          'name': name,
          'registeredCourses': [],
        });
        return user;
      } else {
        rethrow;
      }
    }
  }

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<void> signOut() async => await _auth.signOut();

  static User? currentUser() => _auth.currentUser;
}

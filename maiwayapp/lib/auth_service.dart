import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  // SIGN IN
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  //CREATE ACCOUNT
  Future<UserCredential> createAccount({
    required String email,
    required String password,
    required String name,
    String role = 'user', // Default; change in db for admin role
  }) async {
    UserCredential credential = await firebaseAuth
        .createUserWithEmailAndPassword(email: email, password: password);

    final uid = credential.user?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'name': name,
        'role': role,
      });
    }

    await credential.user?.reload();
    return credential;
  }

  // SIGN OUT
  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  // RESET PASSWORD
  Future<void> resetPassword({required String email}) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // UPDATE USERNAME
  Future<void> updateUsername({required String username}) async {
    await currentUser!.updateDisplayName(username);
  }

  // RESET PASSWORD WITH VERIFICATION
  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }

  // FETCH ROLE
  Future<String?> getUserRole(String uid) async {
    DocumentSnapshot snapshot =
        await firestore.collection('users').doc(uid).get();
    return snapshot.get('role');
  }
}

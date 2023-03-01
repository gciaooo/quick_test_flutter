import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'firebase_options.dart';
import 'test.dart';

class FirebaseAPI {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  static final DatabaseReference userTestsRef =
      _db.ref("users/${auth.currentUser!.uid}/tests");
  static final DatabaseReference testsRef = _db.ref("tests");
  static final DatabaseReference questionsRef = _db.ref("questions");

  static Future<FirebaseApp> initializeApp() async {
    return Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }

  static void addTestToDatabase(Test test) {
    List<String?> questionsKeys = [];
    //aggiungo le questions e conservo la loro chiave su questionKeys
    for (Question q in test.questions) {
      var qKey = questionsRef.push().key;
      questionsKeys.add(qKey);
      if (qKey != null) {
        questionsRef.child(qKey).set(q.toJson());
      }
    }
    //setto una key per il test
    var tKey = testsRef.push().key;
    if (tKey != null) {
      //aggiungo la chiave del test all'utente corrente
      userTestsRef.update({tKey: true});

      //aggiungo il test
      testsRef.child(tKey).set(test.toJson());

      //aggiungo le questionKeys al test
      for (String? k in questionsKeys) {
        if (k != null) {
          testsRef.child("$tKey/questions").update({k: true});
        }
      }
    }
  }

  static Future<void> login(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
      } else if (e.code == 'wrong-password') {}
    }
  }
}
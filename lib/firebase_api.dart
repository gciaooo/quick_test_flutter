import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'firebase_options.dart';
import 'test.dart';

class FirebaseAPI {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseDatabase _db = FirebaseDatabase.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static final DatabaseReference userRef =
      _db.ref("users/${auth.currentUser!.uid}");
  static final DatabaseReference userTestsRef =
      _db.ref("users/${auth.currentUser!.uid}/tests");
  static final DatabaseReference testsRef = _db.ref("tests");
  static DatabaseReference singleTestRef(String testKey) =>
      _db.ref("tests/$testKey");
  static final DatabaseReference questionsRef = _db.ref("questions");
  static DatabaseReference userTestPrintRef(String t) =>
      _db.ref("printed/$t/${auth.currentUser!.uid}");
  static DatabaseReference singleQuestionRef(String questionKey) =>
      _db.ref("questions/$questionKey");
  static Future<FirebaseApp> initializeApp() async {
    return Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }

  // static late final StreamSubscription testsData;
  static List<Test> userTests = [];
  static int listenCount = 0;
  // static void setDBListener() async {
  //   listenCount++;
  //   testsData = userTestsRef.onValue.listen((event) {
  //     _getUserTests(event, userTests);
  //   });
  // }

  // static void cancelDBListener() {
  //   listenCount--;
  //   if (listenCount <= 0) {
  //     testsData.cancel();
  //   }
  // }

  // static void _getUserTests(DatabaseEvent event, List<Test> userTests) async {
  //   Map<String, dynamic> testKeys = Map<String, dynamic>.from(
  //       event.snapshot.value as Map<Object?, Object?>);

  //   for (var tk in testKeys.entries) {
  //     var test = await FirebaseAPI.getTest(tk.key);
  //     if (test != null) {
  //       userTests.add(test);
  //     }
  //   }
  // }

  static Future<String?> getUserDisplayName() async {
    String displayName = await userRef.child("name").get().then((name) =>
        userRef
            .child("surname")
            .get()
            .then((surname) => "${name.value} ${surname.value}"));
    return displayName;
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

  static Future<Test?> getTest(String id) async {
    var test = await FirebaseAPI.singleTestRef(id).get();

    //converto il valore del test in una mappa
    if (test.exists) {
      Map<String, dynamic> testData =
          Map<String, dynamic>.from(test.value! as Map<Object?, Object?>);

      //prendo e itero le chiavi delle domande appartenenti al test iterato
      Map<String, dynamic> questionKeys = Map<String, dynamic>.from(
          test.child("questions").value as Map<Object?, Object?>);

      List<Question> qList = [];
      for (var q in questionKeys.entries) {
        //prendo il valore della domanda iterata
        var value = await FirebaseAPI.singleQuestionRef(q.key).get();
        // questionKeys.forEach((key, value) async {
        // var value = await _db.ref("questions/$key").get();
        //converto in mappa
        Map<String, dynamic> qData =
            Map<String, dynamic>.from(value.value! as Map<Object?, Object?>);
        //aggiungo la domanda ad una lista
        qList.add(Question.fromJson(qData));
        //});
      }

      //metto la lista delle domande dentro la mappa del test
      testData["questions"] = qList;
      //inserisco l'id dalla chiave della reference del test
      testData["id"] = id;
      return Test.fromJson(testData);
    }
    return null;
  }

  static Future<void> login(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
      } else if (e.code == 'wrong-password') {}
    }
  }

  static Future<void> uploadPrint(File document, String test) async {
    final printKey = await userTestPrintRef(test).once();

    if (printKey.snapshot.value != null) {
      await _storage.ref(printKey.snapshot.value.toString()).delete();
    }

    final fileKey = DateTime.now().millisecondsSinceEpoch.toString();
    await userTestPrintRef(test).set(fileKey);
    await _storage.ref(fileKey).putFile(document);
  }

  static Future<File> fetchPrintQuery(String id, Directory outDir) async {
    final fileKey = await userTestPrintRef(id).get();
    final file = File("${outDir.path}/test.pdf");
    final task = await _storage.ref(fileKey.value.toString()).getData();
    if (task != null) {
      file.writeAsBytesSync(task);
    }
    return file;
  }
}

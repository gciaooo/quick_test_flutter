import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:file_picker/file_picker.dart';

import 'package:quick_test_flutter/test.dart';
import 'package:xml/xml.dart';
import 'firebase_options.dart';

//TODO: if building release ver: https://github.com/miguelpruivo/flutter_file_picker/wiki/Setup
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Test',
      theme: ThemeData(primarySwatch: Colors.indigo),
      themeMode: ThemeMode.light,
      home: const MyHomePage(title: 'Quick Test'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int selectedindex = 0;
  static bool logged = false;

  static FirebaseAuth auth = FirebaseAuth.instance;

  final List<Widget> _widgetOptions = <Widget>[
    _MainPage(logged),
    _SettingsPage(),
    _LoginPage(),
  ];

  void toggleLogin() {
    _widgetOptions
        .removeWhere((e) => e.runtimeType == _LoginPage().runtimeType);
    if (!logged) {
      _widgetOptions.add(_LoginPage());
    }
    _widgetOptions[0] = _MainPage(logged);
    _changeIndex(0);
  }

  void _changeIndex(int index) async {
    int temp = index;
    if (index == 2 && logged) {
      temp = 0;
      await auth.signOut();
    }
    setState(() {
      selectedindex = temp;
    });
  }

  @override
  void initState() {
    super.initState();
    auth.authStateChanges().listen((User? user) {
      if (user == null) {
        logged = false;
      } else {
        logged = true;
      }
      toggleLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.title),
          ],
        ),
      ),
      body: Center(
        // child: _botNavBarChange(selectedindex),
        child: _widgetOptions.elementAt(selectedindex),
      ),
      floatingActionButton:
          selectedindex == 0 && logged ? _QuickTestActionButton() : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Impostazioni",
          ),
          if (!logged)
            const BottomNavigationBarItem(
                icon: Icon(Icons.person), label: "Login"),
          if (logged)
            const BottomNavigationBarItem(
                icon: Icon(Icons.logout), label: "Logout"),
        ],
        currentIndex: selectedindex,
        onTap: _changeIndex,
      ),
    );
  }
}

class _QuickTestActionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.cancel,
      mini: false,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.document_scanner),
          label: "Scannerizza test",
        ),
        SpeedDialChild(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => _ImportTestPage()));
          },
          child: const Icon(Icons.note_add_rounded),
          label: "Importa test",
        ),
      ],
    );
  }
}

class _ImportTestPage extends StatefulWidget {
  @override
  State<_ImportTestPage> createState() => _ImportTestPageState();
}

class _ImportTestPageState extends State<_ImportTestPage> {
  bool _selected = false;
  late Test? test;

  Future<Test?> _openTest() async {
    FilePickerResult? res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ["xml"]);

    if (res != null) {
      File file = File(res.files.single.path!);
      XmlDocument xmlFile = XmlDocument.parse(file.readAsStringSync());
      Test t = Test.fromXml(xmlFile);
      return t;
    }
    return null;
  }

  void _importTest() async {
    test = await _openTest();
    if (test != null) {
      setState(() {
        _selected = !_selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Conferma Test"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            !_selected
                ? FilledButton(
                    onPressed: _importTest,
                    child: const Text("Seleziona file..."),
                  )
                : _TestView(test!, true),
          ],
        ),
      ),
    );
  }
}

class _TestView extends StatefulWidget {
  const _TestView(this.test, this.toAdd);
  final Test test;
  final bool toAdd;

  List<Question> getQuestions() => test.questions;

  @override
  State<_TestView> createState() => _TestViewState();
}

class _TestViewState extends State<_TestView> {
  late final List<bool> expandedItems;

  final userTestsRef = FirebaseDatabase.instance
      .ref("users/${FirebaseAuth.instance.currentUser!.uid}/tests");
  final testsRef = FirebaseDatabase.instance.ref("tests");
  final questionsRef = FirebaseDatabase.instance.ref("questions");

  void addTestToDatabase() {
    List<String?> questionsKeys = [];
    //aggiungo le questions e conservo la loro chiave su questionKeys
    for (Question q in widget.getQuestions()) {
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
      testsRef.child(tKey).set(widget.test.toJson());

      //aggiungo le questionKeys al test
      for (String? k in questionsKeys) {
        if (k != null) {
          testsRef.child("$tKey/questions").update({k: true});
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    expandedItems = List<bool>.filled(widget.test.questions.length, false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ExpansionPanelList(
          children: widget.test.questions.map<ExpansionPanel>((Question q) {
            return ExpansionPanel(
              headerBuilder: (context, isExpanded) {
                return ListTile(title: Text(q.name));
              },
              body: ListTile(
                title: Text(q.text),
                subtitle: Text(
                    "Tipo di domanda: ${q.isTrueFalse ? "Vero o falso" : "Risposte multiple"}"),
              ),
              isExpanded: expandedItems[widget.test.questions.indexOf(q)],
            );
          }).toList(),
          expansionCallback: (i, isExpanded) => setState(() {
                expandedItems[i] = !isExpanded;
              })),
      const SizedBox(
        height: 200.0,
      ),
      if (widget.toAdd)
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(
            "Confermi di voler importare questo test?",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(
            height: 20.0,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).buttonTheme.colorScheme!.error),
                child: const Text("Annulla"),
              ),
              ElevatedButton(
                  onPressed: () {
                    addTestToDatabase();
                    Navigator.pop(context);
                  },
                  child: const Text("Conferma")),
            ],
          )
        ]),
    ]);
  }
}

class _MainPage extends StatelessWidget {
  const _MainPage(this.logged);

  final bool logged;

  @override
  Widget build(BuildContext context) {
    return !logged
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Benvenuto su Quick Test!",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 30),
            ],
          )
        : _MainPageLogged();
  }
}

class UserPlaceholder {
  UserPlaceholder(this.displayName);
  final String displayName;
}

class _MainPageLogged extends StatelessWidget {
  static FirebaseAuth auth = FirebaseAuth.instance;
  final user = UserPlaceholder("ggiacomo");

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              "Pagina di ${user.displayName}",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(
            height: 30,
          ),
          Text(
            "Test Recenti",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Divider(),
          const SizedBox(
            height: 500,
            child: TestListView(),
          ),
        ],
      ),
    );
  }
}

class TestListView extends StatefulWidget {
  const TestListView({
    super.key,
  });

  @override
  State<TestListView> createState() => _TestListViewState();
}

class _TestListViewState extends State<TestListView> {
  static FirebaseAuth auth = FirebaseAuth.instance;
  static FirebaseDatabase db = FirebaseDatabase.instance;

  final DatabaseReference userTestsRef =
      db.ref('users/${auth.currentUser?.uid}/tests');
  final DatabaseReference testsRef = db.ref('tests');

  // void setDBListeners() async {
  //   if (auth.currentUser != null) {
  //     testsRef.onChildAdded.listen((testEvent) {
  //       final Map<String, dynamic> testMap =
  //           Map<String, dynamic>.from(testEvent.snapshot.value as dynamic);
  //       testMap["id"] = testEvent.snapshot.key;
  //       testMap["questions"] =
  //           testEvent.snapshot.child("questions").children.toList();
  //       debugPrint(testMap["questions"].runtimeType.toString());
  //       tests.add(Test.fromMap(testMap));
  //     });
  //   }
  // }

  List<Test> tests = [];

  @override
  void initState() {
    super.initState();
    // setDBListeners();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(1),
      children: [
        for (Test t in tests)
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Prova " '${t.id}'),
                  Text("Data creazione: ${t.date.day}"
                      "/"
                      "${t.date.month}"
                      "/"
                      "${t.date.year}"),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8.0)),
            ],
          )
      ],
    );
  }
}

class _SettingsPage extends StatefulWidget {
  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool lightTheme = true;
  bool settingsPageActive = true;

  void changeTheme() {
    setState(() {
      lightTheme = !lightTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    //TODO: implement settings page
    return ListView(
      children: const [
        ListTile(
          title: Text("Impostazioni"),
        ),
      ],
    );
  }
}

class _LoginPage extends StatefulWidget {
  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 350,
      height: 300,
      child: Card(
        elevation: 3.0,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 0.0),
          child: LoginForm(),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _loginFormKey = GlobalKey<FormState>();

  late String? email, password;

  static FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> _login(String email, String password) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
          email: email, password: password);
      debugPrint('LOGGED! uid: ${credential.user!.uid}');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        debugPrint('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        debugPrint('Wrong password provided for that user.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    auth.authStateChanges().listen((User? user) {
      if (user == null) {}
    });
    return Form(
      key: _loginFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextFormField(
            onSaved: (String? value) => email = value,
            validator: (String? value) {
              return value == null || value.isEmpty
                  ? 'Please enter an username'
                  : null;
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Username",
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(
            height: 20.0,
          ),
          TextFormField(
            obscureText: true,
            onSaved: (String? value) => password = value,
            validator: (String? value) {
              return value == null || value.isEmpty
                  ? 'Please enter a password'
                  : null;
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Password",
              prefixIcon: Icon(Icons.key),
            ),
          ),
          const SizedBox(
            height: 20.0,
          ),
          ElevatedButton(
            onPressed: () {
              if (_loginFormKey.currentState!.validate()) {
                _loginFormKey.currentState!.save();
                _login(email!, password!);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white),
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }
}

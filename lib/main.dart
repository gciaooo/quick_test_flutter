import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:xml/xml.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:file_picker/file_picker.dart';

import 'test.dart';
import 'firebase_api.dart';

//TODO: if building release ver: https://github.com/miguelpruivo/flutter_file_picker/wiki/Setup
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseAPI.initializeApp();
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
      await FirebaseAPI.auth.signOut();
    }
    setState(() {
      selectedindex = temp;
    });
  }

  void _setAuthListener() {
    FirebaseAPI.auth.authStateChanges().listen((User? user) {
      if (user == null) {
        logged = false;
      } else {
        logged = true;
      }
      toggleLogin();
    });
  }

  @override
  void initState() {
    super.initState();
    _setAuthListener();
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
                    FirebaseAPI.addTestToDatabase(widget.test);
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

class _MainPageLogged extends StatelessWidget {
  final user = FirebaseAPI.auth.currentUser!;

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
              "Pagina di ${user.uid}",
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
  late final StreamSubscription _testsData;

  void setDBListeners() {
    _testsData = FirebaseAPI.userTestsRef.onValue.listen((event) {
      tests.clear();
      setState(() {
        tests = FirebaseAPI.getUserTests(event);
      });
      debugPrint(tests.toString());
    });
  }

  List<Test> tests = [];

  @override
  void initState() {
    super.initState();
    setDBListeners();
  }

  @override
  void deactivate() {
    _testsData.cancel();
    super.deactivate();
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
                  //TODO: change data format with dart:intl
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

  Future<void> _login(String email, String password) async {
    await FirebaseAPI.auth
        .signInWithEmailAndPassword(email: email, password: password);
    debugPrint('LOGGED! uid: ${FirebaseAPI.auth.currentUser!.uid}');
  }

  @override
  Widget build(BuildContext context) {
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

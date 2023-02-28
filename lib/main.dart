import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import 'firebase_api.dart';
import 'pages/main_page.dart';
import 'pages/login_page.dart';
import 'pages/settings_page.dart';

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

  late final StreamSubscription _authData;

  final List<Widget> _widgetOptions = <Widget>[
    mainPage(logged),
    settingsPage(),
    loginPage(),
  ];

  void toggleLogin() {
    _widgetOptions.removeWhere((e) => e.runtimeType == loginPage().runtimeType);
    if (!logged) {
      _widgetOptions.add(loginPage());
    }
    _widgetOptions[0] = mainPage(logged);
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
    _authData = FirebaseAPI.auth.authStateChanges().listen((User? user) {
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
  void deactivate() {
    _authData.cancel();
    super.deactivate();
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
                MaterialPageRoute(builder: (context) => importTestPage()));
          },
          child: const Icon(Icons.note_add_rounded),
          label: "Importa test",
        ),
      ],
    );
  }
}

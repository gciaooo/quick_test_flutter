import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:quick_test_flutter/pages/scan_page.dart';

import 'firebase_api.dart';
import 'pages/main_page.dart';
import 'pages/login_page.dart';
import 'pages/settings_page.dart';

//TODO: if building release ver: https://github.com/miguelpruivo/flutter_file_picker/wiki/Setup
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseAPI.initializeApp();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Test',
      theme: ThemeData(primarySwatch: Colors.indigo),
      themeMode: ThemeMode.light,
      home: MyHomePage(title: 'Quick Test', cameras: cameras),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.cameras});

  final String title;
  final List<CameraDescription> cameras;

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
    logged ? accountPage() : loginPage(),
  ];

  void toggleLogin() {
    if (!logged) {
      _widgetOptions
          .removeWhere((e) => e.runtimeType == accountPage().runtimeType);
      _widgetOptions.add(loginPage());
    } else {
      _widgetOptions
          .removeWhere((e) => e.runtimeType == loginPage().runtimeType);
      _widgetOptions.add(accountPage());
    }
    _widgetOptions[0] = mainPage(logged);
    _changeIndex(0);
  }

  void _changeIndex(int index) async {
    int temp = index;
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
      floatingActionButton: selectedindex == 0 && logged
          ? _QuickTestActionButton(cameras: widget.cameras)
          : null,
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
                icon: Icon(Icons.login), label: "Login"),
          if (logged)
            const BottomNavigationBarItem(
                icon: Icon(Icons.person), label: "Account"),
        ],
        currentIndex: selectedindex,
        onTap: _changeIndex,
      ),
    );
  }
}

class _QuickTestActionButton extends StatelessWidget {
  const _QuickTestActionButton({required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.cancel,
      mini: false,
      children: [
        SpeedDialChild(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => screenshotPage(cameras))),
          child: const Icon(Icons.document_scanner),
          label: "Scannerizza test",
        ),
        SpeedDialChild(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => importTestPage(true, false))),
          child: const Icon(Icons.note_add_rounded),
          label: "Importa test",
        ),
        SpeedDialChild(
          onTap: () => FirebaseAPI.auth.signOut(),
          child: const Icon(Icons.logout),
          label: "Logout",
        )
      ],
    );
  }
}

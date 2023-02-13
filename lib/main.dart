import 'package:flutter/material.dart';

void main() {
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
  // bool logged = false;

  final List<Widget> _widgetOptions = <Widget>[
    _MainPage(),
    _LoginPage(),
    _SettingsPage(),
  ];

  // void toggleLogin() {
  //   setState(() {
  //     if (!logged) {
  //       _widgetOptions.contains(_LoginPage)
  //     }
  //   });
  // }

  void _changeIndex(int index) {
    setState(() {
      selectedindex = index;
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
        child: _widgetOptions.elementAt(selectedindex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Login"),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
        currentIndex: selectedindex,
        onTap: _changeIndex,
      ),
    );
  }
}

class _MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Benvenuto su Quick Test!",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 30),
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
    //TODO: implement page
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
    return SizedBox(
      width: 350,
      height: 300,
      child: Card(
        elevation: 3.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 0.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                decoration: AppDesign.textFieldsDecoration.copyWith(
                  hintText: "Username",
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(
                height: 20.0,
              ),
              TextField(
                obscureText: true,
                decoration: AppDesign.textFieldsDecoration.copyWith(
                  hintText: "Password",
                  prefixIcon: const Icon(Icons.key),
                ),
              ),
              const SizedBox(
                height: 20.0,
              ),
              //TODO: implement login back-end
              ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white),
                child: const Text("Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppDesign {
  static const InputDecoration textFieldsDecoration =
      InputDecoration(border: OutlineInputBorder());
}

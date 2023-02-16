import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

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
  bool logged = false;

  static FirebaseAuth auth = FirebaseAuth.instance;

  final List<Widget> _widgetOptions = <Widget>[
    _MainPage(),
    _SettingsPage(),
    _LoginPage(),
  ];

  void toggleLogin() {
    _widgetOptions
        .removeWhere((e) => e.runtimeType == _LoginPage().runtimeType);
    if (!logged) {
      _widgetOptions.add(_LoginPage());
    }
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
        toggleLogin();
      } else {
        logged = true;
        toggleLogin();
      }
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
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
      print('LOGGED! uid: ${credential.user!.uid}');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
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
            decoration: AppDesign.textFieldsDecoration.copyWith(
              hintText: "Username",
              prefixIcon: const Icon(Icons.person),
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

class AppDesign {
  static const InputDecoration textFieldsDecoration =
      InputDecoration(border: OutlineInputBorder());
}

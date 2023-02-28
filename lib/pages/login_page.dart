import 'package:flutter/material.dart';

import '../firebase_api.dart';

Widget loginPage() => _LoginPage();

class _LoginPage extends StatelessWidget {
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

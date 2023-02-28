import 'package:flutter/material.dart';

Widget settingsPage() => _SettingsPage();

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

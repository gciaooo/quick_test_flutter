import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../firebase_api.dart';
import '../test.dart';

Widget mainPage(bool logged) => _MainPage(logged);
Widget importTestPage() => _ImportTestPage();

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
          SizedBox(
            height: 500,
            child: _TestListView(),
          ),
        ],
      ),
    );
  }
}

class _TestListView extends StatefulWidget {
  @override
  State<_TestListView> createState() => _TestListViewState();
}

class _TestListViewState extends State<_TestListView> {
  late final StreamSubscription _testsData;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  void setDBListeners() {
    _testsData = FirebaseAPI.userTestsRef.onValue.listen((event) {
      //prendo e itero le chiavi dei test appartenenti all'utente corrente
      Map<String, dynamic> testKeys = Map<String, dynamic>.from(
          event.snapshot.value as Map<Object?, Object?>);

      testKeys.forEach((key, value) {
        //prendo il valore del test iterato
        _db.ref("tests/$key").get().then((test) {
          //converto il valore del test in una mappa
          Map<String, dynamic> testData =
              Map<String, dynamic>.from(test.value! as Map<Object?, Object?>);

          //prendo e itero le chiavi delle domande appartenenti al test iterato
          Map<String, dynamic> questionKeys = Map<String, dynamic>.from(
              test.child("questions").value as Map<Object?, Object?>);

          List<Question> qList = [];
          questionKeys.forEach((key, value) {
            //prendo il valore della domanda iterata
            _db.ref("questions/$key").get().then((value) {
              //converto in mappa
              Map<String, dynamic> qData = Map<String, dynamic>.from(
                  value.value! as Map<Object?, Object?>);
              //aggiungo la domanda ad una lista
              qList.add(Question.fromJson(qData));
            });
          });

          //metto la lista delle domande dentro la mappa del test
          testData["questions"] = qList;
          //inserisco l'id dalla chiave della reference del test
          testData["id"] = key;
          debugPrint(testData.toString());
          setState(() {
            _tests.add(Test.fromJson(testData));
          });
        });
      });
    });
  }

  final List<Test> _tests = [];

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
        for (Test t in _tests)
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

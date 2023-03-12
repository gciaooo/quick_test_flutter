import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:html/parser.dart' show parse;

import '../firebase_api.dart';
import '../test.dart';

Widget mainPage(bool logged) => _MainPage(logged);
Widget accountPage() => _AccountPage();
Widget importTestPage(bool toAdd) => _TestPage(toAdd: toAdd);

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

  String? userDisplayName() => FirebaseAPI.getUserDisplayName(user);

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

class _AccountPage extends StatelessWidget {
  final user = FirebaseAPI.auth.currentUser;

  @override
  Widget build(BuildContext context) {
    return _TestListView();
  }
}

class _TestListView extends StatefulWidget {
  @override
  State<_TestListView> createState() => _TestListViewState();
}

class _TestListViewState extends State<_TestListView> {
  late final StreamSubscription _testsData;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  void setDBListeners() async {
    _testsData = FirebaseAPI.userTestsRef.onValue.listen((event) async {
      //prendo e itero le chiavi dei test appartenenti all'utente corrente
      Map<String, dynamic> testKeys = Map<String, dynamic>.from(
          event.snapshot.value as Map<Object?, Object?>);

      for (var tk in testKeys.entries) {
        // testKeys.forEach((key, value) {
        //prendo il valore del test iterato
        var test = await _db.ref("tests/${tk.key}").get();
        // _db.ref("tests/$key").get().then((test) {
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
            var value = await _db.ref("questions/${q.key}").get();
            // questionKeys.forEach((key, value) async {
            // var value = await _db.ref("questions/$key").get();
            //converto in mappa
            Map<String, dynamic> qData = Map<String, dynamic>.from(
                value.value! as Map<Object?, Object?>);
            //aggiungo la domanda ad una lista
            qList.add(Question.fromJson(qData));
            //});
          }

          //metto la lista delle domande dentro la mappa del test
          testData["questions"] = qList;
          //inserisco l'id dalla chiave della reference del test
          testData["id"] = tk.key;
          setState(() {
            _tests.add(Test.fromJson(testData));
          });
        }
      }
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
              OutlinedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            _TestPage(test: t, toAdd: false))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Prova " '${t.id}'),
                    //TODO: change data format with dart:intl
                    Expanded(
                      child: Text(
                        "Data creazione: ${t.date.day}"
                        "/"
                        "${t.date.month}"
                        "/"
                        "${t.date.year}",
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8.0)),
            ],
          )
      ],
    );
  }
}

class _TestPage extends StatefulWidget {
  _TestPage({this.test, required this.toAdd});

  late Test? test;
  final bool toAdd;

  @override
  State<_TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<_TestPage> {
  bool _selected = false;

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
    widget.test = await _openTest();
    if (widget.test != null) {
      setState(() {
        _selected = !_selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.toAdd
            ? const Text("Conferma Test")
            : Text("Test ${widget.test!.id}"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            !_selected && widget.toAdd
                ? FilledButton(
                    onPressed: _importTest,
                    child: const Text("Seleziona file..."),
                  )
                : _TestView(widget.test!, widget.toAdd),
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
                title: Html(data: q.text),
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
      widget.toAdd
          ? Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
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
            ])
          : Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        printTest(widget.test);
                      },
                      child: const Text("Stampa Test"),
                    ),
                  ],
                )
              ],
            ),
    ]);
  }
}

void printTest(Test test) async {
  final randomizedTest = test.randomize();

  var theme = pw.ThemeData.withFont(
    base: await PdfGoogleFonts.nunitoLight(),
    bold: await PdfGoogleFonts.nunitoBold(),
    italic: await PdfGoogleFonts.nunitoItalic(),
    boldItalic: await PdfGoogleFonts.nunitoBoldItalic(),
  );

  final pdf = pw.Document(theme: theme);

  pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(
                child: pw.Text(randomizedTest.id),
              ),
              pw.Text("QuickTest",
                  style: pw.Theme.of(context)
                      .defaultTextStyle
                      .copyWith(fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Expanded(
              child: pw.ListView.separated(
                  padding: const pw.EdgeInsets.symmetric(vertical: 50.0),
                  itemCount: randomizedTest.questions.length,
                  itemBuilder: (context, int index) {
                    Question q = randomizedTest.questions[index];
                    return pw.Column(children: [
                      pw.Text(parseHtml(q.text)),
                      pw.SizedBox(height: 10.0),
                      pw.Table(children: [
                        if (q.isTrueFalse)
                          pw.TableRow(children: [
                            pw.Row(children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 5.0),
                                child: pw.Checkbox(value: false, name: "1"),
                              ),
                              pw.Text("Vero"),
                            ]),
                            pw.Row(children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 5.0),
                                child: pw.Checkbox(value: false, name: "0"),
                              ),
                              pw.Text("Falso"),
                            ])
                          ]),
                        if (!q.isTrueFalse)
                          pw.TableRow(
                            children: [
                              for (int i = 0; i < q.answers.length; i++)
                                if (i % 2 != 0)
                                  pw.Row(children: [
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 5.0),
                                      child:
                                          pw.Checkbox(value: false, name: "$i"),
                                    ),
                                    pw.Text(
                                      parseHtml(q.answers[i]),
                                    ),
                                  ])
                            ],
                          ),
                        pw.TableRow(children: [
                          pw.SizedBox(height: 5.0),
                        ]),
                        if (!q.isTrueFalse)
                          pw.TableRow(children: [
                            for (int i = 0; i < q.answers.length; i++)
                              if (i % 2 == 0)
                                pw.Row(children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 5.0),
                                    child:
                                        pw.Checkbox(value: false, name: "$i"),
                                  ),
                                  pw.Text(
                                    parseHtml(q.answers[i]),
                                  ),
                                ])
                          ]),
                      ]),
                    ]);
                  },
                  separatorBuilder: (context, index) => pw.Divider()),
            ),
          ],
        );
      }));

  final output = await getApplicationDocumentsDirectory();
  final file = File('${output.path}/test.pdf');
  await file.writeAsBytes(await pdf.save());

  await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => file.readAsBytes());
}

//TODO: fix domande a risposta multipla con testo al centro
String parseHtml(String text) {
  final dom = parse(text);
  String parsed = "";
  for (final p in dom.getElementsByTagName("p")) {
    p.innerHtml = p.innerHtml.replaceAll(RegExp(r"<br>"), "\n");
    parsed += "${p.innerHtml}" "\n";
  }
  return parsed;
}

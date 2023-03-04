import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';

class Test {
  final String id;
  final DateTime date;
  final List<Question> questions;

  Test(this.id, this.date, this.questions);

  Test.withoutDate(this.id, this.questions)
      : date = DateUtils.dateOnly(DateTime.now());

  Test.fromXml(XmlDocument document)
      : id = "0",
        date = DateUtils.dateOnly(DateTime.now()),
        questions = [] {
    document.rootElement.findElements("question").forEach((q) {
      String? name = q.getElement("name")?.getElement("text")?.text;
      String? text = q.getElement("questiontext")?.getElement("text")?.text;
      bool? trueFalse = q.getAttribute("type") != "multichoice";

      int? correctAnswer;
      List<String> answers = [];
      List<XmlElement> xmlAnswers = q.findElements("answer").toList();

      for (int i = 0; i < xmlAnswers.length; i++) {
        if (xmlAnswers[i].getAttribute("fraction") == "100") correctAnswer = i;
        answers.add(xmlAnswers[i].getElement("text")?.text ?? "empty");
      }

      if (name != null && text != null && correctAnswer != null) {
        Question d = Question(name, trueFalse, text, answers, correctAnswer);
        questions.add(d);
      } else {
        throw Exception("non sono stati trovati tutti i campi in una domanda: "
            'name: $name \n'
            'text: $text \n');
      }
    });
    Test(id, date, questions);
  }

  Test.fromJson(Map<String, dynamic> map)
      : id = map["id"] as String,
        date = DateTime.parse(map["date"]),
        questions = [] {
    map["questions"].forEach((value) {
      questions.add(value);
    });
  }

  Map<String, dynamic> toJson() => {
        "date": date.toString(),
      };

  static Future<int> fetchId() async {
    DatabaseReference idRef = FirebaseDatabase.instance.ref("counters");
    TransactionResult result = await idRef.runTransaction((counter) {
      if (counter == null) {
        return Transaction.abort();
      }

      Map<String, int> counterMap = Map<String, int>.from(counter as Map);
      counterMap["tests"] = (counterMap["tests"] ?? 0) + 1;
      return Transaction.success(counterMap);
    }, applyLocally: false);
    if (result.committed) {
      var idTest = result.snapshot.child("tests").value;
      return idTest as Future<int>;
    }
    return 0;
  }

  @override
  String toString() {
    String string = 'Test id:$id'
        '\n'
        'date: $date'
        '\n'
        'questions:'
        '\n\t';
    for (Question i in questions) {
      string = '$string'
          '${i.toString()}';
    }
    return string;
  }
}

class Question {
  final String name;
  final bool isTrueFalse;
  final String text;
  final List<String> answers;
  final int correctIndex;

  Question(
      this.name, this.isTrueFalse, this.text, this.answers, this.correctIndex);

  Question.placeholder()
      : name = "Domanda di prova",
        isTrueFalse = true,
        text = "Testo di prova",
        answers = ["risposta 0 giusta", "risposta 1 sbagliata"],
        correctIndex = 0;

  @override
  String toString() {
    String string = 'name: $name \n'
        '\t'
        'type: ${isTrueFalse ? 'trueFalse' : 'multiple'}'
        '\n\t'
        'text: $text'
        '\n\t'
        'answers:'
        '\n\t\t';
    for (String j in answers) {
      string = '$string $j'
          '\n\t\t';
    }
    string.trimRight();
    return string;
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "isTrueFalse": isTrueFalse,
      "text": text,
      "answers": answers.asMap(),
      "correctIndex": correctIndex
    };
  }

  Question.fromJson(Map<String, dynamic> map)
      : name = map["name"] as String,
        isTrueFalse = map["isTrueFalse"] as bool,
        text = map["text"] as String,
        answers = List<String>.from(map["answers"]),
        correctIndex = map["correctIndex"];
}

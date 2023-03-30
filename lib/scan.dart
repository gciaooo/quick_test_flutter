import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image/image.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:native_opencv/native_opencv.dart';

import 'firebase_api.dart';
import 'test.dart';

List<CameraDescription> cameras = [];

Future<Map<Test, Map<Question, bool>>?> scanDocument(
    File output, NativeOpencv cv) async {
  final mlImage = InputImage.fromFile(output);
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final recognizedText = await textRecognizer.processImage(mlImage);
  TextBlock? idBlock;
  List<TextLine> answers = [];
  List<TextLine> possibleAnswers = [];
  for (TextBlock block in recognizedText.blocks) {
    if (idBlock == null ||
        idBlock.cornerPoints[0].y < block.cornerPoints[0].y) {
      idBlock = block;
    }
    for (TextLine l in block.lines) {
      if (l.text.startsWith("D ") ||
          l.text.startsWith("O ") ||
          l.text.startsWith("0 ")) {
        answers.add(l);
      } else {
        possibleAnswers.add(l);
      }
    }
  }
  if (idBlock != null) {
    debugPrint("id: ${idBlock.text}");
  }

  List<List<TextLine>> answersGrouped = _groupAnswers(answers, possibleAnswers);
  // for (int g = 0; g < answersGrouped.length; g++) {
  //   debugPrint("GRUPPO $g");
  //   for (final a in answersGrouped[g]) {
  //     debugPrint(a.text);
  //   }
  // }

  Test? test = await FirebaseAPI.getTest(idBlock!.text);
  // debugPrint(test.toString());

  if (test != null) {
    Map<Question, List<TextLine>> questionsMap = {};
    for (final q in test.questions) {
      for (final g in answersGrouped) {
        if (g.isEmpty) {
          continue;
        }
        String gAns;
        if (g[0].text.startsWith("D ") ||
            g[0].text.startsWith("O ") ||
            g[0].text.startsWith("0 ")) {
          gAns = g[0].text.substring(2);
        } else {
          gAns = g[0].text;
        }
        bool found = false;
        if (q.isTrueFalse) {
          if (gAns == "Vero" || gAns == "Falso") {
            found = true;
          }
        } else {
          for (final a in q.answers) {
            if (a.contains(gAns)) {
              found = true;
              break;
            }
          }
        }

        if (found) {
          questionsMap[q] = g;
          break;
        }
      }
    }
    // for (final q in questionsMap.keys) {
    //   debugPrint("${q.toString()} ======>>>>>");
    //   for (final a in questionsMap[q]!) {
    //     debugPrint(a.text);
    //   }
    // }

    Map<Question, bool> entryMarks = {};

    for (Question q in questionsMap.keys) {
      Map<int, List<int>> ansCoords =
          prepareAnswerCoordinates(questionsMap[q]!);
      // int entryAns = cv.detectInputAnswer(ansCoords, output.path);
      int entryIndex = detectInputAnswerIndex(ansCoords, output);
      debugPrint("${q.name.toUpperCase()} ------- entryIndex == $entryIndex");
      if (entryIndex == -1) {
        entryMarks[q] = false;
        continue;
      }
      debugPrint("RISPOSTA ${questionsMap[q]![entryIndex].text}");
      if (q.isTrueFalse) {
        debugPrint(
            "${q.name} --> risposta corretta: ${q.correctIndex} -> ${q.answers[q.correctIndex]}");
        if (q.correctIndex == 0) {
          entryMarks[q] = questionsMap[q]![entryIndex].text.contains("Vero");
        } else {
          entryMarks[q] = questionsMap[q]![entryIndex].text.contains("Falso");
        }
      } else {
        entryMarks[q] = q.answers[q.correctIndex]
            .contains(questionsMap[q]![entryIndex].text);
      }
    }
    debugPrint("ESITO: ");
    for (Question q in entryMarks.keys) {
      debugPrint("${q.name} ------------------------>   ${entryMarks[q]}");
    }
    Map<Test, Map<Question, bool>> out = <Test, Map<Question, bool>>{
      test: entryMarks
    };
    return out;
  }
  return null;
}

int detectInputAnswerIndex(Map<int, List<int>> ansCoords, File output) {
  int count = 0;
  int xOffset = 30, yOffset = 5;
  int entryIndex = -1;
  Image? img = decodeJpg(output.readAsBytesSync());
  if (img != null) {
    for (final i in ansCoords.keys) {
      int x = (ansCoords[i]![0] - xOffset);
      int y = (ansCoords[i]![1]);
      final range = img.getRange(x, y, xOffset, yOffset);
      while (range.moveNext()) {
        Pixel pix = range.current;
        if (pix.r <= 30 && pix.g <= 30 && pix.b <= 30) {
          count++;
          entryIndex = i;
          debugPrint("PIXEL: "
              "${pix.toString()}");
          break;
        }
      }
    }
  }
  return count == 1 ? entryIndex : -1;
}

Map<int, List<int>> prepareAnswerCoordinates(List<TextLine> answers) {
  Map<int, List<int>> coords = {};
  for (int i = 0; i < answers.length; i++) {
    if (!(answers[i].text.startsWith("D ") ||
        answers[i].text.startsWith("O ") ||
        answers[i].text.startsWith("0 "))) {
      coords[i] = [answers[i].cornerPoints[0].x, answers[i].cornerPoints[0].y];
    }
  }
  return coords;
}

List<List<TextLine>> _groupAnswers(
    List<TextLine> answers, List<TextLine> possibleAnswers) {
  List<TextLine> ans = answers;

  List<List<TextLine>> grouped = [];
  int maxVertical = 30;
  for (TextLine pA in possibleAnswers) {
    for (TextLine a in answers) {
      if ((pA.cornerPoints[0].y - a.cornerPoints[0].y).abs() <= maxVertical) {
        ans.add(pA);
        break;
      }
    }
  }
  for (int i = 0; i < 2; i++) {
    grouped.add([]);
  }
  ans.sort((a, b) => a.cornerPoints[0].y.compareTo(b.cornerPoints[0].y));
  List<TextLine> ansCopy = List.from(ans);

  for (int i = 0; i < grouped.length; i++) {
    for (TextLine a in ans) {
      if ((grouped[i].isEmpty && ansCopy.contains(a)) ||
          (grouped[i].isNotEmpty &&
              !grouped[i].contains(a) &&
              ansCopy.contains(a) &&
              (grouped[i][0].cornerPoints[0].y - a.cornerPoints[0].y).abs() <=
                  maxVertical)) {
        grouped[i].add(a);
        ansCopy.remove(a);
      }
    }
  }
  return grouped;
}

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:native_opencv/native_opencv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:quick_test_flutter/firebase_api.dart';
import 'package:quick_test_flutter/pages/main_page.dart';

import '../scan.dart';

Widget screenshotPage(List<CameraDescription> cameras, String test) =>
    _ScreenshotPage(
      cameras: cameras,
      test: test,
    );

class _ScreenshotPage extends StatefulWidget {
  const _ScreenshotPage({required this.cameras, required this.test});
  final List<CameraDescription> cameras;
  final String test;

  @override
  State<_ScreenshotPage> createState() => _ScreenshotPageState();
}

class _ScreenshotPageState extends State<_ScreenshotPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final NativeOpencv cv = NativeOpencv();

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.max,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<File> cropDocument(XFile image) async {
    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory("${appDir.path}/scan");
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final input = File("${outDir.path}/input.jpg");
    final imageBytes = await image.readAsBytes();
    input.writeAsBytesSync(imageBytes, flush: true);

    final query = File("${outDir.path}/query.jpg");
    final output = File("${outDir.path}/scanned.jpg");

    final pdfFile = await FirebaseAPI.fetchPrintQuery(widget.test, outDir);
    final pdfQueryDoc = await PdfDocument.openData(pdfFile.readAsBytesSync());
    final pdfQueryPage = await pdfQueryDoc.getPage(1);
    final pdfImage = await pdfQueryPage.render(
        width: pdfQueryPage.width,
        height: pdfQueryPage.height,
        format: PdfPageImageFormat.jpeg);
    if (pdfImage != null) {
      query.writeAsBytesSync(pdfImage.bytes);
      cv.cropDocument(input.path, query.path, output.path);
      debugPrint("DONE SCAN");
    }

    return output;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scannerizza test")),
      body: FutureBuilder(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            return snapshot.connectionState == ConnectionState.done
                ? Center(child: CameraPreview(_controller))
                : const Center(
                    child: CircularProgressIndicator(),
                  );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller.takePicture();

            final input = await cropDocument(image);

            if (!mounted) return;

            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => _DisplayPicturePage(
                        imgPath: input.path, test: widget.test)));
            imageCache.clear();
          } catch (e) {
            debugPrint('$e');
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Container(height: 50.0),
      ),
    );
  }
}

class _DisplayPicturePage extends StatefulWidget {
  const _DisplayPicturePage({required this.imgPath, required this.test});
  final String imgPath;
  final String test;

  @override
  State<_DisplayPicturePage> createState() => _DisplayPicturePageState();
}

class _DisplayPicturePageState extends State<_DisplayPicturePage> {
  final NativeOpencv cv = NativeOpencv();

  void scanTest() async {
    final marking = await scanDocument(File(widget.imgPath), cv);
    if (marking != null && context.mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => markTestPage(false, true,
                  marking.keys.first, marking.entries.first.value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.file(File(widget.imgPath)),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Container(
          height: 50.0,
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).buttonTheme.colorScheme!.error),
                child: const Text(
                  "Riprova",
                ),
              ),
              FilledButton(
                onPressed: scanTest,
                child: const Text("Conferma"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

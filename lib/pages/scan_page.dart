import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:native_opencv/native_opencv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:quick_test_flutter/pages/main_page.dart';

import '../scan.dart';

Widget screenshotPage(List<CameraDescription> cameras) =>
    _ScreenshotPage(cameras: cameras);

class _ScreenshotPage extends StatefulWidget {
  const _ScreenshotPage({required this.cameras});
  final List<CameraDescription> cameras;

  @override
  State<_ScreenshotPage> createState() => _ScreenshotPageState();
}

class _ScreenshotPageState extends State<_ScreenshotPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scannerizza test")),
      body: FutureBuilder(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Center(child: Expanded(child: CameraPreview(_controller)));
            } else {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller.takePicture();

            final appDir = await getApplicationDocumentsDirectory();
            final outDir = Directory("${appDir.path}/scan");
            if (!outDir.existsSync()) {
              outDir.createSync(recursive: true);
            }

            final input = File("${outDir.path}/input.jpg");
            final imageBytes = await image.readAsBytes();
            input.writeAsBytesSync(imageBytes, flush: true);

            if (!mounted) return;

            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        _DisplayPicturePage(imgPath: input.path)));
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
  const _DisplayPicturePage({required this.imgPath});
  final String imgPath;

  @override
  State<_DisplayPicturePage> createState() => _DisplayPicturePageState(imgPath);
}

class _DisplayPicturePageState extends State<_DisplayPicturePage> {
  _DisplayPicturePageState(this.imgPath);
  String imgPath;
  final NativeOpencv cv = NativeOpencv();

  void scanTest() async {
    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory("${appDir.path}/scan");
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final input = File(imgPath);
    // final input = File("${outDir.path}/input.jpg");
    final query = File("${outDir.path}/query.jpeg");
    final output = File("${outDir.path}/scanned.jpg");

    final pdfQueryDoc = await PdfDocument.openFile("${outDir.path}/test.pdf");
    final pdfQueryPage = await pdfQueryDoc.getPage(1);
    final pdfImage = await pdfQueryPage.render(
        width: pdfQueryPage.width,
        height: pdfQueryPage.height,
        format: PdfPageImageFormat.jpeg);
    if (pdfImage != null) {
      query.writeAsBytesSync(pdfImage.bytes);
      // cv.cropDocument(widget.imgPath, query.path, output.path);
      cv.cropDocument(input.path, query.path, output.path);
      debugPrint("DONE SCAN");
      setState(() {
        imgPath = output.path;
      });
      final marking = await scanDocument(output, cv);
      if (marking != null && context.mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => markTestPage(false, true,
                    marking.keys.first, marking.entries.first.value)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.file(File(imgPath)),
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

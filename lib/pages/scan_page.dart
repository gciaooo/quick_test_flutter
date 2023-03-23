import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:native_opencv/native_opencv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

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
              return CameraPreview(_controller);
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
    );
  }
}

class _DisplayPicturePage extends StatefulWidget {
  _DisplayPicturePage({required this.imgPath});
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      children: [
        Image.file(File(imgPath)),
        Row(
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
        )
      ],
    ));
  }
}

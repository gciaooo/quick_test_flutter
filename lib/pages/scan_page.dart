import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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

            if (!mounted) return;

            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        _DisplayPicturePage(imgPath: image.path)));
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

class _DisplayPicturePage extends StatelessWidget {
  const _DisplayPicturePage({required this.imgPath});
  final String imgPath;

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
            const FilledButton(
              onPressed: null,
              child: Text("Conferma"),
            ),
          ],
        )
      ],
    ));
  }
}

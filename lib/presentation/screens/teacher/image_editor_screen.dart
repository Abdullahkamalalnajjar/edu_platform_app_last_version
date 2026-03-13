import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:edu_platform_app/core/constants/app_colors.dart';

class ImageEditorScreen extends StatefulWidget {
  final String imageUrl;

  const ImageEditorScreen({super.key, required this.imageUrl});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  // Drawing state
  List<DrawingPoint?> points = [];
  Color selectedColor = AppColors.primary;
  double strokeWidth = 3.0;
  bool _isLoading = true;
  ui.Image? _backgroundImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final codec = await ui.instantiateImageCodec(bytes);
        final frameInfo = await codec.getNextFrame();
        setState(() {
          _backgroundImage = frameInfo.image;
          _isLoading = false;
        });
      } else {
        // Handle error?
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading image for editing: $e');
      setState(() => _isLoading = false);
    }
  }

  void _undo() {
    if (points.isNotEmpty) {
      setState(() {
        // Remove the last stroke (sequence of points until null)
        // We look for the last null from the end, ignoring the very last one if it is null
        // Actually, simpler: remove points until we hit a null (break).
        // But points defines continuous lines separated by nulls.

        // Find the start of the last stroke
        int lastStrokeEnd = points.length - 1;
        // If the list ends with null (which it usually does after finishing a stroke), skip it
        if (points.isNotEmpty && points.last == null) {
          lastStrokeEnd--;
        }

        while (lastStrokeEnd >= 0 && points[lastStrokeEnd] != null) {
          lastStrokeEnd--;
        }
        // Now lastStrokeEnd is the index of the null BEFORE the last stroke (or -1).
        // We want to keep everything up to and including that null.
        points.removeRange(lastStrokeEnd + 1, points.length);
        // Ensure we don't have trailing nulls if we want cleaner list, currently not strict
      });
    }
  }

  void _clear() {
    setState(() {
      points.clear();
    });
  }

  Future<void> _save() async {
    if (_backgroundImage == null) return;

    // Create a recorder to draw the image and the points onto
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw background
    canvas.drawImage(_backgroundImage!, Offset.zero, Paint());

    // Draw points (strokes)
    Paint paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin
          .round // Smoother lines
      ..style = PaintingStyle.stroke; // Important!

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        paint.color = points[i]!.paint.color;
        paint.strokeWidth = points[i]!.paint.strokeWidth;
        canvas.drawLine(points[i]!.offset, points[i + 1]!.offset, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      _backgroundImage!.width,
      _backgroundImage!.height,
    );
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    if (pngBytes != null) {
      Navigator.pop(context, pngBytes.buffer.asUint8List());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'تعديل الإجابة',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: () => _undo()),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _backgroundImage == null ? null : () => _save(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _backgroundImage == null
          ? const Center(
              child: Text(
                'فشل تحميل الصورة',
                style: TextStyle(color: Colors.white),
              ),
            )
          : Center(
              // Center the interactive viewer
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate scale to fit image in screen while maintaining aspect ratio
                  final double imageAspectRatio =
                      _backgroundImage!.width / _backgroundImage!.height;
                  final double screenAspectRatio =
                      constraints.maxWidth / constraints.maxHeight;

                  double displayWidth, displayHeight;

                  if (imageAspectRatio > screenAspectRatio) {
                    // Image is wider than screen
                    displayWidth = constraints.maxWidth;
                    displayHeight = displayWidth / imageAspectRatio;
                  } else {
                    // Image is taller than screen
                    displayHeight = constraints.maxHeight;
                    displayWidth = displayHeight * imageAspectRatio;
                  }

                  return Container(
                    width: displayWidth,
                    height: displayHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                    ),
                    child: GestureDetector(
                      onPanStart: (details) {
                        // Correct local position based on the container size vs image size ratio
                        // Actually CustomPainter draws in its own coordinate system (0 to width)
                        // We need to map the touch coordinates to the IMAGE coordinates.

                        RenderBox renderBox =
                            context.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.globalPosition,
                        );

                        // Scale factor
                        double scaleX = _backgroundImage!.width / displayWidth;
                        double scaleY =
                            _backgroundImage!.height / displayHeight;

                        setState(() {
                          points.add(
                            DrawingPoint(
                              offset: Offset(
                                localPosition.dx * scaleX,
                                localPosition.dy * scaleY,
                              ),
                              paint: Paint()
                                ..color = selectedColor
                                ..isAntiAlias = true
                                ..strokeWidth =
                                    strokeWidth *
                                    scaleX, // Scale stroke too? Maybe
                            ),
                          );
                        });
                      },
                      onPanUpdate: (details) {
                        RenderBox renderBox =
                            context.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.globalPosition,
                        );

                        // Scale factor
                        double scaleX = _backgroundImage!.width / displayWidth;
                        double scaleY =
                            _backgroundImage!.height / displayHeight;

                        // Boundary check to stop drawing outside
                        if (localPosition.dx >= 0 &&
                            localPosition.dx <= displayWidth &&
                            localPosition.dy >= 0 &&
                            localPosition.dy <= displayHeight) {
                          setState(() {
                            points.add(
                              DrawingPoint(
                                offset: Offset(
                                  localPosition.dx * scaleX,
                                  localPosition.dy * scaleY,
                                ),
                                paint: Paint()
                                  ..color = selectedColor
                                  ..isAntiAlias = true
                                  ..strokeWidth = strokeWidth * scaleX,
                              ),
                            );
                          });
                        }
                      },
                      onPanEnd: (details) {
                        setState(() {
                          points.add(null);
                        });
                      },
                      child: CustomPaint(
                        painter: ImagePainter(
                          backgroundImage: _backgroundImage!,
                          points: points,
                        ),
                        size: Size(displayWidth, displayHeight),
                      ),
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildColorChanger(AppColors.primary),
            _buildColorChanger(Colors.red),
            _buildColorChanger(Colors.green),
            _buildColorChanger(Colors.blue),
            _buildColorChanger(Colors.yellow),
            // Eraser (just draw transparent? No, that doesn't work on base image layer easily without layers.
            // Eraser usually paints with background color or clears pixels.
            // Simple "Eraser" here can just be "White" if paper is white, but background is an image.
            // So real eraser needs Paint with BlendMode.clear (only works if background is separate layer)
            // For now, let's stick to markers since it's "grading".
            // Maybe black to cover up?
            _buildColorChanger(Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildColorChanger(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
        });
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selectedColor == color
              ? Border.all(color: Colors.white, width: 3)
              : null,
        ),
      ),
    );
  }
}

class DrawingPoint {
  Offset offset;
  Paint paint;
  DrawingPoint({required this.offset, required this.paint});
}

class ImagePainter extends CustomPainter {
  final ui.Image backgroundImage;
  final List<DrawingPoint?> points;

  ImagePainter({required this.backgroundImage, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Background Image
    // The canvas size here is the display size.
    // We want to fit the image into this size.
    // But wait, in the logic above, I scaled the Touch Points to Image Coordinates.
    // So the Painter should draw in Image Coordinates, but calculate scale to fit Canvas (Display)?
    // OR, simpler:
    // Scale the Canvas to match the Image size, then draw everything in Image coordinates.

    double scaleX = size.width / backgroundImage.width;
    double scaleY = size.height / backgroundImage.height;

    canvas.scale(scaleX, scaleY); // Scale coordinate system

    canvas.drawImage(backgroundImage, Offset.zero, Paint());

    // 2. Draw Points
    Paint paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      // Points are already stored in Image Coordinates!
      if (points[i] != null && points[i + 1] != null) {
        paint.color = points[i]!.paint.color;
        paint.strokeWidth = points[i]!.paint.strokeWidth;
        canvas.drawLine(points[i]!.offset, points[i + 1]!.offset, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    return true;
  }
}

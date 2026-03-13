import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';
import 'package:image/image.dart' as img;

class CustomImageCropScreen extends StatefulWidget {
  final String imagePath;

  const CustomImageCropScreen({super.key, required this.imagePath});

  @override
  State<CustomImageCropScreen> createState() => _CustomImageCropScreenState();
}

class _CustomImageCropScreenState extends State<CustomImageCropScreen> {
  img.Image? _originalImage;
  bool _isLoading = true;

  // Crop area values
  int _x = 0;
  int _y = 0;
  int _width = 0;
  int _height = 0;

  // Image dimensions
  int _imageWidth = 0;
  int _imageHeight = 0;

  // Interactive dragging
  Offset? _dragStart;
  Offset? _dragEnd;
  bool _isDragging = false;
  String _dragMode = 'none'; // 'none', 'move', 'resize', 'new'
  String _resizeCorner =
      'none'; // 'topLeft', 'topRight', 'bottomLeft', 'bottomRight'
  int _initialCropX = 0;
  int _initialCropY = 0;
  int _initialCropWidth = 0;
  int _initialCropHeight = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final image = img.decodeImage(bytes);

      if (image != null) {
        setState(() {
          _originalImage = image;
          _imageWidth = image.width;
          _imageHeight = image.height;
          _width = image.width;
          _height = image.height;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الصورة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _cropAndSave() async {
    if (_originalImage == null) return;

    setState(() => _isLoading = true);

    try {
      // Crop the image
      final croppedImage = img.copyCrop(
        _originalImage!,
        x: _x,
        y: _y,
        width: _width,
        height: _height,
      );

      // Encode to bytes
      final croppedBytes = img.encodeJpg(croppedImage, quality: 85);

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(croppedBytes);

      if (mounted) {
        Navigator.pop(context, tempFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في قص الصورة: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetCrop() {
    setState(() {
      _x = 0;
      _y = 0;
      _width = _imageWidth;
      _height = _imageHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'قص الصورة',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _resetCrop,
              tooltip: 'إعادة تعيين',
            ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: _cropAndSave,
              tooltip: 'حفظ',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildImagePreview(),
              ),
            ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Original image
              Image.file(File(widget.imagePath), fit: BoxFit.contain),

              // Crop overlay with interactive handles
              if (_originalImage != null)
                CustomPaint(
                  size: Size.infinite,
                  painter: CropOverlayPainter(
                    imageWidth: _imageWidth,
                    imageHeight: _imageHeight,
                    cropX: _x,
                    cropY: _y,
                    cropWidth: _width,
                    cropHeight: _height,
                  ),
                ),

              // Instruction hint
              if (!_isDragging)
                Positioned(
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.touch_app,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'اسحب على الصورة لتحديد المنطقة',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    // Get the render box to calculate positions
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final containerWidth = box.size.width;
    final containerHeight = 400.0;

    final scaleX = containerWidth / _imageWidth;
    final scaleY = containerHeight / _imageHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledImageWidth = _imageWidth * scale;
    final scaledImageHeight = _imageHeight * scale;

    final offsetX = (containerWidth - scaledImageWidth) / 2;
    final offsetY = (containerHeight - scaledImageHeight) / 2;

    // Convert touch position to image coordinates
    final touchX = ((details.localPosition.dx - offsetX) / scale).clamp(
      0,
      _imageWidth.toDouble(),
    );
    final touchY = ((details.localPosition.dy - offsetY) / scale).clamp(
      0,
      _imageHeight.toDouble(),
    );

    // Calculate crop rectangle corners in image coordinates
    final cropLeft = _x.toDouble();
    final cropRight = (_x + _width).toDouble();
    final cropTop = _y.toDouble();
    final cropBottom = (_y + _height).toDouble();

    // Check if touch is on a corner (for resizing)
    // Use 40 logical pixels divided by scale to get image pixels tolerance
    // This ensures consistent touch target size regardless of image resolution
    final cornerTolerance = 40.0 / scale;

    bool isNearTopLeft =
        (touchX - cropLeft).abs() < cornerTolerance &&
        (touchY - cropTop).abs() < cornerTolerance;
    bool isNearTopRight =
        (touchX - cropRight).abs() < cornerTolerance &&
        (touchY - cropTop).abs() < cornerTolerance;
    bool isNearBottomLeft =
        (touchX - cropLeft).abs() < cornerTolerance &&
        (touchY - cropBottom).abs() < cornerTolerance;
    bool isNearBottomRight =
        (touchX - cropRight).abs() < cornerTolerance &&
        (touchY - cropBottom).abs() < cornerTolerance;

    // Check if touch is inside crop area (for moving)
    final isInsideCrop =
        touchX >= cropLeft &&
        touchX <= cropRight &&
        touchY >= cropTop &&
        touchY <= cropBottom;

    setState(() {
      _isDragging = true;
      _dragStart = details.localPosition;
      _dragEnd = details.localPosition;

      // Determine drag mode
      if (isNearTopLeft ||
          isNearTopRight ||
          isNearBottomLeft ||
          isNearBottomRight) {
        // Resize mode - resize from the selected corner
        _dragMode = 'resize';

        // Determine which corner is being dragged
        if (isNearTopLeft) {
          _resizeCorner = 'topLeft';
        } else if (isNearTopRight) {
          _resizeCorner = 'topRight';
        } else if (isNearBottomLeft) {
          _resizeCorner = 'bottomLeft';
        } else if (isNearBottomRight) {
          _resizeCorner = 'bottomRight';
        }

        // Store initial crop values for resizing
        _initialCropX = _x;
        _initialCropY = _y;
        _initialCropWidth = _width;
        _initialCropHeight = _height;
      } else if (isInsideCrop) {
        // Move mode - will move the existing crop area
        _dragMode = 'move';
        // Store initial crop position for moving
        _initialCropX = _x;
        _initialCropY = _y;
      } else {
        // New crop mode - create new crop area
        _dragMode = 'new';
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragEnd = details.localPosition;

      if (_dragMode == 'move') {
        _updateCropMove();
      } else if (_dragMode == 'resize') {
        _updateCropResize();
      } else {
        _updateCropFromDrag();
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Store the current drag mode before resetting
    final currentDragMode = _dragMode;

    setState(() {
      _isDragging = false;

      // Use the stored drag mode to determine which update function to call
      if (currentDragMode == 'move') {
        _updateCropMove();
      } else if (currentDragMode == 'resize') {
        _updateCropResize();
      } else {
        _updateCropFromDrag();
      }

      // Reset drag mode AFTER using it
      _dragMode = 'none';
      _resizeCorner = 'none';
    });
  }

  void _updateCropMove() {
    if (_dragStart == null || _dragEnd == null) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final containerWidth = box.size.width;
    final containerHeight = 400.0;

    final scaleX = containerWidth / _imageWidth;
    final scaleY = containerHeight / _imageHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate movement delta in image coordinates
    final deltaX = ((_dragEnd!.dx - _dragStart!.dx) / scale).toInt();
    final deltaY = ((_dragEnd!.dy - _dragStart!.dy) / scale).toInt();

    // Apply movement to crop position
    _x = (_initialCropX + deltaX).clamp(0, _imageWidth - _width);
    _y = (_initialCropY + deltaY).clamp(0, _imageHeight - _height);

    // Update controllers removed
  }

  void _updateCropResize() {
    if (_dragStart == null || _dragEnd == null) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final containerWidth = box.size.width;
    final containerHeight = 400.0;

    final scaleX = containerWidth / _imageWidth;
    final scaleY = containerHeight / _imageHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate movement delta in image coordinates
    final deltaX = ((_dragEnd!.dx - _dragStart!.dx) / scale).toInt();
    final deltaY = ((_dragEnd!.dy - _dragStart!.dy) / scale).toInt();

    // Apply resize based on which corner is being dragged
    switch (_resizeCorner) {
      case 'topLeft':
        // Moving top-left corner: adjust x, y, width, height
        _x = (_initialCropX + deltaX).clamp(
          0,
          _initialCropX + _initialCropWidth - 10,
        );
        _y = (_initialCropY + deltaY).clamp(
          0,
          _initialCropY + _initialCropHeight - 10,
        );
        _width = (_initialCropWidth - deltaX).clamp(10, _imageWidth - _x);
        _height = (_initialCropHeight - deltaY).clamp(10, _imageHeight - _y);
        break;

      case 'topRight':
        // Moving top-right corner: adjust y, width, height
        _y = (_initialCropY + deltaY).clamp(
          0,
          _initialCropY + _initialCropHeight - 10,
        );
        _width = (_initialCropWidth + deltaX).clamp(
          10,
          _imageWidth - _initialCropX,
        );
        _height = (_initialCropHeight - deltaY).clamp(10, _imageHeight - _y);
        break;

      case 'bottomLeft':
        // Moving bottom-left corner: adjust x, width, height
        _x = (_initialCropX + deltaX).clamp(
          0,
          _initialCropX + _initialCropWidth - 10,
        );
        _width = (_initialCropWidth - deltaX).clamp(10, _imageWidth - _x);
        _height = (_initialCropHeight + deltaY).clamp(
          10,
          _imageHeight - _initialCropY,
        );
        break;

      case 'bottomRight':
        // Moving bottom-right corner: adjust width, height
        _width = (_initialCropWidth + deltaX).clamp(
          10,
          _imageWidth - _initialCropX,
        );
        _height = (_initialCropHeight + deltaY).clamp(
          10,
          _imageHeight - _initialCropY,
        );
        break;
    }

    // Update controllers removed
  }

  void _updateCropFromDrag() {
    if (_dragStart == null || _dragEnd == null) return;

    // Get the render box to calculate the actual image position
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Calculate the scale factor
    final containerWidth = box.size.width;
    final containerHeight = 400.0; // Max height from constraints

    final scaleX = containerWidth / _imageWidth;
    final scaleY = containerHeight / _imageHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledImageWidth = _imageWidth * scale;
    final scaledImageHeight = _imageHeight * scale;

    final offsetX = (containerWidth - scaledImageWidth) / 2;
    final offsetY = (containerHeight - scaledImageHeight) / 2;

    // Convert screen coordinates to image coordinates
    final startX = ((_dragStart!.dx - offsetX) / scale).clamp(
      0,
      _imageWidth.toDouble(),
    );
    final startY = ((_dragStart!.dy - offsetY) / scale).clamp(
      0,
      _imageHeight.toDouble(),
    );
    final endX = ((_dragEnd!.dx - offsetX) / scale).clamp(
      0,
      _imageWidth.toDouble(),
    );
    final endY = ((_dragEnd!.dy - offsetY) / scale).clamp(
      0,
      _imageHeight.toDouble(),
    );

    // Calculate crop rectangle
    final left = startX < endX ? startX : endX;
    final top = startY < endY ? startY : endY;
    final right = startX > endX ? startX : endX;
    final bottom = startY > endY ? startY : endY;

    final width = (right - left).toInt().clamp(1, _imageWidth);
    final height = (bottom - top).toInt().clamp(1, _imageHeight);

    // Update crop values
    _x = left.toInt().clamp(0, _imageWidth - 1);
    _y = top.toInt().clamp(0, _imageHeight - 1);
    _width = width;
    _height = height;

    // Update controllers removed
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class CropOverlayPainter extends CustomPainter {
  final int imageWidth;
  final int imageHeight;
  final int cropX;
  final int cropY;
  final int cropWidth;
  final int cropHeight;

  CropOverlayPainter({
    required this.imageWidth,
    required this.imageHeight,
    required this.cropX,
    required this.cropY,
    required this.cropWidth,
    required this.cropHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale to fit image in container
    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledImageWidth = imageWidth * scale;
    final scaledImageHeight = imageHeight * scale;

    final offsetX = (size.width - scaledImageWidth) / 2;
    final offsetY = (size.height - scaledImageHeight) / 2;

    // Calculate crop rectangle
    final cropRect = Rect.fromLTWH(
      offsetX + (cropX * scale),
      offsetY + (cropY * scale),
      cropWidth * scale,
      cropHeight * scale,
    );

    // Draw semi-transparent overlay on non-crop areas
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.3);

    // Draw overlay on all four sides of the crop area
    // Top
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, cropRect.top),
      overlayPaint,
    );
    // Bottom
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        cropRect.bottom,
        size.width,
        size.height - cropRect.bottom,
      ),
      overlayPaint,
    );
    // Left
    canvas.drawRect(
      Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height),
      overlayPaint,
    );
    // Right
    canvas.drawRect(
      Rect.fromLTWH(
        cropRect.right,
        cropRect.top,
        size.width - cropRect.right,
        cropRect.height,
      ),
      overlayPaint,
    );

    // Draw RED crop border
    final borderPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(cropRect, borderPaint);

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      final x = cropRect.left + (cropRect.width * i / 3);
      canvas.drawLine(
        Offset(x, cropRect.top),
        Offset(x, cropRect.bottom),
        gridPaint,
      );
    }

    // Horizontal lines
    for (int i = 1; i < 3; i++) {
      final y = cropRect.top + (cropRect.height * i / 3);
      canvas.drawLine(
        Offset(cropRect.left, y),
        Offset(cropRect.right, y),
        gridPaint,
      );
    }

    // Draw RED corner handles
    final handlePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    const handleSize = 12.0;
    final corners = [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, handleSize / 2, handlePaint);
      canvas.drawCircle(
        corner,
        handleSize / 2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(CropOverlayPainter oldDelegate) {
    return oldDelegate.cropX != cropX ||
        oldDelegate.cropY != cropY ||
        oldDelegate.cropWidth != cropWidth ||
        oldDelegate.cropHeight != cropHeight;
  }
}

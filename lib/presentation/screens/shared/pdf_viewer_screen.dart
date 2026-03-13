import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_platform_app/core/constants/app_colors.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final bool isLocal;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.isLocal = false,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void dispose() {
    // Clean up controller to free memory
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'خطأ في تحميل الملف',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'رجوع',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                widget.isLocal
                    ? SfPdfViewer.file(
                        File(widget.pdfUrl),
                        key: _pdfViewerKey,
                        controller: _pdfViewerController,
                        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        },
                        onDocumentLoadFailed:
                            (PdfDocumentLoadFailedDetails details) {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                  _errorMessage = details.error;
                                });
                              }
                            },
                        // Memory optimization settings
                        enableTextSelection: false,
                        canShowTextSelectionMenu: false,
                        canShowScrollHead: true,
                        canShowPaginationDialog: true,
                        enableDoubleTapZooming: true,
                        pageLayoutMode: PdfPageLayoutMode.continuous,
                        // Enable page caching for better performance
                        enableDocumentLinkAnnotation: false,
                      )
                    : SfPdfViewer.network(
                        widget.pdfUrl,
                        key: _pdfViewerKey,
                        controller: _pdfViewerController,
                        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        },
                        onDocumentLoadFailed:
                            (PdfDocumentLoadFailedDetails details) {
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                  _errorMessage = details.error;
                                });
                              }
                            },
                        // Memory optimization settings
                        enableTextSelection: false,
                        canShowTextSelectionMenu: false,
                        canShowScrollHead: true,
                        canShowPaginationDialog: true,
                        enableDoubleTapZooming: true,
                        pageLayoutMode: PdfPageLayoutMode.continuous,
                        // Enable page caching for better performance
                        enableDocumentLinkAnnotation: false,
                      ),
                if (_isLoading)
                  Container(
                    color: AppColors.background.withOpacity(0.9),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'جاري تحميل الملف...',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

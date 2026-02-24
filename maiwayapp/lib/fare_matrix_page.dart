import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class FareMatrixPage extends StatelessWidget {
  const FareMatrixPage({super.key});

  // Theme Colors
  final Color primaryBlue = const Color(0xFF1A5276);
  final Color skyBlueBackground = const Color(0xFF91C9F1);

  // Organized PDF file names
  static const ltfrbfarePdfs = {
    'PUJ Fare Guide': 'pujfare.pdf',
    'PUB (Ordinary) Fare Guide': 'busordinaryfare.pdf',
    'PUB (Aircon) Fare Guide': 'busairconfare.pdf',
  };
  static const mtpbFarePdfs = {'Ordinance No. 8979': 'ordinanceno8979.pdf'};
  static const lrtFarePdfs = {'LRT 1 Fare': 'lrt1routefare.pdf'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: skyBlueBackground,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Fare Matrices',
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          const SizedBox(height: 10),
          _buildCategory(
            context,
            icon: Icons.payments_rounded,
            title: 'LTFRB Fare Guides',
            pdfs: ltfrbfarePdfs,
            previewOnly: false,
          ),
          _buildCategory(
            context,
            icon: Icons.motorcycle_rounded,
            title: 'MTPB Fare Rates',
            pdfs: mtpbFarePdfs,
            previewOnly: false,
          ),
          _buildCategory(
            context,
            icon: Icons.train_rounded,
            title: 'LRT Fare Tables',
            pdfs: lrtFarePdfs,
            previewOnly: false,
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Map<String, String> pdfs,
    required bool previewOnly,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: skyBlueBackground.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryBlue),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: primaryBlue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          children:
              pdfs.entries
                  .map(
                    (entry) => PdfTile(
                      title: entry.key,
                      assetPath: 'assets/images/${entry.value}',
                      previewOnly: previewOnly,
                      primaryColor: primaryBlue,
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class PdfTile extends StatelessWidget {
  final String title;
  final String assetPath;
  final bool previewOnly;
  final Color primaryColor;

  const PdfTile({
    super.key,
    required this.title,
    required this.assetPath,
    required this.previewOnly,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(
          Icons.picture_as_pdf_rounded,
          color: Colors.redAccent.shade200,
          size: 20,
        ),
        onTap: () {
          if (previewOnly) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No preview available for $title'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => PDFViewerPage(pdfAssetPath: assetPath, title: title),
              ),
            );
          }
        },
      ),
    );
  }
}

class PDFViewerPage extends StatelessWidget {
  final String pdfAssetPath;
  final String title;

  const PDFViewerPage({
    super.key,
    required this.pdfAssetPath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF1A5276);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          title,
          style: TextStyle(
            color: primaryBlue,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SfPdfViewer.asset(pdfAssetPath),
    );
  }
}

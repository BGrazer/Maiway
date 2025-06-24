import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class FareMatrixPage extends StatelessWidget {
  const FareMatrixPage({super.key});

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
      appBar: AppBar(centerTitle: true, title: const Text('Fare Matrices')),
      body: ListView(
        children: [
          _buildCategory(
            context,
            icon: Icons.directions_bus,
            title: 'LTFRB',
            pdfs: ltfrbfarePdfs,
            previewOnly: false,
          ),
          _buildCategory(
            context,
            icon: Icons.motorcycle,
            title: 'MTPB',
            pdfs: mtpbFarePdfs,
            previewOnly: false,
          ),
          _buildCategory(
            context,
            icon: Icons.train,
            title: 'LRT',
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
    return ExpansionTile(
      leading: Icon(icon),
      title: Text(title),
      children:
          pdfs.entries
              .map(
                (entry) => PdfTile(
                  title: entry.key,
                  assetPath: 'assets/images/${entry.value}',
                  previewOnly: previewOnly,
                ),
              )
              .toList(),
    );
  }
}

class PdfTile extends StatelessWidget {
  final String title;
  final String assetPath;
  final bool previewOnly;

  const PdfTile({
    super.key,
    required this.title,
    required this.assetPath,
    required this.previewOnly,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.picture_as_pdf),
      onTap: () {
        if (previewOnly) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No preview available for $title')),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PDFViewerPage(pdfAssetPath: assetPath),
            ),
          );
        }
      },
    );
  }
}

class PDFViewerPage extends StatelessWidget {
  final String pdfAssetPath;

  const PDFViewerPage({super.key, required this.pdfAssetPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('PDF Viewer')),
      body: SfPdfViewer.asset(pdfAssetPath),
    );
  }
}

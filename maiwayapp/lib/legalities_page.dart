import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class LegalitiesPage extends StatelessWidget {
  const LegalitiesPage({super.key});

  // Organized PDF file names
  static const ltfrbPdfs = {
    'NCR Consolidation - PUJ with Consolidation': 'pujwithconso.pdf',
    'NCR Consolidation - PUJ without Consolidation': 'pujwithoutconso.pdf',
    'City Bus Routes 1': 'busroute1.pdf',
    'City Bus Routes 2': 'busroute2.pdf',
  };
  static const mtpbPdfs = {
    'Ordinance No. 9091': 'ordinanceno9091.pdf',
    'Ordinance No. 8979': 'ordinanceno8979.pdf',
    'D1-D6 Toda List': 'd1-6toda.pdf',
  };
  static const lrtPdfs = {'LRT 1 Route': 'lrt1routefare.pdf'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Legalities of Transportation'),
      ),
      body: ListView(
        children: [
          _buildCategory(
            context,
            icon: Icons.directions_bus,
            title: 'LTFRB',
            pdfs: ltfrbPdfs,
            previewOnly: true,
          ),
          _buildCategory(
            context,
            icon: Icons.motorcycle,
            title: 'MTPB',
            pdfs: mtpbPdfs,
            previewOnly: false,
          ),
          _buildCategory(
            context,
            icon: Icons.train,
            title: 'LRT',
            pdfs: lrtPdfs,
            previewOnly: true,
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

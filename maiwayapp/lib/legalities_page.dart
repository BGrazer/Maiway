import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class LegalitiesPage extends StatelessWidget {
  const LegalitiesPage({Key? key}) : super(key: key);

  // Only retain regform.pdf for MTPB
  static const ltfrbPdfs = ['LTFRB Guidelines.pdf', 'LTFRB Memo.pdf'];
  static const mtpbPdfs = ['summser.pdf'];
  static const lrtPdfs = ['LRT Safety.pdf'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legalities of Transportation')),
      body: ListView(
        children: [
          ExpansionTile(
            leading: const Icon(Icons.directions_bus),
            title: const Text('LTFRB'),
            children:
                ltfrbPdfs
                    .map(
                      (pdf) => ListTile(
                        title: Text(pdf),
                        trailing: const Icon(Icons.picture_as_pdf),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No preview available for $pdf'),
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
          ),
          ExpansionTile(
            leading: const Icon(Icons.motorcycle),
            title: const Text('MTPB'),
            children:
                mtpbPdfs
                    .map(
                      (pdf) => ListTile(
                        title: Text(pdf),
                        trailing: const Icon(Icons.picture_as_pdf),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => PDFViewerPage(
                                    pdfAssetPath: 'assets/$pdf',
                                  ),
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
          ),
          ExpansionTile(
            leading: const Icon(Icons.train),
            title: const Text('LRT'),
            children:
                lrtPdfs
                    .map(
                      (pdf) => ListTile(
                        title: Text(pdf),
                        trailing: const Icon(Icons.picture_as_pdf),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No preview available for $pdf'),
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class PDFViewerPage extends StatelessWidget {
  final String pdfAssetPath;

  const PDFViewerPage({Key? key, required this.pdfAssetPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Viewer')),
      body: SfPdfViewer.asset(pdfAssetPath),
    );
  }
}

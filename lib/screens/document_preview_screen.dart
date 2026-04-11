import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:docx_creator/docx_creator.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final List<String> imagePaths;

  const DocumentPreviewScreen({super.key, required this.imagePaths});

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  bool _isProcessing = false;
  String _ocrText = '';

  Future<void> _extractText(String imagePath) async {
    setState(() => _isProcessing = true);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      setState(() {
        _ocrText = recognizedText.text;
      });
      
      textRecognizer.close();
      
      if (mounted) {
        _showOcrResultDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no OCR: $e')));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showOcrResultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Texto Extraído'),
        content: SingleChildScrollView(
          child: Text(_ocrText.isEmpty ? 'Nenhum texto encontrado.' : _ocrText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDocumentHistory(String title, String path, int size, String type) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> docs = prefs.getStringList('scanned_docs') ?? [];
    final docInfo = {
      'title': title,
      'path': path,
      'date': DateTime.now().toIso8601String(),
      'size': size,
      'type': type,
    };
    docs.insert(0, jsonEncode(docInfo));
    await prefs.setStringList('scanned_docs', docs);
  }

  Future<void> _saveAsPdf() async {
    setState(() => _isProcessing = true);
    try {
      final pdf = pw.Document();

      for (var path in widget.imagePaths) {
        final image = pw.MemoryImage(
          File(path).readAsBytesSync(),
        );

        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(image),
              );
            },
          ),
        );
      }

      final output = await getApplicationDocumentsDirectory();
      final String title = "Documento_${DateTime.now().millisecondsSinceEpoch}";
      final pdfPath = "${output.path}/$title.pdf";
      final file = File(pdfPath);
      await file.writeAsBytes(await pdf.save());

      await _saveDocumentHistory(title, pdfPath, await file.length(), 'PDF');

      if (mounted) {
        Navigator.pop(context); // Goes back to Home
        await OpenFilex.open(pdfPath);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar PDF: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveAsDocx() async {
    setState(() => _isProcessing = true);
    try {
      var builder = docx();
      builder.h1('Documento Escaneado');

      builder.p('Texto extraído pelo ScannerPro:');
      for (var i = 0; i < widget.imagePaths.length; i++) {
        final inputImage = InputImage.fromFilePath(widget.imagePaths[i]);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        builder.h3('Página ${i + 1}');
        builder.p(recognizedText.text);
        textRecognizer.close();
      }

      final doc = builder.build();

      final output = await getApplicationDocumentsDirectory();
      final String title = "Word_OCR_${DateTime.now().millisecondsSinceEpoch}";
      final docxPath = "${output.path}/$title.docx";
      
      final file = File(docxPath);
      await DocxExporter().exportToFile(doc, docxPath);

      await _saveDocumentHistory(title, docxPath, await file.length(), 'DOCX');

      if (mounted) {
        Navigator.pop(context); // Goes back to Home
        await OpenFilex.open(docxPath);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar DOCX: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveAsJpegs() async {
    setState(() => _isProcessing = true);
    try {
      final output = await getApplicationDocumentsDirectory();
      
      for (var i = 0; i < widget.imagePaths.length; i++) {
        final String title = "Imagem_${i+1}_${DateTime.now().millisecondsSinceEpoch}";
        final String destPath = "${output.path}/$title.jpg";
        final file = await File(widget.imagePaths[i]).copy(destPath);
        await _saveDocumentHistory(title, destPath, await file.length(), 'JPEG');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imagens salvas avulsas!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exportar imagens: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showExportOptionsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E212D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Como deseja Exportar?',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildActionTile(
                  icon: Icons.picture_as_pdf, color: Colors.redAccent, 
                  title: 'Salvar Livreto (PDF)', subtitle: 'Juntar páginas em único PDF',
                  onTap: () {
                    Navigator.pop(context);
                    _saveAsPdf();
                  }
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.text_snippet, color: const Color(0xFFAA00FF), 
                  title: 'Salvar Word Lindo (DOCX)', subtitle: 'Somente texto extraído de fotos',
                  onTap: () {
                    Navigator.pop(context);
                    _saveAsDocx(); // DOCX Only Text OCR
                  }
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.image, color: const Color(0xFF00E5FF), 
                  title: 'Salvar Imagens Soltas (JPEG)', subtitle: 'Fotos originais avulsas',
                  onTap: () {
                    Navigator.pop(context);
                    _saveAsJpegs();
                  }
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 28),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Colors.white.withOpacity(0.02),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${widget.imagePaths.length} Páginas', style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt, color: Color(0xFF00E5FF)),
            onPressed: _isProcessing ? null : _showExportOptionsDialog,
            tooltip: 'Exportar Documento',
          ),
        ],
      ),
      body: _isProcessing 
        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: Color(0xFF00E5FF)),
            SizedBox(height: 16),
            Text('Processando as páginas...', style: TextStyle(color: Colors.white54))
          ]))
        : ListView.builder(
            itemCount: widget.imagePaths.length,
            itemBuilder: (context, index) {
              final path = widget.imagePaths[index];
              return Card(
                color: const Color(0xFF1E212D),
                margin: const EdgeInsets.all(16),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Image.file(File(path)),
                    Container(
                      color: Colors.black12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.text_fields, color: Colors.orangeAccent),
                            label: const Text('Prever Texto (OCR)', style: TextStyle(color: Colors.white70)),
                            onPressed: () => _extractText(path),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          ),
    );
  }
}

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:docx_creator/docx_creator.dart';
import '../utils/translations.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final List<String> imagePaths;

  const DocumentPreviewScreen({super.key, required this.imagePaths});

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  bool _isProcessing = false;
  // Estado de OCR movido para widget filho

  Future<void> _saveDocumentHistory(String title, String path, int size, String type) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> docs = prefs.getStringList('scanned_docs') ?? [];
    final docInfo = {
      'title': title,
      'path': path,
      'date': DateTime.now().toIso8601String(),
      'size': size,
      'type': type,
      'folder': '', // Initially no folder
    };
    docs.insert(0, jsonEncode(docInfo));
    await prefs.setStringList('scanned_docs', docs);
  }

  Future<void> _promptAndSave(String defaultTitle, Function(String) onConfirm) async {
    final TextEditingController nameCtrl = TextEditingController(text: defaultTitle);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E212D),
          title: Text(AppTranslations.get('rename'), style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: AppTranslations.get('new_name'),
              hintStyle: const TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(AppTranslations.get('save'), style: const TextStyle(color: Color(0xFF00E5FF))),
              onPressed: () {
                Navigator.pop(context);
                if (nameCtrl.text.isNotEmpty) {
                  onConfirm(nameCtrl.text);
                }
              },
            ),
          ],
        );
      }
    );
  }

  Future<void> _saveAsPdf() async {
    await _promptAndSave("Documento_${DateTime.now().millisecondsSinceEpoch}", (String title) async {
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
        final pdfPath = "${output.path}/$title.pdf";
        final file = File(pdfPath);
        await file.writeAsBytes(await pdf.save());

        await _saveDocumentHistory(title, pdfPath, await file.length(), 'PDF');

        if (mounted) {
          Navigator.pop(context); // Goes back to Home
          await OpenFilex.open(pdfPath);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.get('error')}: $e')));
      } finally {
        setState(() => _isProcessing = false);
      }
    });
  }

  Future<void> _saveAsDocx() async {
    await _promptAndSave("Word_${DateTime.now().millisecondsSinceEpoch}", (String title) async {
      setState(() => _isProcessing = true);
      try {
        var builder = docx();
        builder.h1(title);

        builder.p('Texto extraído pelo PDFscan:');
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
        final docxPath = "${output.path}/$title.docx";
        
        final file = File(docxPath);
        await DocxExporter().exportToFile(doc, docxPath);

        await _saveDocumentHistory(title, docxPath, await file.length(), 'DOCX');

        if (mounted) {
          Navigator.pop(context); // Goes back to Home
          await OpenFilex.open(docxPath);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.get('error')}: $e')));
      } finally {
        setState(() => _isProcessing = false);
      }
    });
  }

  Future<void> _saveAsJpegs() async {
    await _promptAndSave("Imagens_${DateTime.now().millisecondsSinceEpoch}", (String title) async {
      setState(() => _isProcessing = true);
      try {
        final output = await getApplicationDocumentsDirectory();
        
        for (var i = 0; i < widget.imagePaths.length; i++) {
          final String fileTitle = "${title}_${i+1}";
          final String destPath = "${output.path}/$fileTitle.jpg";
          final file = await File(widget.imagePaths[i]).copy(destPath);
          await _saveDocumentHistory(fileTitle, destPath, await file.length(), 'JPEG');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('success'))));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.get('error')}: $e')));
      } finally {
        setState(() => _isProcessing = false);
      }
    });
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
                Text(
                  AppTranslations.get('export_as'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildActionTile(
                  icon: Icons.picture_as_pdf, color: Colors.redAccent, 
                  title: AppTranslations.get('save_pdf'), subtitle: '',
                  onTap: () {
                    Navigator.pop(context);
                    _saveAsPdf();
                  }
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.text_snippet, color: const Color(0xFFAA00FF), 
                  title: AppTranslations.get('save_docx'), subtitle: '',
                  onTap: () {
                    Navigator.pop(context);
                    _saveAsDocx(); // DOCX Only Text OCR
                  }
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.image, color: const Color(0xFF00E5FF), 
                  title: AppTranslations.get('save_jpeg'), subtitle: '',
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
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.white54)) : null,
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
        title: Text('${widget.imagePaths.length} ${AppTranslations.get('pages')}', style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt, color: Color(0xFF00E5FF)),
            onPressed: _isProcessing ? null : _showExportOptionsDialog,
            tooltip: AppTranslations.get('export_as'),
          ),
        ],
      ),
      body: _isProcessing 
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Color(0xFF00E5FF)),
            const SizedBox(height: 16),
            Text(AppTranslations.get('processing'), style: const TextStyle(color: Colors.white54))
          ]))
        : ListView.builder(
            itemCount: widget.imagePaths.length,
            itemBuilder: (context, index) {
              final path = widget.imagePaths[index];
              return DocumentPageCard(imagePath: path);
            },
          ),
    );
  }
}

class DocumentPageCard extends StatefulWidget {
  final String imagePath;
  const DocumentPageCard({super.key, required this.imagePath});
  @override
  State<DocumentPageCard> createState() => _DocumentPageCardState();
}class _DocumentPageCardState extends State<DocumentPageCard> {
  bool _isExtracting = true;
  String _extractedText = '';

  @override
  void initState() {
    super.initState();
    _extractText(); // Extrair texto automaticamente ao carregar
  }

  Future<void> _extractText() async {
    try {
      final inputImage = InputImage.fromFilePath(widget.imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      if (mounted) {
        setState(() {
          _extractedText = recognizedText.text;
        });
      }
      textRecognizer.close();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${AppTranslations.get('error')}: \$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  Future<void> _searchInGemini() async {
    if (_isExtracting) return; // Aguarde a extração
    if (_extractedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('no_docs'))));
      return;
    }
    
    // Copiar para a área de transferência
    await Clipboard.setData(ClipboardData(text: _extractedText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\${AppTranslations.get('text_copied')} - Cole no Gemini!')));
    }
    
    // Launch Gemini
    final Uri url = Uri.parse('https://gemini.google.com/app');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch Gemini')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E212D),
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Content Area - Always show Image
          Image.file(File(widget.imagePath)),
          
          // Action Bar
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_isExtracting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 20, height: 20, 
                      child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2)
                    ),
                  ),
                if (!_isExtracting) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.copy, color: Colors.white70),
                    label: Text(AppTranslations.get('copy_text'), style: const TextStyle(color: Colors.white70)),
                    onPressed: () {
                      if (_extractedText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('no_docs'))));
                        return;
                      }
                      Clipboard.setData(ClipboardData(text: _extractedText));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('text_copied'))));
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome, color: Colors.white),
                    label: const Text('Gemini', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAA00FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _searchInGemini,
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

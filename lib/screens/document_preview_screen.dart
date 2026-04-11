import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

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
          // You can add a Copy to Clipboard button here
        ],
      ),
    );
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
      final file = File("${output.path}/documento_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Salvo em: ${file.path}')),
        );
        Navigator.pop(context); // Goes back to Home
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.imagePaths.length} Páginas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            onPressed: _isProcessing ? null : _saveAsPdf,
            tooltip: 'Salvar PDF',
          ),
        ],
      ),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: widget.imagePaths.length,
            itemBuilder: (context, index) {
              final path = widget.imagePaths[index];
              return Card(
                margin: const EdgeInsets.all(16),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Image.file(File(path)),
                    Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.text_fields, color: Colors.orange),
                            label: const Text('Extrair (OCR)'),
                            onPressed: () => _extractText(path),
                          ),
                          // Other image tools could be added here
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

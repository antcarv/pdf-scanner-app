import 'package:flutter/material.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'document_preview_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meus PDFs',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner_outlined, size: 80, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            Text(
              'Nenhum documento ainda',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque em + para escanear ou importar',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showActionOptions(context);
        },
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Novo Documento'),
      ),
    );
  }

  void _showActionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF6C63FF),
                    child: Icon(Icons.document_scanner, color: Colors.white),
                  ),
                  title: const Text('Escanear com Câmera'),
                  subtitle: const Text('Detecção automática de bordas'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      List<String>? pictures = await CunningDocumentScanner.getPictures();
                      if (pictures != null && pictures.isNotEmpty && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DocumentPreviewScreen(imagePaths: pictures),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: \$e')));
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF00E676),
                    child: Icon(Icons.image, color: Colors.white),
                  ),
                  title: const Text('Importar Imagens'),
                  subtitle: const Text('Criar PDF da Galeria'),
                  onTap: () async {
                    Navigator.pop(context);
                    final ImagePicker picker = ImagePicker();
                    final List<XFile>? images = await picker.pickMultiImage();
                    if (images != null && images.isNotEmpty && context.mounted) {
                      List<String> paths = images.map((img) => img.path).toList();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DocumentPreviewScreen(imagePaths: paths),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orangeAccent,
                    child: Icon(Icons.text_snippet, color: Colors.white),
                  ),
                  title: const Text('Extrair Texto (OCR)'),
                  subtitle: const Text('Ler texto de uma foto'),
                  onTap: () async {
                    Navigator.pop(context);
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DocumentPreviewScreen(imagePaths: [image.path]),
                        ),
                      );
                    }
                  },
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

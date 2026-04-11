import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'document_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> docsString = prefs.getStringList('scanned_docs') ?? [];
    
    setState(() {
      _documents = docsString.map((d) => jsonDecode(d) as Map<String, dynamic>).toList();
      _isLoading = false;
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateRel(String isoDate) {
    final date = DateTime.parse(isoDate);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Agorinha';
    if (diff.inHours < 1) return '${diff.inMinutes} min atrás';
    if (diff.inDays < 1) return 'Hoje ${DateFormat('HH:mm').format(date)}';
    if (diff.inDays == 1) return 'Ontem, ${DateFormat('HH:mm').format(date)}';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F16), // Dark background base
      body: Stack(
        children: [
          // Background neon/grid effects
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF).withOpacity(0.15),
                boxShadow: const [BoxShadow(color: Color(0xFF00E5FF), blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFAA00FF).withOpacity(0.1),
                boxShadow: const [BoxShadow(color: Color(0xFFAA00FF), blurRadius: 150, spreadRadius: 60)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildTabs(),
                Expanded(child: _buildDocumentList()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildScannerFab(),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFFAA00FF)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ],
            ),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF1E212D),
              child: Icon(Icons.person, color: Colors.white70, size: 24),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.document_scanner, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              const Text(
                'ScannerPro',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              )
            ],
          ),
          Row(
            children: [
              const Icon(Icons.search, color: Colors.white54, size: 28),
              const SizedBox(width: 12),
              const Icon(Icons.more_horiz, color: Colors.white54, size: 28),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text(
                  'RECENT',
                  style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 6, spreadRadius: 1)
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'FOLDERS',
                  style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                Container(height: 3, color: Colors.transparent)
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }
    
    if (_documents.isEmpty) {
      return const Center(
        child: Text('Nenhum documento ainda', style: TextStyle(color: Colors.white54)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      color: const Color(0xFF00E5FF),
      backgroundColor: const Color(0xFF1E212D),
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          final doc = _documents[index];
          return GestureDetector(
            onTap: () {
              if (File(doc['path']).existsSync()) {
                OpenFilex.open(doc['path']);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arquivo não encontrado no celular.')));
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, spreadRadius: 1)
                ],
              ),
              child: Row(
                children: [
                  // Icon badge
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E212D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        doc['type'] == 'PDF' ? Icons.picture_as_pdf : Icons.image,
                        color: doc['type'] == 'PDF' ? Colors.redAccent : Colors.blueAccent,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc['title'],
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Scanned: ${_formatDateRel(doc['date'])}, ${_formatSize(doc['size'])}',
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: doc['type'] == 'PDF' ? Colors.blue.withOpacity(0.8) : Colors.purple.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(doc['type'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.more_horiz, color: Colors.white54),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF12141D),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: const SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavIcon(icon: Icons.home, label: 'Home', isActive: true),
            _NavIcon(icon: Icons.search, label: 'Search'),
            SizedBox(width: 40), // Spacer for FAB
            _NavIcon(icon: Icons.folder, label: 'Folders'),
            _NavIcon(icon: Icons.settings, label: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerFab() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: GestureDetector(
        onTap: () => _showActionOptions(context),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFFAA00FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
               BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.6), blurRadius: 20, spreadRadius: 4, offset: const Offset(-2, -2)),
               BoxShadow(color: const Color(0xFFAA00FF).withOpacity(0.6), blurRadius: 20, spreadRadius: 4, offset: const Offset(2, 2)),
            ],
          ),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 36),
        ),
      ),
    );
  }

  void _showActionOptions(BuildContext context) {
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
                _buildActionTile(
                  icon: Icons.document_scanner, color: const Color(0xFF00E5FF), 
                  title: 'Escanear com Câmera', subtitle: 'Detecção inteligente de bordas',
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      List<String>? pictures = await CunningDocumentScanner.getPictures();
                      if (pictures != null && pictures.isNotEmpty && context.mounted) {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(imagePaths: pictures)));
                        _loadDocuments(); // Reload after back
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: \$e')));
                    }
                  }
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.image, color: const Color(0xFFAA00FF), 
                  title: 'Importar Imagens', subtitle: 'Criar PDF a partir da galeria',
                  onTap: () async {
                    Navigator.pop(context);
                    final ImagePicker picker = ImagePicker();
                    final List<XFile>? images = await picker.pickMultiImage();
                    if (images != null && images.isNotEmpty && context.mounted) {
                      List<String> paths = images.map((img) => img.path).toList();
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(imagePaths: paths)));
                      _loadDocuments();
                    }
                  }
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.text_snippet, color: Colors.orangeAccent, 
                  title: 'Extrair Texto (OCR)', subtitle: 'Ler texto de uma foto existente',
                  onTap: () async {
                    Navigator.pop(context);
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null && context.mounted) {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(imagePaths: [image.path])));
                      _loadDocuments();
                    }
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
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _NavIcon({required this.icon, required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? const Color(0xFF00E5FF) : Colors.white30, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF00E5FF) : Colors.white30,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        )
      ],
    );
  }
}

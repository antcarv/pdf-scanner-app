import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/translations.dart';
import 'document_preview_screen.dart';
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _documents = [];
  List<String> _folders = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  int _tabIndex = 0; // 0 = Recent, 1 = Folders, 2 = Files
  String _selectedFolderGrid = ''; // When inside a folder
  
  List<File> _externalFiles = [];
  bool _hasStoragePermission = false;
  bool _isLoadingExternalFiles = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    String lang = prefs.getString('language') ?? 'pt';
    AppTranslations.currentLanguage = lang;
    
    _folders = prefs.getStringList('folders') ?? [];
    final List<String> docsString = prefs.getStringList('scanned_docs') ?? [];
    
    setState(() {
      _documents = docsString.map((d) => jsonDecode(d) as Map<String, dynamic>).toList();
      _isLoading = false;
    });
  }

  Future<void> _saveDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> docsString = _documents.map((d) => jsonEncode(d)).toList();
    await prefs.setStringList('scanned_docs', docsString);
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('folders', _folders);
  }

  void _toggleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      AppTranslations.currentLanguage = AppTranslations.currentLanguage == 'pt' ? 'en' : 'pt';
    });
    prefs.setString('language', AppTranslations.currentLanguage);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateRel(String isoDate) {
    final date = DateTime.parse(isoDate);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hoje ${DateFormat('HH:mm').format(date)}';
    if (diff.inDays == 1) return 'Ontem ${DateFormat('HH:mm').format(date)}';
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
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildScannerFab(),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!_isSearching)
            const Expanded(
              child: Text(
                'PDFscan',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              )
            )
          else
            Expanded(
              child: TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: AppTranslations.get('search_hint'),
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              ),
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white54, size: 28),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
          ),
          TextButton(
            onPressed: _toggleLanguage,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              AppTranslations.currentLanguage.toUpperCase(),
              style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white54, size: 28),
            onPressed: _showAuthorMenu,
          ),
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
            child: GestureDetector(
              onTap: () => setState(() { _tabIndex = 0; _selectedFolderGrid = ''; }),
              child: Column(
                children: [
                  Text(
                    AppTranslations.get('recent'),
                    style: TextStyle(
                      color: _tabIndex == 0 ? const Color(0xFF00E5FF) : Colors.white30, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 1.5
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: _tabIndex == 0 ? const Color(0xFF00E5FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: _tabIndex == 0 ? [
                        BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 6, spreadRadius: 1)
                      ] : null,
                    ),
                  )
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() { _tabIndex = 1; _selectedFolderGrid = ''; }),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppTranslations.get('folders'),
                        style: TextStyle(
                          color: _tabIndex == 1 ? const Color(0xFF00E5FF) : Colors.white30, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 1.5
                        ),
                      ),
                      if (_tabIndex == 1 && _selectedFolderGrid.isEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addFolderDialog,
                          child: const Icon(Icons.add_circle, color: Color(0xFF00E5FF), size: 20),
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: _tabIndex == 1 ? const Color(0xFF00E5FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: _tabIndex == 1 ? [
                        BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 6, spreadRadius: 1)
                      ] : null,
                    ),
                  )
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() { _tabIndex = 2; _selectedFolderGrid = ''; });
                _checkPermissionsAndLoadFiles();
              },
              child: Column(
                children: [
                  Text(
                    AppTranslations.get('files'),
                    style: TextStyle(
                      color: _tabIndex == 2 ? const Color(0xFF00E5FF) : Colors.white30, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 1.5
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: _tabIndex == 2 ? const Color(0xFF00E5FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: _tabIndex == 2 ? [
                        BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 6, spreadRadius: 1)
                      ] : null,
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_tabIndex == 0) {
      return _buildDocumentList();
    } else if (_tabIndex == 1) {
      if (_selectedFolderGrid.isNotEmpty) {
        return _buildFolderContents();
      } else {
        return _buildFoldersGrid();
      }
    } else {
      return _buildExternalFilesList();
    }
  }

  Future<void> _checkPermissionsAndLoadFiles() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted || 
          await Permission.storage.isGranted) {
        setState(() => _hasStoragePermission = true);
        _loadExternalFiles();
      } else {
        setState(() => _hasStoragePermission = false);
      }
    } else {
      setState(() => _hasStoragePermission = true);
      _loadExternalFiles();
    }
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 11+ (API 30+)
      if (await Permission.manageExternalStorage.request().isGranted) {
        setState(() => _hasStoragePermission = true);
        _loadExternalFiles();
        return;
      }
      
      // For older Android versions
      if (await Permission.storage.request().isGranted) {
        setState(() => _hasStoragePermission = true);
        _loadExternalFiles();
        return;
      }
      
      setState(() => _hasStoragePermission = false);
    }
  }

  Future<void> _loadExternalFiles() async {
    setState(() => _isLoadingExternalFiles = true);
    List<File> files = [];
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (downloadDir.existsSync()) {
        final list = downloadDir.listSync(recursive: false).whereType<File>().where((f) {
           final ext = f.path.toLowerCase();
           return ext.endsWith('.pdf') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.docx');
        });
        files.addAll(list);
      }
      final documentsDir = Directory('/storage/emulated/0/Documents');
      if (documentsDir.existsSync()) {
        final list = documentsDir.listSync(recursive: false).whereType<File>().where((f) {
           final ext = f.path.toLowerCase();
           return ext.endsWith('.pdf') || ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.docx');
        });
        files.addAll(list);
      }
    } catch (e) {
      debugPrint('Error loading external files: $e');
    }
    
    // Sort files by modified date (newest first)
    files.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (_) {
        return 0;
      }
    });

    setState(() {
      _externalFiles = files;
      _isLoadingExternalFiles = false;
    });
  }

  Widget _buildExternalFilesList() {
    if (!_hasStoragePermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(AppTranslations.get('permission_denied'), style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
              ),
              onPressed: _requestStoragePermission,
              child: Text(AppTranslations.get('grant_permission'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

    if (_isLoadingExternalFiles) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }

    if (_externalFiles.isEmpty) {
      return Center(
        child: Text(AppTranslations.get('no_docs'), style: const TextStyle(color: Colors.white54)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadExternalFiles,
      color: const Color(0xFF00E5FF),
      backgroundColor: const Color(0xFF1E212D),
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
        itemCount: _externalFiles.length,
        itemBuilder: (context, index) {
          final file = _externalFiles[index];
          final String name = file.path.split('/').last;
          final int size = file.lengthSync();
          final String ext = name.split('.').last.toUpperCase();
          final DateTime modified = file.lastModifiedSync();
          
          return GestureDetector(
            onTap: () {
              OpenFilex.open(file.path);
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
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E212D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        ext == 'PDF' ? Icons.picture_as_pdf : (ext == 'DOCX' ? Icons.text_snippet : Icons.image),
                        color: ext == 'PDF' ? Colors.redAccent : (ext == 'DOCX' ? Colors.orangeAccent : Colors.blueAccent),
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
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${_formatDateRel(modified.toIso8601String())}, ${_formatSize(size)}',
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_folders.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.drive_file_move, color: Color(0xFF00E5FF)),
                      onPressed: () => _importExternalFileToFolder(file, name, size, ext),
                      tooltip: AppTranslations.get('move_folder'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _importExternalFileToFolder(File originalFile, String name, int size, String ext) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E212D),
        title: Text(AppTranslations.get('move_folder'), style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _folders.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(_folders[index], style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  // Copy file to app directory to make it part of the app's documents
                  try {
                    final appDir = await getApplicationDocumentsDirectory();
                    final String newPath = '${appDir.path}/imported_$name';
                    await originalFile.copy(newPath);
                    
                    final docInfo = {
                      'title': name,
                      'path': newPath,
                      'date': DateTime.now().toIso8601String(),
                      'size': size,
                      'type': ext,
                      'folder': _folders[index],
                    };
                    
                    setState(() {
                      _documents.insert(0, docInfo);
                    });
                    _saveDocuments();
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('success'))));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.get('error')}: $e')));
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
        ],
      )
    );
  }

  Widget _buildFoldersGrid() {
    if (_folders.isEmpty) {
      return Center(
        child: Text(AppTranslations.get('no_docs'), style: const TextStyle(color: Colors.white54)),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.1
      ),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        final docCount = _documents.where((d) => d['folder'] == folder).length;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedFolderGrid = folder),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E212D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder, size: 48, color: Color(0xFF00E5FF)),
                const SizedBox(height: 12),
                Text(folder, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('$docCount doc(s)', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFolderContents() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => setState(() => _selectedFolderGrid = '')),
              Text(_selectedFolderGrid, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(child: _buildDocumentList(inFolder: _selectedFolderGrid)),
      ],
    );
  }

  Widget _buildDocumentList({String? inFolder}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
    }
    
    List<Map<String, dynamic>> displayDocs = _documents;

    if (inFolder != null) {
      displayDocs = displayDocs.where((d) => d['folder'] == inFolder).toList();
    }

    if (_searchQuery.isNotEmpty) {
      displayDocs = displayDocs.where((d) {
        final title = (d['title'] as String).toLowerCase();
        return title.contains(_searchQuery);
      }).toList();
    }
    
    if (displayDocs.isEmpty) {
      return Center(
        child: Text(AppTranslations.get('no_docs'), style: const TextStyle(color: Colors.white54)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadState,
      color: const Color(0xFF00E5FF),
      backgroundColor: const Color(0xFF1E212D),
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
        itemCount: displayDocs.length,
        itemBuilder: (context, index) {
          final doc = displayDocs[index];
          return GestureDetector(
            onTap: () {
              if (File(doc['path']).existsSync()) {
                OpenFilex.open(doc['path']);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('file_not_found'))));
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
                              '${_formatDateRel(doc['date'])}, ${_formatSize(doc['size'])}',
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
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: Colors.white54),
                    color: const Color(0xFF1E212D),
                    onSelected: (action) {
                      if (action == 'rename') {
                        _renameDocument(doc);
                      } else if (action == 'delete') {
                        _deleteDocument(doc);
                      } else if (action == 'move') {
                        _moveDocument(doc);
                      } else if (action == 'share') {
                        Share.shareXFiles([XFile(doc['path'])], text: doc['title']);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(value: 'rename', child: Text(AppTranslations.get('rename'), style: const TextStyle(color: Colors.white))),
                      PopupMenuItem<String>(value: 'share', child: Text(AppTranslations.get('share'), style: const TextStyle(color: Colors.blueAccent))),
                      PopupMenuItem<String>(value: 'delete', child: Text(AppTranslations.get('delete'), style: const TextStyle(color: Colors.redAccent))),
                      if (_folders.isNotEmpty)
                        PopupMenuItem<String>(value: 'move', child: Text(AppTranslations.get('move_folder'), style: const TextStyle(color: Colors.white))),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _addFolderDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E212D),
        title: Text(AppTranslations.get('create_folder'), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: AppTranslations.get('folder_name'),
            hintStyle: const TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty && !_folders.contains(ctrl.text)) {
                setState(() => _folders.add(ctrl.text));
                _saveFolders();
              }
              Navigator.pop(context);
            }, 
            child: Text(AppTranslations.get('save'), style: const TextStyle(color: Color(0xFF00E5FF)))
          ),
        ],
      )
    );
  }

  void _renameDocument(Map<String, dynamic> doc) {
    final ctrl = TextEditingController(text: doc['title']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E212D),
        title: Text(AppTranslations.get('rename'), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: AppTranslations.get('new_name'), hintStyle: const TextStyle(color: Colors.white54)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                setState(() => doc['title'] = ctrl.text);
                _saveDocuments();
              }
              Navigator.pop(context);
            }, 
            child: Text(AppTranslations.get('save'), style: const TextStyle(color: Color(0xFF00E5FF)))
          ),
        ],
      )
    );
  }

  void _deleteDocument(Map<String, dynamic> doc) async {
    final file = File(doc['path']);
    if (await file.exists()) {
      await file.delete();
    }
    setState(() => _documents.remove(doc));
    _saveDocuments();
  }

  void _moveDocument(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E212D),
        title: Text(AppTranslations.get('move_folder'), style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _folders.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(_folders[index], style: const TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() => doc['folder'] = _folders[index]);
                  _saveDocuments();
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
        ],
      )
    );
  }

  void _showAuthorMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E212D),
        title: Text(AppTranslations.get('about_author'), style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nome: Antonio carvalho', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Se gostou, colabore com o desenvolvedor com 1 centavo.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Pix: carvant@gmail.com', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'carvant@gmail.com'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-mail copiado!')));
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFF00E5FF)))),
        ],
      )
    );
  }

  Widget _buildScannerFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => _showActionOptions(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
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
            const SizedBox(height: 8),
            const Text(
              'Scanear',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.2,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1))],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActionOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E212D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bsContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionTile(
                  icon: Icons.document_scanner, color: const Color(0xFF00E5FF), 
                  title: AppTranslations.get('scan_camera'), subtitle: AppTranslations.get('scan_smart'),
                  onTap: () async {
                    Navigator.pop(bsContext);
                    try {
                      List<String>? pictures = await CunningDocumentScanner.getPictures();
                      if (pictures != null && pictures.isNotEmpty && mounted) {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(imagePaths: pictures)));
                        _loadState(); // Reload after back
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.get('error')}: $e')));
                    }
                  }
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.image, color: const Color(0xFFAA00FF), 
                  title: AppTranslations.get('import_images'), subtitle: AppTranslations.get('import_gallery'),
                  onTap: () async {
                    Navigator.pop(bsContext);
                    final ImagePicker picker = ImagePicker();
                    final List<XFile>? images = await picker.pickMultiImage();
                    if (images != null && images.isNotEmpty && mounted) {
                      List<String> paths = images.map((img) => img.path).toList();
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(imagePaths: paths)));
                      _loadState();
                    }
                  }
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.text_snippet, color: Colors.orangeAccent, 
                  title: AppTranslations.get('extract_text'), subtitle: AppTranslations.get('extract_photo'),
                  onTap: () async {
                    Navigator.pop(bsContext);
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null && mounted) {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentPreviewScreen(imagePaths: [image.path])));
                      _loadState();
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/pdf_document_model.dart';
import 'models/storage_helper.dart';
import 'views/files_tab.dart';
import 'views/tools_tab.dart';
import 'views/favorites_tab.dart';
import 'views/profile_tab.dart';
import 'views/widgets/banner_ad_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<PdfDocumentModel> _pdfFiles = [];
  bool _isLoading = false;

  static const String _favoriteKey = 'starred_pdf_paths';
  Set<String> _starredPaths = {};

  @override
  void initState() {
    super.initState();
    _loadFavoritesAndScan();
  }

  Future<void> _loadFavoritesAndScan() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList(_favoriteKey) ?? [];
    _starredPaths = savedList.toSet();
    await _scanDevicePdfFiles();
  }

  Future<void> _scanDevicePdfFiles() async {
    setState(() => _isLoading = true);

    try {
      final foundPdfs = await StorageHelper.getAllPdfDocuments();

      // Sync persistent favorite status
      final syncedList = foundPdfs.map((doc) {
        return PdfDocumentModel(
          path: doc.path,
          name: doc.name,
          sizeInBytes: doc.sizeInBytes,
          modifiedDate: doc.modifiedDate,
          isFavorite: _starredPaths.contains(doc.path),
        );
      }).toList();

      setState(() {
        _pdfFiles = syncedList;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(PdfDocumentModel file) async {
    final newStatus = !file.isFavorite;

    setState(() {
      if (newStatus) {
        _starredPaths.add(file.path);
      } else {
        _starredPaths.remove(file.path);
      }

      final index = _pdfFiles.indexWhere((element) => element.path == file.path);
      if (index != -1) {
        final current = _pdfFiles[index];
        _pdfFiles[index] = PdfDocumentModel(
          path: current.path,
          name: current.name,
          sizeInBytes: current.sizeInBytes,
          modifiedDate: current.modifiedDate,
          isFavorite: newStatus,
        );
      }
    });

    // Save to SharedPreferences permanently
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoriteKey, _starredPaths.toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    final List<Widget> tabs = [
      FilesTab(
        files: _pdfFiles,
        isLoading: _isLoading,
        onRefresh: _scanDevicePdfFiles,
        onToggleFavorite: _toggleFavorite,
        onNavigateToTools: () {
          setState(() => _currentIndex = 1);
        },
      ),
      ToolsTab(
        onFileCreated: _scanDevicePdfFiles,
      ),
      FavoritesTab(
        allFiles: _pdfFiles,
        onToggleFavorite: _toggleFavorite,
      ),
      const ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BannerAdWidget(),
              NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                backgroundColor: Colors.white,
                indicatorColor: const Color(0xFFE5252A).withValues(alpha: 0.12),
                elevation: 0,
                height: 64,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.picture_as_pdf_outlined),
                    selectedIcon: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFE5252A),
                    ),
                    label: 'Files',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(
                      Icons.grid_view_rounded,
                      color: Color(0xFFE5252A),
                    ),
                    label: 'Tools',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.star_border_rounded),
                    selectedIcon: Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFA000),
                    ),
                    label: 'Starred',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(
                      Icons.person_rounded,
                      color: Color(0xFFE5252A),
                    ),
                    label: 'Profile',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

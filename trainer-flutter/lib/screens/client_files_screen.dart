// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class ClientFilesScreen extends StatefulWidget {
  final Client client;
  const ClientFilesScreen({super.key, required this.client});

  @override
  State<ClientFilesScreen> createState() => _ClientFilesScreenState();
}

class _ClientFilesScreenState extends State<ClientFilesScreen> {
  final _apiService = ApiService();
  bool _loading = true;
  String? _error;
  List<FileItem> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await _apiService.get(
        ApiConfig.file,
        queryParams: {'client_id': widget.client.id.toString()},
      );
      List<dynamic> list = resp is List
          ? resp
          : (resp is Map && resp['data'] is List ? resp['data'] as List : []);
      _files = list.map((e) => FileItem.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Fehler beim Laden der Dateien';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _buildDownloadUrl(String url) {
    if (url.startsWith('/api/')) {
      final base = ApiConfig.baseUrl.replaceAll('/api/', '');
      final token = _apiService.authToken;
      return '$base$url${url.contains('?') ? '&' : '?'}token=$token';
    }
    return url;
  }

  void _openFile(FileItem file) {
    final url = file.file;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kein Datei-Link verfügbar'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    final downloadUrl = _buildDownloadUrl(url);
    // Open file in-app using a full-screen dialog with embedded viewer
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _InAppFileViewer(
        title: file.displayName,
        url: downloadUrl,
      ),
    ));
  }

  Future<void> _sendFile(FileItem file) async {
    final emailCtrl = TextEditingController(text: widget.client.email ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Datei senden',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('„${file.displayName}" per E-Mail senden:',
              style: const TextStyle(color: AppColors.text, fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'E-Mail-Adresse',
              labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.muted, size: 18),
              filled: true, fillColor: AppColors.surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.muted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Senden', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
    if (confirmed != true) {
      emailCtrl.dispose();
      return;
    }
    final email = emailCtrl.text.trim();
    emailCtrl.dispose();
    if (email.isEmpty) return;
    try {
      await _apiService.postForm(ApiConfig.sendFile, body: {
        'file_id': file.id.toString(),
        'email': email,
        'client_id': widget.client.id.toString(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datei erfolgreich gesendet'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dateien'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null ? _buildError()
          : _files.isEmpty  ? _buildEmpty()
          : _buildList(),
    );
  }

  Widget _buildError() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: AppColors.red, size: 48),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 16),
      TextButton(onPressed: _loadFiles, child: const Text('Nochmal versuchen')),
    ]),
  );

  Widget _buildEmpty() => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.folder_open, color: AppColors.muted, size: 56),
      SizedBox(height: 16),
      Text('Keine Dateien vorhanden',
          style: TextStyle(color: AppColors.muted, fontSize: 15)),
    ]),
  );

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadFiles,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: _files.length,
        itemBuilder: (_, i) {
          final file = _files[i];
          final ext = file.extension;
          final hasUrl = file.file != null && file.file!.isNotEmpty;

          return Card(
            color: AppColors.surface,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border, width: 0.5),
            ),
            child: InkWell(
              onTap: hasUrl ? () => _openFile(file) : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  // File type icon
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _extColor(ext).withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: ext != null
                          ? Text(ext,
                              style: TextStyle(
                                  color: _extColor(ext),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800))
                          : Icon(Icons.insert_drive_file_outlined,
                              color: _extColor(ext), size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + date
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(file.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(file.displayDate,
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  )),
                  // Actions
                  if (hasUrl)
                    Tooltip(
                      message: 'Öffnen',
                      child: IconButton(
                        icon: const Icon(Icons.open_in_new,
                            color: AppColors.primary, size: 20),
                        onPressed: () => _openFile(file),
                      ),
                    ),
                  Tooltip(
                    message: 'Per E-Mail senden',
                    child: IconButton(
                      icon: const Icon(Icons.email_outlined,
                          color: AppColors.muted, size: 20),
                      onPressed: () => _sendFile(file),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _extColor(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':  return const Color(0xFFEF5350);
      case 'jpg':
      case 'jpeg':
      case 'png':  return const Color(0xFF42A5F5);
      case 'doc':
      case 'docx': return const Color(0xFF2196F3);
      case 'xls':
      case 'xlsx': return const Color(0xFF4CAF50);
      default:     return AppColors.muted;
    }
  }
}

/// Full-screen in-app file viewer using an iframe (for web/PDF files).
/// Files are loaded through the authenticated proxy — no external URLs exposed.
class _InAppFileViewer extends StatefulWidget {
  final String title;
  final String url;

  const _InAppFileViewer({required this.title, required this.url});

  @override
  State<_InAppFileViewer> createState() => _InAppFileViewerState();
}

class _InAppFileViewerState extends State<_InAppFileViewer> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'file-viewer-${widget.url.hashCode}';

    // Register an iframe element for HtmlElementView
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen'
        ..setAttribute('sandbox', 'allow-same-origin allow-scripts allow-popups');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: HtmlElementView(viewType: _viewId),
    );
  }
}

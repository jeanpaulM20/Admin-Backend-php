import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class QrCodeScreen extends StatefulWidget {
  final int trainerId;

  const QrCodeScreen({super.key, required this.trainerId});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  final _apiService = ApiService();
  bool _loading = true;
  String? _error;
  String? _qrImageData; // base64 data URI or URL

  @override
  void initState() {
    super.initState();
    _loadQrCode();
  }

  Future<void> _loadQrCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _apiService.get(
        ApiConfig.trainerQR,
        queryParams: {'id': widget.trainerId.toString()},
      );
      if (resp is Map && resp['code'] != null) {
        _qrImageData = resp['code'].toString();
      } else if (resp is Map && resp['message'] != null) {
        _error = resp['message'].toString();
      } else {
        _error = 'QR-Code nicht verfügbar';
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'QR-Code konnte nicht geladen werden';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trainer QR-Code'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadQrCode),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: AppColors.primary)
            : _error != null
                ? _buildError()
                : _buildQr(),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.qr_code_scanner, color: AppColors.muted, size: 64),
        const SizedBox(height: 16),
        Text(_error!,
            style: const TextStyle(color: AppColors.muted, fontSize: 15),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        TextButton(onPressed: _loadQrCode, child: const Text('Erneut versuchen')),
      ],
    );
  }

  Widget _buildQr() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Image.network(
            _qrImageData!,
            width: 220,
            height: 220,
            errorBuilder: (_, __, ___) => SizedBox(
              width: 220,
              height: 220,
              child: _buildFallbackQr(),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Teile diesen Code mit deinen Kunden',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kunden können ihn scannen, um sich zu verbinden',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFallbackQr() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.qr_code_2, color: Colors.black54, size: 100),
        SizedBox(height: 8),
        Text('QR-Bild nicht verfügbar',
            style: TextStyle(color: Colors.black54, fontSize: 12),
            textAlign: TextAlign.center),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/profile.dart';
import '../../models/registration.dart';
import '../../providers/data_refresh_provider.dart';
import '../../services/registration_service.dart';
import '../../theme/app_colors.dart';

class CheckinScannerScreen extends StatefulWidget {
  final String eventId;
  const CheckinScannerScreen({super.key, required this.eventId});

  @override
  State<CheckinScannerScreen> createState() => _CheckinScannerScreenState();
}

class _CheckinScannerScreenState extends State<CheckinScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await _scannerController.stop();
    await _lookupAndConfirm(code);
  }

  Future<void> _lookupAndConfirm(String code) async {
    try {
      final result = await RegistrationService.instance.findByTicketCode(
        eventId: widget.eventId,
        ticketCode: code,
      );

      if (!mounted) return;

      if (result == null) {
        await _showResultDialog(
          success: false,
          message: 'Ticket not found for this event.',
        );
      } else {
        final (registration, profile) = result;
        await _confirmCheckIn(registration, profile);
      }
    } catch (e) {
      if (!mounted) return;
      await _showResultDialog(
        success: false,
        message: 'Something went wrong looking up that ticket.',
      );
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      await _scannerController.start();
    }
  }

  Future<void> _confirmCheckIn(Registration registration, Profile profile) async {
    if (registration.isCancelled) {
      await _showResultDialog(
        success: false,
        message: '${profile.fullName}\'s ticket was cancelled.',
      );
      return;
    }
    if (registration.isCheckedIn) {
      await _showResultDialog(
        success: false,
        message: '${profile.fullName} is already checked in.',
      );
      return;
    }

    await RegistrationService.instance.markCheckedIn(registration.id);
    if (mounted) context.read<DataRefreshProvider>().bump();
    await _showResultDialog(
      success: true,
      message: '${profile.fullName} checked in successfully.',
    );
  }

  Future<void> _showResultDialog({
    required bool success,
    required String message,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: Icon(
          success ? Icons.check_circle : Icons.error_outline,
          color: success ? AppColors.accent : AppColors.statusDanger,
          size: 40,
        ),
        title: Text(success ? 'Checked in' : 'Not checked in',
            textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openManualSearch() async {
    await _scannerController.stop();
    final code = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => const _ManualCodeSheet(),
    );
    if (code != null && code.trim().isNotEmpty) {
      await _lookupAndConfirm(code.trim());
    } else if (mounted) {
      await _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Scan Ticket'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _scannerController.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              final value = barcodes.isNotEmpty ? barcodes.first.rawValue : null;
              if (value != null) _handleCode(value);
            },
          ),
          // Dim overlay + scan-target frame, matching the Stitch design.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Align QR code within the frame',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: SafeArea(
              top: false,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Search manually'),
                onPressed: _isProcessing ? null : _openManualSearch,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.black54,
                  side: const BorderSide(color: Colors.white38),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualCodeSheet extends StatefulWidget {
  const _ManualCodeSheet();

  @override
  State<_ManualCodeSheet> createState() => _ManualCodeSheetState();
}

class _ManualCodeSheetState extends State<_ManualCodeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter ticket code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'Use this if the QR code won\'t scan — the code is printed on the attendee\'s ticket screen.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'e.g. 4F2A9C'),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Check in'),
          ),
        ],
      ),
    );
  }
}
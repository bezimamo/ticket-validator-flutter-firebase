// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'ticket_service.dart';

class ValidateScreen extends StatefulWidget {
  const ValidateScreen({super.key});

  @override
  State<ValidateScreen> createState() => _ValidateScreenState();
}

class _ValidateScreenState extends State<ValidateScreen> {
  // UI state variables
  String resultMessage = "Scan a ticket to validate";
  String status = "";
  bool isScanning = true;
  bool isLoading = false;

  final MobileScannerController cameraController = MobileScannerController();

  // Custom colors
  final Color primaryColor = const Color(0xFFDEA449);
  final Color cardBackground = Colors.white;

  /// Handle ticket validation from scanned value
  void validateTicket(String scannedValue) async {
    setState(() {
      resultMessage = "🔄 Validating...";
      status = "";
      isScanning = false;
      isLoading = true;
      cameraController.stop();
    });

    String ticketId = "";
    String eventId = "event001"; // Default eventId

    if (scannedValue.contains(':')) {
      var parts = scannedValue.split(':');
      ticketId = parts[0].trim();
      eventId = parts[1].trim();
    } else {
      ticketId = scannedValue.trim();
    }

    final result = await TicketService.validateTicket(ticketId, eventId);

    setState(() {
      resultMessage = result;
      isLoading = false;

      if (result.contains("✅")) {
        status = "valid";
      } else if (result.contains("⚠️")) {
        status = "used";
      } else if (result.contains("Wrong event")) {
        status = "wrong_event";
      } else {
        status = "invalid_format";
      }
    });
  }

  /// Reset the scanner for a new scan
  void resetScanner() {
    setState(() {
      resultMessage = "Scan a ticket to validate";
      status = "";
      isScanning = true;
      isLoading = false;
    });
    cameraController.start();
  }

  /// Color based on validation status
  Color getAlertColor(String status) {
    switch (status) {
      case "valid":
        return Colors.green.shade100;
      case "used":
        return Colors.yellow.shade100;
      case "wrong_event":
      case "invalid_format":
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  /// Border color based on validation status
  Color getBorderColor(String status) {
    switch (status) {
      case "valid":
        return Colors.green.shade700;
      case "used":
        return Colors.orange.shade700;
      case "wrong_event":
      case "invalid_format":
        return Colors.red.shade700;
      default:
        return Colors.grey.shade400;
    }
  }

  /// Icon based on validation status
  IconData getStatusIcon(String status) {
    switch (status) {
      case "valid":
        return Icons.check_circle_rounded;
      case "used":
        return Icons.warning_rounded;
      case "wrong_event":
      case "invalid_format":
        return Icons.error_rounded;
      default:
        return Icons.info_outline;
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  /// Build UI
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE6B4), Color(0xFFFFF3E2)],
          ),
        ),
        child: Center(
          child: Card(
            color: cardBackground,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
            child: SizedBox(
              width: screenWidth < 420 ? double.infinity : 380,
              height: 560,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: const Center(
                      child: Text(
                        "🎟️ Ticket Validator",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),

                  // QR Scanner
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: isScanning
                          ? MobileScanner(
                              controller: cameraController,
                              onDetect: (capture) {
                                final List<Barcode> barcodes = capture.barcodes;
                                if (barcodes.isNotEmpty) {
                                  final scannedTicketId = barcodes.first.rawValue?.trim() ?? "";
                                  if (scannedTicketId.isNotEmpty) {
                                    validateTicket(scannedTicketId);
                                  }
                                }
                              },
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(Icons.qr_code_scanner, size: 100, color: Colors.grey),
                              ),
                            ),
                    ),
                  ),

                  // Result Display
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: getAlertColor(status),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: getBorderColor(status),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  getStatusIcon(status),
                                  size: 32,
                                  color: getBorderColor(status),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: isLoading
                                      ? const Center(child: CircularProgressIndicator())
                                      : Text(
                                          resultMessage,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Scan Again Button
                          if (!isScanning)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: resetScanner,
                                icon: const Icon(Icons.restart_alt),
                                label: const Text("Scan Again"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

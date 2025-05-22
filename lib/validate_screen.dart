import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'ticket_service.dart';

class ValidateScreen extends StatefulWidget {
  const ValidateScreen({super.key});

  @override
  State<ValidateScreen> createState() => _ValidateScreenState();
}

class _ValidateScreenState extends State<ValidateScreen> {
  String resultMessage = "Scan a ticket to validate";
  String status = "";
  bool isScanning = true;
  final MobileScannerController cameraController = MobileScannerController();

  void validateTicket(String scannedValue) async {
    setState(() {
      resultMessage = "🔄 Validating...";
      status = "";
      isScanning = false;
      cameraController.stop();
    });

    String ticketId = "";
    String eventId = "event001";

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

  void resetScanner() {
    setState(() {
      resultMessage = "Scan a ticket to validate";
      status = "";
      isScanning = true;
    });
    cameraController.start();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Color getAlertColor(String status) {
    switch (status) {
      case "valid":
        return Colors.green.shade50;
      case "used":
        return Colors.yellow.shade50;
      case "wrong_event":
      case "invalid_format":
        return Colors.red.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  Color getBorderColor(String status) {
    switch (status) {
      case "valid":
        return Colors.green.shade600;
      case "used":
        return Colors.yellow.shade700;
      case "wrong_event":
      case "invalid_format":
        return Colors.red.shade700;
      default:
        return Colors.grey.shade400;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case "valid":
        return Icons.check_circle;
      case "used":
        return Icons.warning;
      case "wrong_event":
      case "invalid_format":
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("🎟️ Ticket Validator"),
        backgroundColor: Colors.blue.shade300,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 380,
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: isScanning
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: MobileScanner(
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
                          ),
                        )
                      : const Center(child: Icon(Icons.qr_code_scanner, size: 100)),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (resultMessage.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: getAlertColor(status),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: getBorderColor(status),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(getStatusIcon(status), size: 30),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    resultMessage,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        if (!isScanning)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: resetScanner,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text("🔁 Scan Again"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade400,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
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
    );
  }
}

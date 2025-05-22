import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'ticket_service.dart';  // Make sure this has your validateTicket function

class ValidateScreen extends StatefulWidget {
  const ValidateScreen({super.key});

  @override
  State<ValidateScreen> createState() => _ValidateScreenState();
}

class _ValidateScreenState extends State<ValidateScreen> {
  String resultMessage = "Scan a ticket to validate";
  bool isScanning = true;
  final MobileScannerController cameraController = MobileScannerController();

  void validateTicket(String scannedValue) async {
    setState(() {
      resultMessage = "🔄 Validating...";
      isScanning = false;
      cameraController.stop();
    });

    // Parse scannedValue into ticketId and eventId if format is 'ticketId:eventId'
    String ticketId = "";
    String eventId = "event001"; // default eventId or parse if provided

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
    });
  }

  void resetScanner() {
    setState(() {
      resultMessage = "Scan a ticket to validate";
      isScanning = true;
    });
    cameraController.start();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("QR Ticket Validator")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: isScanning
                ? MobileScanner(
                    controller: cameraController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final scannedValue = barcodes.first.rawValue?.trim() ?? "";
                        if (scannedValue.isNotEmpty) {
                          validateTicket(scannedValue);
                        }
                      }
                    },
                  )
                : const Center(child: Icon(Icons.qr_code_scanner, size: 100)),
          ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  resultMessage,
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (!isScanning)
                  ElevatedButton.icon(
                    onPressed: resetScanner,
                    icon: const Icon(Icons.qr_code),
                    label: const Text("Scan Again"),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

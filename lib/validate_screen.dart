// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ValidateScreen extends StatefulWidget {
  const ValidateScreen({super.key});

  @override
  State<ValidateScreen> createState() => _ValidateScreenState();
}

class _ValidateScreenState extends State<ValidateScreen> {
  String resultMessage = "Scan a ticket to validate";
  String status = "";
  bool isScanning = true;
  bool isLoading = false;

  final MobileScannerController cameraController = MobileScannerController();
  final Color primaryColor = const Color(0xFFDEA449);
  final Color cardBackground = Colors.white;

  /// Validates a ticket and updates Firestore
  void validateTicket(String scannedValue) async {
    setState(() {
      resultMessage = "🔄 Validating...";
      status = "";
      isScanning = false;
      isLoading = true;
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

    final querySnapshot = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('tickets')
        .where('ticketId', isEqualTo: ticketId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      setState(() {
        resultMessage = "❌ Invalid or mismatched ticket";
        status = "invalid_format";
        isLoading = false;
      });
      return;
    }

    final ticket = querySnapshot.docs.first;

    if (ticket['used'] == true) {
      Timestamp validatedAt = ticket['validatedAt'];
      String formattedDate = validatedAt.toDate().toString();

      setState(() {
        resultMessage = "⚠️ Ticket Already Used\n✔️ Validated on: $formattedDate";
        status = "used";
        isLoading = false;
      });
      return;
    }

    await ticket.reference.update({
      'used': true,
      'validatedAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      resultMessage = "✅ Ticket is Valid!";
      status = "valid";
      isLoading = false;
    });
  }

  void resetScanner() {
    setState(() {
      resultMessage = "Scan a ticket to validate";
      status = "";
      isScanning = true;
      isLoading = false;
    });
    cameraController.start();
  }

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "🎟️ Ticket Validator",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Center(
        child: Card(
          color: cardBackground,
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.all(16),
          child: SizedBox(
            width: screenWidth < 420 ? double.infinity : 380,
            height: 520, // Reduced height to fix overflow issue
            child: Column(
              children: [
                Expanded(
                  flex: 2, // Reduced height for QR scanner
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: isScanning
                        ? SizedBox(
                            height: 180, // Fixed height for scanner to prevent overflow
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
                        : Container(
                            height: 180, // Keep height fixed when scanning stops
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: getAlertColor(status),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: getBorderColor(status),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(getStatusIcon(status), size: 36, color: getBorderColor(status)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : Text(
                                        resultMessage,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

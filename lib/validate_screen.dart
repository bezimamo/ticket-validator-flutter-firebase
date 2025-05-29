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

    try {
      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(eventId).get();
      if (!eventDoc.exists) {
        setState(() {
          resultMessage = "❌ Event not found";
          status = "invalid_format";
          isLoading = false;
        });
        return;
      }

      final eventName = eventDoc.data()?['eventName'] ?? eventId;
      final eventDate = (eventDoc.data()?['eventDate'] as Timestamp?)?.toDate();

      final now = DateTime.now();
      if (eventDate == null || now.isBefore(eventDate.subtract(const Duration(minutes: 15)))) {
        setState(() {
          resultMessage = "⏰ Too early to scan ticket for: $eventName";
          status = "invalid_format";
          isLoading = false;
        });
        return;
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

      final validationsRef = ticket.reference.collection('validations');
      final validationsSnapshot = await validationsRef
          .where('eventDate', isEqualTo: Timestamp.fromDate(eventDate))
          .limit(1)
          .get();

      if (validationsSnapshot.docs.isNotEmpty) {
        final validatedAt = validationsSnapshot.docs.first.data()['timestamp'] as Timestamp;
        final formattedDate = validatedAt.toDate().toString();

        setState(() {
          resultMessage = "⚠️ Ticket Already Used\n✔️ Event: $eventName\n📅 Validated at: $formattedDate";
          status = "used";
          isLoading = false;
        });
        return;
      }

      await validationsRef.add({
        'timestamp': FieldValue.serverTimestamp(),
        'eventDate': Timestamp.fromDate(eventDate),
      });

      setState(() {
        resultMessage = "✅ Ticket is Valid!\n🎉 Event: $eventName";
        status = "valid";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        resultMessage = "❗ Error: $e";
        status = "invalid_format";
        isLoading = false;
      });
    }
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              "OWL Event Ticket Validator",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          margin: const EdgeInsets.all(16),
          child: SizedBox(
            width: screenWidth < 420 ? double.infinity : 380,
            height: 520,
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: isScanning
                        ? SizedBox(
                            height: 180,
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
                            height: 180,
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
                            borderRadius: BorderRadius.circular(30),
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
                          child: Text(
                            resultMessage,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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

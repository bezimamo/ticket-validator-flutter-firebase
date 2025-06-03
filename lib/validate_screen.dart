// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
  bool isDarkMode = false;

  final MobileScannerController cameraController = MobileScannerController();
  final Color primaryColor = const Color(0xFFDEA449);

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

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
final formattedDate = DateFormat('MMM/dd/yyyy – hh:mm a').format(validatedAt.toDate());

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

  Color getAlertColor(String status, bool isDark) {
    switch (status) {
      case "valid":
        return isDark ? Colors.green.shade900 : Colors.green.shade100;
      case "used":
        return isDark ? Colors.yellow.shade800 : Colors.yellow.shade100;
      case "wrong_event":
      case "invalid_format":
        return isDark ? Colors.red.shade900 : Colors.red.shade100;
      default:
        return isDark ? Colors.grey.shade800 : Colors.grey.shade100;
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

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = isDarkMode ? ThemeData.dark() : ThemeData.light();
    final screenWidth = MediaQuery.of(context).size.width;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 28,
              ),
              const SizedBox(width: 8),
              Text(
                "OWL Event Ticket Validator",
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.15,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          actions: [
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: toggleTheme,
              tooltip: "Toggle Theme",
            ),
          ],
        ),
        body: Center(
          child: Card(
            color: theme.cardColor,
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
                              color: theme.cardColor,
                              child: Icon(Icons.qr_code_scanner, size: 80, color: theme.iconTheme.color),
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
                              color: getAlertColor(status, isDarkMode),
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
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              softWrap: true,
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
      ),
    );
  }
}

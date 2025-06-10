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
  String resultMessage = "🎫 Scan a ticket to validate";
  String status = "";
  bool isScanning = true;
  bool isLoading = false;
  bool isDarkMode = false;
  String ticketType = "";

  final MobileScannerController cameraController = MobileScannerController();
  final Color primaryColor = const Color(0xFFDEA449);
  final Color vipColor = const Color(0xFF5E4A8E);

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  void validateTicket(String scannedValue) async {
    setState(() {
      resultMessage = "🔍 Validating Ticket...";
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
          resultMessage = "❌ Event not found.";
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
          resultMessage = "⏳ Too early to validate ticket for:\n🗓️ $eventName";
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
          resultMessage = "❌ Invalid Ticket\nPlease check the code!";
          status = "invalid_format";
          isLoading = false;
        });
        return;
      }

      final ticket = querySnapshot.docs.first;
      ticketType = ticket['type'] ?? 'Normal';

      final validationsRef = ticket.reference.collection('validations');
      final validationsSnapshot = await validationsRef
          .where('eventDate', isEqualTo: Timestamp.fromDate(eventDate))
          .limit(1)
          .get();

      if (validationsSnapshot.docs.isNotEmpty) {
        final validatedAt = validationsSnapshot.docs.first.data()['timestamp'] as Timestamp;
        final formattedDate = DateFormat('yyyy-MM-dd – hh:mm a').format(validatedAt.toDate());

        setState(() {
          resultMessage =
              "⚠️ Already Used Ticket!\n\n🎉 Event: $eventName\n📅 Validated At: $formattedDate";
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
        resultMessage = "✅ Ticket Valid!\n🎊 Welcome to $eventName 🎉";
        status = "valid";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        resultMessage = "❗ Error occurred.\n$e";
        status = "invalid_format";
        isLoading = false;
      });
    }
  }

  void resetScanner() {
    setState(() {
      resultMessage = "🎫 Scan a ticket to validate";
      status = "";
      isScanning = true;
      isLoading = false;
    });
    cameraController.start();
  }

  Color getCardColor() {
    if (ticketType == "VIP") {
      return vipColor;
    } else {
      return Colors.blueGrey.shade600;
    }
  }

  Icon getTicketIcon() {
    if (ticketType == "VIP") {
      return const Icon(Icons.auto_awesome, color: Colors.amber, size: 30);
    } else {
      return const Icon(Icons.event_seat, color: Colors.white, size: 30);
    }
  }

  Widget getTicketBanner() {
    if (ticketType == "VIP") {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          "✨ VIP TICKET",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white70,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          "🪑 NORMAL TICKET",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
        ),
      );
    }
  }

  IconData getStatusIcon() {
    switch (status) {
      case "valid":
        return Icons.check_circle;
      case "used":
        return Icons.warning_amber;
      case "invalid_format":
        return Icons.error;
      default:
        return Icons.qr_code_2;
    }
  }

  Color getStatusColor() {
    switch (status) {
      case "valid":
        return Colors.greenAccent;
      case "used":
        return Colors.orangeAccent;
      case "invalid_format":
        return Colors.redAccent;
      default:
        return Colors.white;
    }
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
              Image.asset('assets/logo.png', height: 28),
              const SizedBox(width: 8),
              Text(
                "OWL Ticket Validator",
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          actions: [
            IconButton(
              icon: Icon(
                isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: Colors.white,
              ),
              onPressed: toggleTheme,
              tooltip: "Toggle Theme",
            ),
          ],
        ),
        body: Center(
          child: Card(
            color: getCardColor(),
            elevation: 20,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            margin: const EdgeInsets.all(16),
            child: SizedBox(
              width: screenWidth < 400 ? double.infinity : 360,
              height: 550,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  getTicketIcon(),
                  const SizedBox(height: 8),
                  getTicketBanner(),
                  const SizedBox(height: 10),
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: isScanning
                          ? SizedBox(
                              height: 180,
                              child: MobileScanner(
                                controller: cameraController,
                                onDetect: (capture) {
                                  final barcodes = capture.barcodes;
                                  if (barcodes.isNotEmpty) {
                                    final scannedValue = barcodes.first.rawValue?.trim() ?? "";
                                    if (scannedValue.isNotEmpty) {
                                      validateTicket(scannedValue);
                                    }
                                  }
                                },
                              ),
                            )
                          : Icon(getStatusIcon(), size: 120, color: getStatusColor()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black12.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        resultMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!isScanning)
                    ElevatedButton.icon(
                      onPressed: resetScanner,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text("Scan Again"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

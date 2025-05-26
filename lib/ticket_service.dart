import 'package:cloud_firestore/cloud_firestore.dart';

class TicketService {
  static final _db = FirebaseFirestore.instance;

  static Future<String> validateTicket(String ticketId, String eventId) async {
    try {
      final querySnapshot = await _db
          .collection('events')
          .doc(eventId)
          .collection('tickets')
          .where('ticketId', isEqualTo: ticketId.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return "❌ Invalid or mismatched ticket";
      }

      final ticket = querySnapshot.docs.first;

      if (ticket['used'] == true) {
        return "⚠️ Ticket Already Used";
      }

      await ticket.reference.update({
        'used': true,
        'validatedAt': FieldValue.serverTimestamp(), // Adds timestamp
      });

      return "✅ Ticket is Valid and now marked as used";
    } catch (e) {
      return "❗ Error validating ticket: $e";
    }
  }
}

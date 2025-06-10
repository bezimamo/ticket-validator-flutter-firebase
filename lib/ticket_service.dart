import 'package:cloud_firestore/cloud_firestore.dart';

class TicketService {
  static final _db = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> validateTicket(String ticketId, String eventId) async {
    try {
      final eventRef = _db.collection('events').doc(eventId);
      final eventDoc = await eventRef.get();

      if (!eventDoc.exists) {
        return {"status": "invalid_format", "message": "❌ Event not found"};
      }

      final eventData = eventDoc.data()!;
      final eventDate = (eventData['eventDate'] as Timestamp).toDate();
      final eventName = eventData['eventName'] ?? eventId;

      final now = DateTime.now();
      if (now.isBefore(eventDate.subtract(const Duration(minutes: 15)))) {
        return {
          "status": "invalid_format",
          "message": "⏰ Too early to scan ticket for: $eventName"
        };
      }

      final ticketQuery = await eventRef
          .collection('tickets')
          .where('ticketId', isEqualTo: ticketId)
          .limit(1)
          .get();

      if (ticketQuery.docs.isEmpty) {
        return {"status": "invalid_format", "message": "❌ Invalid or mismatched ticket"};
      }

      final ticket = ticketQuery.docs.first;
      final validationsRef = ticket.reference.collection('validations');

      final existingValidation = await validationsRef
          .where('eventDate', isEqualTo: Timestamp.fromDate(eventDate))
          .limit(1)
          .get();

      if (existingValidation.docs.isNotEmpty) {
        final validatedAt = (existingValidation.docs.first.data()['timestamp'] as Timestamp).toDate();
        return {
          "status": "used",
          "message": "⚠️ Ticket Already Used\n✔️ Event: $eventName\n📅 Validated at: $validatedAt"
        };
      }

      await validationsRef.add({
        'timestamp': FieldValue.serverTimestamp(),
        'eventDate': Timestamp.fromDate(eventDate),
      });

      return {
        "status": "valid",
        "message": "✅ Ticket is Valid!\n🎉 Event: $eventName"
      };
    } catch (e) {
      return {
        "status": "invalid_format",
        "message": "❗ Error: $e"
      };
    }
  }
}

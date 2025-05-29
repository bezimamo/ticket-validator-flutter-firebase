import 'package:cloud_firestore/cloud_firestore.dart';

class TicketService {
  static final _db = FirebaseFirestore.instance;

  static Future<String> validateTicket(String ticketId, String eventId) async {
    try {
      final eventRef = _db.collection('events').doc(eventId);

      // 🔍 Fetch event metadata
      final eventDoc = await eventRef.get();
      if (!eventDoc.exists) return "❌ Event not found";

      final eventData = eventDoc.data()!;
      final eventDate = (eventData['eventDate'] as Timestamp).toDate();
      final eventName = eventData['eventName'] ?? eventId;
      final now = DateTime.now();

      // 📆 Check if ticket is being used on the correct day
      if (now.year != eventDate.year ||
          now.month != eventDate.month ||
          now.day != eventDate.day) {
        return "❌ Ticket not valid today. \"$eventName\" is on ${eventDate.toLocal()}";
      }

      // 🎟️ Find the ticket
      final ticketQuery = await eventRef
          .collection('tickets')
          .where('ticketId', isEqualTo: ticketId)
          .limit(1)
          .get();

      if (ticketQuery.docs.isEmpty) return "❌ Ticket not found";

      final ticketDoc = ticketQuery.docs.first;
      final ticketRef = ticketDoc.reference;

      // 🔁 Check if this ticket was already used for this event date
      final validations = await ticketRef
          .collection('validations')
          .where('eventDate', isEqualTo: Timestamp.fromDate(eventDate))
          .limit(1)
          .get();

      if (validations.docs.isNotEmpty) {
        return "⚠️ Ticket already used for \"$eventName\" on ${eventDate.toLocal()}";
      }

      // ✅ Save validation
      await ticketRef.collection('validations').add({
        'eventDate': Timestamp.fromDate(eventDate),
        'validatedAt': FieldValue.serverTimestamp()
      });

      return "✅ Ticket valid for \"$eventName\" on ${eventDate.toLocal()}";
    } catch (e) {
      return "❗ Error validating ticket: $e";
    }
  }
}

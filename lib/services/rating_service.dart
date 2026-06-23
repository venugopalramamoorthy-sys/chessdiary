import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingEntry {
  final String id;
  final DateTime date;
  final int rating;
  final String type; // 'fide', 'national', 'ecf', 'other'
  final String? note;

  RatingEntry({
    required this.id,
    required this.date,
    required this.rating,
    required this.type,
    this.note,
  });

  factory RatingEntry.fromMap(Map<String, dynamic> map, String id) {
    return RatingEntry(
      id: id,
      date: DateTime.parse(map['date']),
      rating: map['rating'] as int,
      type: map['type'] as String? ?? 'fide',
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'rating': rating,
        'type': type,
        'note': note,
      };
}

class RatingService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;
  static CollectionReference get _col =>
      _db.collection('users').doc(_uid).collection('ratings');

  static Future<void> addEntry(RatingEntry entry) async {
    await _col.add(entry.toMap());
  }

  static Future<void> deleteEntry(String id) async {
    await _col.doc(id).delete();
  }

  static Stream<List<RatingEntry>> entriesStream() {
    return _col
        .orderBy('date', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RatingEntry.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  static Future<List<RatingEntry>> getAllEntries() async {
    final snap = await _col.orderBy('date').get();
    return snap.docs
        .map((d) => RatingEntry.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }
}

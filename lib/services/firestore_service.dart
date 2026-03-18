import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get donors => _db.collection('donors');
  CollectionReference get alerts => _db.collection('alerts');

  Stream<QuerySnapshot> getDonors() {
    return donors.orderBy('updatedAt', descending: true).snapshots();
  }

  Future<void> addDonor(Map<String, dynamic> data) async {
    await donors.add(data);
  }

  Future<void> updateDonor(String id, Map<String, dynamic> data) async {
    await donors.doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteDonor(String id) async {
    await donors.doc(id).delete();
  }

  Future<void> toggleAvailability(String id, bool value) async {
    await donors.doc(id).update({
      'available': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendAlert(String msg) async {
    await alerts.add({
      'message': msg,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
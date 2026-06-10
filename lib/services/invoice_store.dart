import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client.dart';
import '../models/company.dart';
import '../models/invoice.dart';
import '../models/lead.dart';
import '../models/studio_item.dart';
import '../models/studio_package.dart';

class InvoiceStore {
  InvoiceStore(this.db);

  final FirebaseFirestore db;

  Stream<List<Company>> companies() => db
      .collection('companies')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Company.fromDoc).toList());

  Stream<List<Client>> clients() => db
      .collection('clients')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Client.fromDoc).toList());

  Stream<List<Lead>> leads() => db
      .collection('leads')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Lead.fromDoc).toList());

  Stream<List<Invoice>> invoices() => db
      .collection('invoices')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Invoice.fromDoc).toList());

  Stream<List<StudioPackage>> packages() => db
      .collection('packages')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(StudioPackage.fromDoc).toList());

  Stream<List<StudioItem>> studioItems() => db
      .collection('studio_items')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(StudioItem.fromDoc).toList());

  Future<void> saveCompany(Company company) {
    final ref = company.id.isEmpty
        ? db.collection('companies').doc()
        : db.collection('companies').doc(company.id);
    return ref.set(company.toJson(), SetOptions(merge: true));
  }

  Future<void> saveClient(Client client) {
    final ref = client.id.isEmpty
        ? db.collection('clients').doc()
        : db.collection('clients').doc(client.id);
    return ref.set(client.toJson(), SetOptions(merge: true));
  }

  Future<void> saveLead(Lead lead) {
    final ref = lead.id.isEmpty
        ? db.collection('leads').doc()
        : db.collection('leads').doc(lead.id);
    return ref.set(lead.toJson(), SetOptions(merge: true));
  }

  Future<void> saveInvoice(Invoice invoice) {
    final ref = invoice.id.isEmpty
        ? db.collection('invoices').doc()
        : db.collection('invoices').doc(invoice.id);
    return ref.set(invoice.toJson(), SetOptions(merge: true));
  }

  Future<void> deleteInvoice(String id) =>
      db.collection('invoices').doc(id).delete();

  Future<void> savePackage(StudioPackage package) {
    final ref = package.id.isEmpty
        ? db.collection('packages').doc()
        : db.collection('packages').doc(package.id);
    return ref.set(package.toJson(), SetOptions(merge: true));
  }

  Future<void> saveStudioItem(StudioItem item) {
    final ref = item.id.isEmpty
        ? db.collection('studio_items').doc()
        : db.collection('studio_items').doc(item.id);
    return ref.set(item.toJson(), SetOptions(merge: true));
  }

  Future<void> deleteCompany(String id) =>
      db.collection('companies').doc(id).delete();

  Future<void> deleteClient(String id) =>
      db.collection('clients').doc(id).delete();

  Future<void> deleteLead(String id) =>
      db.collection('leads').doc(id).delete();

  Future<void> rejectLead(String id, String reason) =>
      db.collection('leads').doc(id).update({
        'isRejected': true,
        'rejectReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> convertLeadToClient(Lead lead) async {
    final batch = db.batch();
    
    // Create new client document with the same data
    final clientRef = db.collection('clients').doc(lead.id);
    batch.set(clientRef, lead.toJson()..['updatedAt'] = FieldValue.serverTimestamp()..['fromLead'] = true, SetOptions(merge: true));
    
    // Delete lead document
    final leadRef = db.collection('leads').doc(lead.id);
    batch.delete(leadRef);
    
    await batch.commit();
  }

  Future<void> deletePackage(String id) =>
      db.collection('packages').doc(id).delete();

  Future<void> deleteStudioItem(String id) =>
      db.collection('studio_items').doc(id).delete();
}

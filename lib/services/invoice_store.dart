import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company.dart';
import '../models/client.dart';
import '../models/invoice.dart';
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

  Future<void> saveInvoice(Invoice invoice) =>
      db.collection('invoices').add(invoice.toJson());

  Future<void> savePackage(StudioPackage package) {
    final ref = package.id.isEmpty
        ? db.collection('packages').doc()
        : db.collection('packages').doc(package.id);
    return ref.set(package.toJson(), SetOptions(merge: true));
  }
}

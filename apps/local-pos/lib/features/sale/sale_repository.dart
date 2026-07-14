import 'package:auice_pos/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReceiptData {
  const ReceiptData({
    required this.sale,
    required this.branchName,
    required this.items,
    required this.payments,
    required this.movements,
  });
  final Sale sale;
  final String branchName;
  final List<SaleItem> items;
  final List<Payment> payments;
  final List<StockMovement> movements;
}

class SaleRepository {
  SaleRepository(this.db);
  final AppDatabase db;
  Future<Sale?> getSaleById(String id) => (db.select(
    db.sales,
  )..where((row) => row.id.equals(id))).getSingleOrNull();
  Future<Sale?> getSaleByReceiptNumber(String number) => (db.select(
    db.sales,
  )..where((row) => row.receiptNumber.equals(number))).getSingleOrNull();
  Future<List<Sale>> listRecentSales({int limit = 50}) =>
      (db.select(db.sales)
            ..where((row) => row.status.equals('completed'))
            ..orderBy([(row) => OrderingTerm.desc(row.soldAt)])
            ..limit(limit))
          .get();
  Future<List<SaleItem>> getSaleItems(String saleId) => (db.select(
    db.saleItems,
  )..where((row) => row.saleId.equals(saleId))).get();
  Future<List<Payment>> getSalePayments(String saleId) =>
      (db.select(db.payments)..where((row) => row.saleId.equals(saleId))).get();
  Future<List<StockMovement>> getSaleStockMovements(String saleId) =>
      (db.select(db.stockMovements)..where(
            (row) =>
                row.referenceType.equals('sale') &
                row.referenceId.equals(saleId),
          ))
          .get();
  Future<ReceiptData?> getReceipt(String saleId) async {
    final sale = await getSaleById(saleId);
    if (sale == null) return null;
    return ReceiptData(
      sale: sale,
      branchName:
          (await (db.select(db.branches)
                    ..where((row) => row.id.equals(sale.branchId)))
                  .getSingleOrNull())
              ?.name ??
          sale.branchId,
      items: await getSaleItems(saleId),
      payments: await getSalePayments(saleId),
      movements: await getSaleStockMovements(saleId),
    );
  }

  Future<bool> isSyncPending(String saleId) async =>
      await (db.select(db.syncOutbox)..where(
            (row) =>
                row.entityType.equals('sale') &
                row.entityId.equals(saleId) &
                row.status.equals('pending'),
          ))
          .getSingleOrNull() !=
      null;
}

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepository(ref.watch(databaseProvider)),
);
final recentSalesProvider = FutureProvider<List<Sale>>(
  (ref) => ref.watch(saleRepositoryProvider).listRecentSales(),
);
final receiptProvider = FutureProvider.family<ReceiptData?, String>(
  (ref, id) => ref.watch(saleRepositoryProvider).getReceipt(id),
);

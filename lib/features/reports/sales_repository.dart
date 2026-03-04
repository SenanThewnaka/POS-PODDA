import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:sme_buddy/features/inventory/product_model.dart';
import 'package:sme_buddy/features/home/cart_provider.dart'; // For CartItem
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:flutter/material.dart'; // For DateTimeRange
import 'package:intl/intl.dart';

class DailySummary {
  final double totalSales;
  final double cashInHand;
  final double creditGiven;
  final String mostSoldItem;

  DailySummary({
    required this.totalSales,
    required this.cashInHand,
    required this.creditGiven,
    required this.mostSoldItem,
  });
}



final salesRepositoryProvider = Provider((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null) {
     throw Exception("SalesRepository accessed without user profile");
  }
  final repo = SalesRepository(userProfile);
  // Auto-run maintenance (fire and forget)
  repo.performMaintenance();
  return repo;
});

final salesSummaryProvider = StreamProvider.family<DailySummary, DateTimeRange>((ref, range) {
  return ref.watch(salesRepositoryProvider).getStatsStream(range.start, range.end);
});

final salesListProvider = StreamProvider.family<List<Sale>, DateTimeRange>((ref, range) {
  return ref.watch(salesRepositoryProvider).getSalesStream(range.start, range.end);
});

class SalesRepository {
  final UserModel currentUser;
  SalesRepository(this.currentUser);

  // ... (Collections remain same)
  CollectionReference get _collection => 
      FirebaseFirestore.instance.collection('shops').doc(currentUser.shopId).collection('sales');
  
  CollectionReference get _customerCollection => 
      FirebaseFirestore.instance.collection('users').doc(currentUser.shopId).collection('customers');

  CollectionReference get _statsCollection =>
      FirebaseFirestore.instance.collection('shops').doc(currentUser.shopId).collection('stats');
      
  CollectionReference get _metadataCollection =>
      FirebaseFirestore.instance.collection('shops').doc(currentUser.shopId).collection('system');

  Future<Sale> recordSale(double amount, String method, String? customerId, Map<String, CartItem> cartItems) async {
    final docRef = _collection.doc();
    final todayStr = DateFormat('yyyy_MM_dd').format(DateTime.now());
    final statsRef = _statsCollection.doc(todayStr);
    
    // ... (rest of recordSale logic is fine, no changes needed inside)
    // Actually, I need to preserve the recordSale implementation from previous step, 
    // but replaced_file_content requires me to provide the content I'm replacing + context.
    // Since I'm essentially inserting methods or modifying the class structure, 
    // I should be careful not to overwrite the long recordSale unless I provide it all.
    // 
    // Strategy: I will use `performMaintenance` as the anchor to insert the migration logic BEFORE or AFTER it,
    // Or I can add the migration method at the end of the class.
    // 
    // Let's modify `performMaintenance` to INLCUDE the migration check.
    
    // Convert Cart (Map<String, CartItem>) to List<SaleItem>
    final List<SaleItem> lineItems = cartItems.values.map((item) {
      final double originalPrice = item.product.sellingPrice;
      final double soldPrice = item.effectivePrice;
      String name = item.product.name;
      
      // If discounted, append info
      final double totalOriginal = originalPrice * item.quantity;
      final double totalSold = item.subTotal;
      final double totalDiscount = totalOriginal - totalSold;

      if (totalDiscount > 0.01) { 
        final diffStr = totalDiscount % 1 == 0 ? totalDiscount.toStringAsFixed(0) : totalDiscount.toStringAsFixed(2);
        name = "$name (Disc. Rs. $diffStr)";
      }

      return SaleItem(
        productId: item.product.id,
        productName: name, // Saved with discount badge
        unitPrice: soldPrice, 
        costPrice: item.costPrice, // Use item specific cost (supports overrides)
        quantity: item.quantity,
        subTotal: item.subTotal,
        description: item.description,
      );
    }).toList();

    print("RECORDING SALE: Total=$amount, Method=$method, Customer=$customerId");
    final sale = Sale(
      id: docRef.id,
      timestamp: DateTime.now(),
      totalAmount: amount,
      paymentMethod: method,
      customerId: customerId,
      isFullyPaid: method != 'CREDIT', // Cash/Card = Paid. Credit = Not Paid.
      amountPaid: method != 'CREDIT' ? amount : 0, 
      items: lineItems,
      userId: currentUser.uid, // Audit
      userName: currentUser.name, // Audit
    );
    
    // ATOMIC WRITE: Sale Doc + Stats Increment
    await FirebaseFirestore.instance.runTransaction((transaction) async {
       // 1. Write Sale
       transaction.set(docRef, sale.toMap());
       
       // 2. Increment Stats (Blind Write / SetMerge)
       transaction.set(statsRef, {
         'totalSales': FieldValue.increment(amount),
         'cashInHand': method == 'CASH' ? FieldValue.increment(amount) : FieldValue.increment(0),
         'creditGiven': method == 'CREDIT' ? FieldValue.increment(amount) : FieldValue.increment(0),
         'updatedAt': FieldValue.serverTimestamp(),
       }, SetOptions(merge: true));
    });
    
    print("Sale Saved Successfully: ${docRef.id}");
    return sale; // Return the sale object (useful for Receipt)
  }
  
  Future<bool> hasSalesForProduct(String productId) async {
    final query = await _collection
        .where('productIds', arrayContains: productId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // 1. Maintenance & self-Healing
  Future<void> performMaintenance() async {
     // A. Backfill Stats if needed (One-time Migration)
     _checkAndRunStatsMigration();

     // B. Delete Old Sales
     try {
       final cutoff = DateTime.now().subtract(const Duration(days: 60));
       // Batch delete is safer for large sets
       final snapshot = await _collection.where('timestamp', isLessThan: Timestamp.fromDate(cutoff)).limit(500).get();
       
       if (snapshot.docs.isNotEmpty) {
         print("Maintenance: Deleting ${snapshot.docs.length} old sales records.");
         final batch = FirebaseFirestore.instance.batch();
         for(var doc in snapshot.docs) {
           batch.delete(doc.reference);
         }
         await batch.commit();
       }
     } catch (e) {
       print("Maintenance Error: $e");
     }
  }

  Future<void> _checkAndRunStatsMigration() async {
    final metaDoc = _metadataCollection.doc('stats_migration');
    final docSnapshot = await metaDoc.get();
    
    if (!docSnapshot.exists) {
       print("MIGRATION: Starting Stats Backfill...");
       try {
          // 1. Fetch all sales from last 60 days
          final cutoff = DateTime.now().subtract(const Duration(days: 60));
          final salesSnap = await _collection.where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff)).get();
          
          if (salesSnap.docs.isNotEmpty) {
             print("MIGRATION: Found ${salesSnap.docs.length} sales to process.");
             final Map<String, Map<String, double>> aggregator = {};
             
             // 2. Aggregate in memory
             for (var doc in salesSnap.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final sale = Sale.fromMap(data);
                final dateKey = DateFormat('yyyy_MM_dd').format(sale.timestamp);
                
                if (!aggregator.containsKey(dateKey)) {
                   aggregator[dateKey] = {'total': 0, 'cash': 0, 'credit': 0};
                }
                
                aggregator[dateKey]!['total'] = aggregator[dateKey]!['total']! + sale.totalAmount;
                if (sale.paymentMethod == 'CASH') aggregator[dateKey]!['cash'] = aggregator[dateKey]!['cash']! + sale.totalAmount;
                if (sale.paymentMethod == 'CREDIT') aggregator[dateKey]!['credit'] = aggregator[dateKey]!['credit']! + sale.totalAmount;
             }
             
             // 3. Write to Stats Collection
             final batch = FirebaseFirestore.instance.batch();
             aggregator.forEach((date, stats) {
                final ref = _statsCollection.doc(date);
                batch.set(ref, {
                   'totalSales': stats['total'],
                   'cashInHand': stats['cash'],
                   'creditGiven': stats['credit'],
                   'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
             });
             
             await batch.commit();
             print("MIGRATION: Successfully backfilled ${aggregator.length} days of stats.");
          }
          
          // 4. Mark Complete
          await metaDoc.set({'migrated': true, 'migratedAt': FieldValue.serverTimestamp()});
          
       } catch (e) {
          print("MIGRATION FAILED: $e");
       }
    }
  }

  // Legacy Wrapper (Future Based) - kept for compatibility if needed
  Future<List<Sale>> getSales(DateTime start, DateTime end) async {
    final snapshot = await _collection
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => Sale.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }

  // 2. Stream Stats Query (Aggregated)
  Stream<DailySummary> getStatsStream(DateTime start, DateTime end) {
      final startStr = DateFormat('yyyy_MM_dd').format(start);
      final endStr = DateFormat('yyyy_MM_dd').format(end);
      
      if (startStr == endStr) {
         // Single Day - Stream 1 doc
         return _statsCollection.doc(startStr).snapshots().map((doc) {
            if (!doc.exists) return DailySummary(totalSales: 0, cashInHand: 0, creditGiven: 0, mostSoldItem: "N/A");
            final data = doc.data() as Map<String, dynamic>;
            return DailySummary(
              totalSales: (data['totalSales'] ?? 0).toDouble(),
              cashInHand: (data['cashInHand'] ?? 0).toDouble(),
              creditGiven: (data['creditGiven'] ?? 0).toDouble(),
              mostSoldItem: "View Details", 
            );
         });
      } else {
         // Multi-Day Range
         return _statsCollection
            .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
            .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
            .snapshots()
            .map((snapshot) {
                double total = 0;
                double cash = 0;
                double credit = 0;
                
                for(var doc in snapshot.docs) {
                   final data = doc.data() as Map<String, dynamic>;
                   total += (data['totalSales'] ?? 0).toDouble();
                   cash += (data['cashInHand'] ?? 0).toDouble();
                   credit += (data['creditGiven'] ?? 0).toDouble();
                }
                
                return DailySummary(
                  totalSales: total,
                  cashInHand: cash,
                  creditGiven: credit,
                  mostSoldItem: "Multiple Days",
                );
            });
      }
  }

  // Cost-Optimized: Paged Sales History Query
  Query getSalesQuery(DateTime start, DateTime end) {
    return _collection
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true);
  }

  // 3. Stream Sales List
  Stream<List<Sale>> getSalesStream(DateTime start, DateTime end) {
    return _collection
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Sale.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }
  
  // Legacy Wrapper
  Future<List<Sale>> getTodaySales() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getSales(start, end);
  }

  Stream<List<Sale>> getSalesByCustomer(String customerId) {
    print("Streaming sales for customer: $customerId");
    return _collection
        .where('customerId', isEqualTo: customerId)
        // .orderBy('timestamp', descending: true) // Index issue bypass
        .snapshots()
        .map((snapshot) {
          final sales = snapshot.docs.map((doc) => Sale.fromMap(doc.data() as Map<String, dynamic>)).toList();
          sales.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return sales;
        });
  }



  Future<void> recordPayment(String saleId, String customerId, double amount) async {
    return FirebaseFirestore.instance.runTransaction((transaction) async {
       final saleRef = _collection.doc(saleId);
       // NOTE: Assuming Customers are also isolated per user now, we must target correct path.
       // SalesRepository has userId, so we can construct path dynamically? Or just assume Repo usage.
       // But here we do raw transaction.
       // We need to use `_customerCollection` defined above if we want consistency.
       final customerRef = _customerCollection.doc(customerId);
       
       final saleSnapshot = await transaction.get(saleRef);
       final customerSnapshot = await transaction.get(customerRef);
       
       if (!saleSnapshot.exists) throw Exception("Sale not found");
       
       // Update Sale Logic
       final saleData = saleSnapshot.data() as Map<String, dynamic>;
       final currentPaid = (saleData['amountPaid'] ?? 0).toDouble(); // Safe cast
       final totalAmount = (saleData['totalAmount'] ?? 0).toDouble(); // Safe cast
       
       final newPaid = currentPaid + amount;
       final isFullyPaid = newPaid >= (totalAmount - 0.01); // Tolerance for float errors
       
       transaction.update(saleRef, {
         'amountPaid': newPaid,
         'isFullyPaid': isFullyPaid,
       });

       // Update Customer Balance Logic
       if (customerSnapshot.exists) {
         final data = customerSnapshot.data() as Map<String, dynamic>;
         final currentBalance = (data['currentBalance'] as num?)?.toDouble() ?? 0.0;
         transaction.update(customerRef, {
           'currentBalance': currentBalance - amount
         });
       }
    });
  }

  // ADVANCED REPORTS

  // 1. Sales Trend (Daily Totals)
  Future<List<Map<String, dynamic>>> getDailySalesTrend(DateTime start, DateTime end) async {
    final startStr = DateFormat('yyyy_MM_dd').format(start);
    final endStr = DateFormat('yyyy_MM_dd').format(end);

    // Fetch stats docs directly (Fast)
    final snapshot = await _statsCollection
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endStr)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Parse date from ID 'yyyy_MM_dd'
      final dateParts = doc.id.split('_'); 
      final date = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
      
      return {
        'date': date,
        'amount': (data['totalSales'] ?? 0).toDouble(),
      };
    }).toList();
  }

  // 2. Category Breakdown (Using Payment Method as Proxy for V1)
  Future<Map<String, double>> getPaymentBreakdown(DateTime start, DateTime end) async {
    final sales = await getSales(start, end);
    final Map<String, double> breakdown = {};
    
    for (var sale in sales) {
      breakdown[sale.paymentMethod] = (breakdown[sale.paymentMethod] ?? 0) + sale.totalAmount;
    }
    return breakdown;
  }

  // 3. Top Selling Items (Bar Chart)
  Future<List<Map<String, dynamic>>> getTopSellingItems(DateTime start, DateTime end, {int limit = 5}) async {
    final sales = await getSales(start, end);
    final Map<String, double> qtyMap = {};

    for (var sale in sales) {
      for (var item in sale.items) {
        // Strip "(Disc...)" for aggregation
        final cleanName = item.productName.split(' (Disc.').first;
        qtyMap[cleanName] = (qtyMap[cleanName] ?? 0) + item.quantity;
      }
    }

    var sorted = qtyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => {'name': e.key, 'qty': e.value}).toList();
  }

  // 4. Peak Hours (Heatmap)
  Future<Map<int, int>> getPeakHours(DateTime start, DateTime end) async {
    final sales = await getSales(start, end);
    final Map<int, int> hoursMap = {}; // Hour (0-23) -> Count

    for (var sale in sales) {
      final hour = sale.timestamp.hour;
      hoursMap[hour] = (hoursMap[hour] ?? 0) + 1;
    }
    return hoursMap;
  }
}

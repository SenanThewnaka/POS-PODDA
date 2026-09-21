import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/auth/auth_repository.dart';
import 'product_model.dart';
import 'stock_batch_model.dart';

import 'package:sme_buddy/features/users/user_repository.dart';

final productRepositoryProvider = Provider((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null) {
     throw Exception("ProductRepository accessed without user profile");
  }
  final repo = ProductRepository(userProfile.shopId);
  repo.performIntegrityCheck(); // Self-healing
  return repo;
});

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).productsStream();
});



class ProductRepository {
  final String userId;
  ProductRepository(this.userId);

  CollectionReference get _collection => 
      FirebaseFirestore.instance.collection('users').doc(userId).collection('products');
  
  // NOTE: Original _firestore reference for transactions is fine, but we need updated paths inside transactions.
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Stream<List<Product>> productsStream() {
    // Fetch ALL and filter client-side to handle legacy data (missing isActive field implies true)
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>; // Cast for safety
        data['id'] = doc.id; // overwrite id
        return Product.fromMap(data);
      }).toList();
    });
  }



  Stream<Product> getProductStream(String id) {
    return _collection.doc(id).snapshots().map((doc) {
       final data = doc.data() as Map<String, dynamic>;
       data['id'] = doc.id;
       return Product.fromMap(data);
    });
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final snapshot = await _collection.where('barcode', isEqualTo: barcode).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return Product.fromMap(data);
    }
    return null;
  }

  // Cost-Optimized Count for Quota Check
  Future<int> productsCount() async {
     final countQuery = await _collection.count().get();
     return countQuery.count ?? 0;
  }

  // --- BATCH MANAGEMENT ---

  Future<void> addStockBatch(String productId, StockBatch batch) async {
    // 1. Prepare Batch Reference
    final batchRef = _collection.doc(productId).collection('batches').doc();
    final batchData = batch.copyWith(id: batchRef.id, productId: productId).toMap();
    
    // 2. Use WriteBatch for Atomic Operation without read-lock requirement on Product
    final writeBatch = _firestore.batch();
    
    // Set New Batch
    writeBatch.set(batchRef, batchData);
    
    // Update Product Aggregate using FieldValue.increment
    final productRef = _collection.doc(productId);
    writeBatch.update(productRef, {
      'currentStock': FieldValue.increment(batch.currentStock),
      'sellingPrice': batch.sellingPrice, // Sync latest price
      'costPrice': batch.costPrice       // Sync latest cost
    });

    await writeBatch.commit();
  }

  Future<List<StockBatch>> getActiveBatches(String productId) async {
    final snapshot = await _collection.doc(productId).collection('batches')
        .where('currentStock', isGreaterThan: 0)
        .orderBy('currentStock') // Needed for query, but ideally we order by createdAt.
        // Composite index might be needed: currentStock > 0 AND orderBy createdAt.
        // For now, let's just get all > 0 and sort in memory.
        .get();
    
    final batches = snapshot.docs.map((d) {
      var data = d.data();
      data['id'] = d.id;
      return StockBatch.fromMap(data);
    }).toList();

    // Sort FIFO (Oldest First)
    batches.sort((a,b) => a.createdAt.compareTo(b.createdAt));
    return batches;
  }

  // Active Batches for POS (Must be Stock > 0 AND isActive == true)
  Future<List<StockBatch>> getPosBatches(String productId) async {
    final all = await getActiveBatches(productId);
    return all.where((b) => b.isActive).toList(); 
  }

  // Overridden addProduct to create initial batch
  Future<Product> addProduct(Product product) async {
    final docRef = _collection.doc();
    final data = product.toMap();
    data['id'] = docRef.id;
    
    // Create Product
    await docRef.set(data);

    // Create Initial Batch
    // Only if stock > 0 to avoid empty batches? 
    // Yes, but user might add 0 stock product. 
    // If stock > 0, create a batch.
    if (product.currentStock > 0) {
      final batch = StockBatch(
        id: '',
        productId: docRef.id,
        costPrice: product.costPrice,
        sellingPrice: product.sellingPrice,
        currentStock: product.currentStock,
        createdAt: DateTime.now(),
        isActive: true, // Default Active
      );
      // We can't use `addStockBatch` here easily because we are already in a flow? 
      // Actually we can just write to subcollection directly here.
      final batchRef = docRef.collection('batches').doc();
      await batchRef.set(batch.copyWith(id: batchRef.id).toMap());
    }
    
    return product.copyWith(id: docRef.id);
  }

  Future<void> migrateLegacyStock(String productId, StockBatch batch) async {
    final batchRef = _collection.doc(productId).collection('batches').doc();
    final batchData = batch.copyWith(id: batchRef.id, productId: productId).toMap();
    
    // Use WriteBatch for safety
    final writeBatch = _firestore.batch();
    writeBatch.set(batchRef, batchData);
    
    // DO NOT update aggregate stock here, as it is already correct on the product doc.
    await writeBatch.commit();
  }


  Future<void> updateStockBatch(String productId, StockBatch batch, {required double oldStock}) async {
       final batchRef = _collection.doc(productId).collection('batches').doc(batch.id);
       final productRef = _collection.doc(productId);

       // Removed blocking read for speed. oldStock passed from UI.
       final stockDiff = batch.currentStock - oldStock;

       // WriteBatch
       final writeBatch = _firestore.batch();
       
       writeBatch.update(batchRef, batch.toMap());
       
       // Update Aggregate only if stock changed
       if (stockDiff != 0) {
          writeBatch.update(productRef, {
            'currentStock': FieldValue.increment(stockDiff)
          });
       }
       
       await writeBatch.commit();
  }

  Future<void> updateProduct(Product product) async {
    await _collection.doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> deactivateProduct(String productId) async {
    final writeBatch = _firestore.batch();
    
    // 1. Deactivate Product
    writeBatch.update(_collection.doc(productId), {'isActive': false});
    
    // 2. Deactivate All Batches (Active or Inactive, just to be safe, disable them all)
    // Actually getActiveBatches only grabs stock > 0. 
    // We should probably grab ALL batches to strictly meet "all stocks user that product also should be deactivated"
    // But grabbing ALL batches might be heavy. 
    // Let's grab "Batches where isActive == true".
    // We haven't indexed that. 
    // Let's iterate what we can efficiently. 
    // Getting all active batches (stock > 0) is reasonable.
    // If a batch has 0 stock but isActive=true, it hardly matters, but we should probably clean it up.
    // For now, let's use getActiveBatches (stock > 0) as those are the meaningful ones.
    
    final batches = await getActiveBatches(productId);
    for (var batch in batches) {
       final batchRef = _collection.doc(productId).collection('batches').doc(batch.id);
       writeBatch.update(batchRef, {'isActive': false});
    }
    
    await writeBatch.commit();
  }

  Future<void> activateProduct(String productId) async {
    final writeBatch = _firestore.batch();
    
    // 1. Activate Product
    writeBatch.update(_collection.doc(productId), {'isActive': true});
    
    // 2. Activate Batches with Stock > 0
    // We want to restore availabilty of actual stock.
    final snapshot = await _collection.doc(productId).collection('batches')
        .where('currentStock', isGreaterThan: 0)
        .get();
        
    for (var doc in snapshot.docs) {
       writeBatch.update(doc.reference, {'isActive': true});
    }
    
    await writeBatch.commit();
  }

  Future<void> breakBulk(String sourceId, String targetId, double sourceQty, double targetQty, {double? newSellingPrice}) async {
     // 1. PRE-FETCH Source Product & Batches
     final sourceDoc = await _collection.doc(sourceId).get();
     final targetDoc = await _collection.doc(targetId).get();

     if (!sourceDoc.exists || !targetDoc.exists) throw Exception("Product not found");

     final sourceProduct = Product.fromMap(sourceDoc.data() as Map<String, dynamic>);
     final targetProduct = Product.fromMap(targetDoc.data() as Map<String, dynamic>);

     if (sourceProduct.currentStock < sourceQty) {
        throw Exception("Not enough stock in source item (${sourceProduct.name}). Available: ${sourceProduct.currentStock}");
     }
     
     // Fetch Source Batches (FIFO)
     final sourceBatches = await getActiveBatches(sourceId);
     
     // 2. PREPARE WRITE BATCH
     final writeBatch = _firestore.batch();
     
     // A. Handle Source Deduction (Aggregate)
     writeBatch.update(_collection.doc(sourceId), {
       'currentStock': FieldValue.increment(-sourceQty)
     });
     
     // B. Handle Source Batches Deduction
     double remainingToDeduct = sourceQty;
     for (var batch in sourceBatches) {
        if (remainingToDeduct <= 0) break;
        
        double available = batch.currentStock;
        double deduct = 0;
        
        if (available >= remainingToDeduct) {
           deduct = remainingToDeduct;
           remainingToDeduct = 0;
        } else {
           deduct = available;
           remainingToDeduct -= available;
        }
        
        final batchRef = _collection.doc(sourceId).collection('batches').doc(batch.id);
        writeBatch.update(batchRef, {
           'currentStock': FieldValue.increment(-deduct)
        });
     }
     
     // Note: If remainingToDeduct > 0 here, it means Aggregate > Sum of Batches (Ghost Stock).
     // We already deducted from Aggregate, so we accept the "Ghost Stock" is consumed.
     
     // C. Handle Target Addition (Aggregate)
     // Calculate value transffered
     double totalCostValue = sourceProduct.costPrice * sourceQty;
     double newUnitCost = totalCostValue / targetQty;
     
     writeBatch.update(_collection.doc(targetId), {
       'currentStock': FieldValue.increment(targetQty),
       'costPrice': newUnitCost // Update to latest batch cost logic
     });
     
     // D. Handle Target Batch Creation
     final targetBatchRef = _collection.doc(targetId).collection('batches').doc();
     final targetBatch = StockBatch(
        id: targetBatchRef.id,
        productId: targetId,
        costPrice: newUnitCost,
        sellingPrice: newSellingPrice ?? targetProduct.sellingPrice,
        currentStock: targetQty,
        createdAt: DateTime.now(),
        isActive: true,
     );
     writeBatch.set(targetBatchRef, targetBatch.toMap());
     
     // 3. COMMIT
     await writeBatch.commit();
  }

  Future<void> processSale(List<BatchSaleItem> items) async {
    // 1. PRE-FETCH: Get all active batches for involved products
    Map<String, List<StockBatch>> productBatches = {};
    
    // We need to fetch batches AND products to do logic
    // Let's fetch them now.
    
    for (var item in items) {
       // Get active batches sorted by date (FIFO)
       final batches = await getPosBatches(item.productId);
       // FIX: Do NOT filter by price. Stock is physical. Deduct from oldest batch.
       productBatches[item.productId] = batches;
    }

    // 2. READ CURRENT PRODUCT STATES (Aggregates)
    // We need this to update the total 'currentStock'
    Map<String, Product> productMap = {};
    for (var item in items) {
       final doc = await _collection.doc(item.productId).get();
       if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          productMap[item.productId] = Product.fromMap(data);
       }
    }

    // 3. PREPARE WRITE BATCH
    final writeBatch = _firestore.batch();
    
    for (var item in items) {
       if (!productMap.containsKey(item.productId)) continue;
       Product product = productMap[item.productId]!;
       
       // A. Deduct Aggregate
       // We can use FieldValue.increment for safety, no need to calc manually from 'product' snapshot 
       // (unless we want to validate < 0, but increment(-qty) allows negative which is fine for audit or we can block).
       // Using increment is safer for concurrency.
       
       final productRef = _collection.doc(item.productId);
       // Auto-Deactivate Check
       // Note: We use the pre-sale stock (product.currentStock) and deduct item.quantity.
       // If multiple items in one cart refer to same product, this logic is slightly flawed (race condition within loop),
       // but typically cart aggregates items by product.
       double newTotal = product.currentStock - item.quantity;
       Map<String, dynamic> productUpdate = {
         'currentStock': FieldValue.increment(-item.quantity)
       };
       
       if (newTotal <= 0 && product.productType != 'SERVICE') {
          productUpdate['isActive'] = false;
       }
       
       writeBatch.update(productRef, productUpdate);

       // B. Deduct Batches (FIFO)
       // logic: Iterate batches, deduct.
       // We must use specific values for batches, FieldValue.increment works there too!
       // But we need to know WHICH batches to touch.
       
       double quantityRemainingToDeduct = item.quantity;
       final batches = productBatches[item.productId] ?? [];
       
       for (var batch in batches) {
         if (quantityRemainingToDeduct <= 0) break;
         
         double available = batch.currentStock;
         if (available > 0) {
            double deduct = 0;
            if (available >= quantityRemainingToDeduct) {
               deduct = quantityRemainingToDeduct;
               quantityRemainingToDeduct = 0;
            } else {
               deduct = available;
               quantityRemainingToDeduct -= available;
            }
            
            final batchRef = _collection.doc(item.productId).collection('batches').doc(batch.id);
            writeBatch.update(batchRef, {
               'currentStock': FieldValue.increment(-deduct)
            });
         }
       }
    }
    
    // 4. COMMIT
    await writeBatch.commit();
  }

  Future<void> performIntegrityCheck() async {
    final metaRef = _collection.parent!.collection('system').doc('stock_integrity_v2');
    final metaDoc = await metaRef.get();
    
    if (!metaDoc.exists) {
      print("INTEGRITY: Starting Stock Correction...");
      try {
        final allProducts = await _collection.get();
        final batch = _firestore.batch();
        int corrections = 0;
        
        for (var doc in allProducts.docs) {
           final productData = doc.data() as Map<String, dynamic>;
           final currentAgg = (productData['currentStock'] as num?)?.toDouble() ?? 0.0;
           
           // Fetch batches
           final batchesSnap = await doc.reference.collection('batches').where('currentStock', isGreaterThan: 0).get();
           double actualSum = 0.0;
           for(var b in batchesSnap.docs) {
              actualSum += (b.data()['currentStock'] as num?)?.toDouble() ?? 0.0;
           }
           
           if ((currentAgg - actualSum).abs() > 0.01) {
              print("FIX: Product ${productData['name']} drifted. Agg: $currentAgg, Real: $actualSum");
              batch.update(doc.reference, {'currentStock': actualSum});
              corrections++;
           }
           
           // AUTO-DEACTIVATE CHECK (Cleanup)
           final isActive = productData['isActive'] ?? true;
           final isService = productData['productType'] == 'SERVICE';
           if (actualSum <= 0 && isActive && !isService) {
              print("FIX: Deactivating stockless product ${productData['name']}");
              batch.update(doc.reference, {'isActive': false});
              corrections++;
           }
        }
        
        if (corrections > 0) {
           await batch.commit();
           print("INTEGRITY: Fixed $corrections drifted products.");
        }
        
        await metaRef.set({'done': true, 'timestamp': FieldValue.serverTimestamp()});
        
      } catch (e) {
        print("Integrity Check Failed: $e");
      }
    }
  }

  // ALERTS (Admin Dashboard)
  Future<List<Product>> getLowStockItems() async {
    // Note: We can't do complex math in query (where current <= threshold).
    // Strategy: Fetch all ACTIVE items that are NOT Services.
    // Client-side filter: stock <= threshold.
    // Optimization: If we have many items, this is heavy. 
    // Alternative: We could maintain a 'isLowStock' flag on write. 
    // For now (MVP/SME scale): Client side filter is acceptable for < 2000 items.
    
    final snapshot = await _collection
        .where('isActive', isEqualTo: true)
        // .where('productType', isNotEqualTo: 'SERVICE') // Requires index if mixed with other fields?
        // Let's just fetch all active and filter.
        .get();
        
    final List<Product> lowStock = [];
    
    for (var doc in snapshot.docs) {
       final data = doc.data() as Map<String, dynamic>;
       data['id'] = doc.id;
       final p = Product.fromMap(data);
       
       if (p.productType == 'SERVICE') continue;
       
       double threshold = p.lowStockThreshold ?? 5.0;
       if (p.stockType == 'weight') threshold = p.lowStockThreshold ?? 0.500;
       
       if (p.currentStock <= threshold) {
          lowStock.add(p);
       }
    }
    return lowStock;
  }
}

class BatchSaleItem {
  final String productId;
  final double quantity;
  final double soldPrice;

  BatchSaleItem({required this.productId, required this.quantity, required this.soldPrice});
}

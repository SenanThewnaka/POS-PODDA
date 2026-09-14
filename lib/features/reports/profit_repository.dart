import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sme_buddy/features/users/user_repository.dart';
import 'package:sme_buddy/features/users/user_model.dart';
import 'package:sme_buddy/features/reports/sale_model.dart';
import 'package:sme_buddy/features/shifts/shift_model.dart';

class ProductProfitItem {
  final String productId;
  final String productName;
  final double quantitySold;
  final double revenue;
  final double cost;
  final double profit;
  final double marginPercent;

  ProductProfitItem({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.marginPercent,
  });
}

class ProfitSummary {
  final double totalRevenue;
  final double totalCOGS;
  final double grossProfit;
  final double grossMarginPercent;
  final double operatingExpenses;
  final double netProfit;
  final double netMarginPercent;
  final int transactionCount;
  final List<ProductProfitItem> topProducts;

  ProfitSummary({
    required this.totalRevenue,
    required this.totalCOGS,
    required this.grossProfit,
    required this.grossMarginPercent,
    required this.operatingExpenses,
    required this.netProfit,
    required this.netMarginPercent,
    required this.transactionCount,
    required this.topProducts,
  });

  factory ProfitSummary.empty() {
    return ProfitSummary(
      totalRevenue: 0,
      totalCOGS: 0,
      grossProfit: 0,
      grossMarginPercent: 0,
      operatingExpenses: 0,
      netProfit: 0,
      netMarginPercent: 0,
      transactionCount: 0,
      topProducts: [],
    );
  }
}

final profitRepositoryProvider = Provider<ProfitRepository>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null) {
    throw Exception("ProfitRepository accessed without user profile");
  }
  return ProfitRepository(userProfile);
});

final profitSummaryProvider =
    FutureProvider.family<ProfitSummary, DateTimeRange>((ref, range) {
  return ref.watch(profitRepositoryProvider).getProfitSummary(range.start, range.end);
});

class ProfitRepository {
  final UserModel currentUser;

  ProfitRepository(this.currentUser);

  CollectionReference get _salesCollection => FirebaseFirestore.instance
      .collection('shops')
      .doc(currentUser.shopId)
      .collection('sales');

  CollectionReference get _shiftsCollection => FirebaseFirestore.instance
      .collection('shops')
      .doc(currentUser.shopId)
      .collection('shifts');

  Future<ProfitSummary> getProfitSummary(DateTime start, DateTime end) async {
    // 1. Fetch sales in date range
    final salesSnap = await _salesCollection
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    double totalRev = 0.0;
    double totalCost = 0.0;
    final Map<String, _ProductAccumulator> productMap = {};

    for (final doc in salesSnap.docs) {
      final sale = Sale.fromMap(doc.data() as Map<String, dynamic>);
      totalRev += sale.totalAmount;

      for (final item in sale.items) {
        final lineRev = item.subTotal;
        final lineCost = item.quantity * item.costPrice;
        totalCost += lineCost;

        final acc = productMap.putIfAbsent(
          item.productId,
          () => _ProductAccumulator(productId: item.productId, productName: item.productName),
        );
        acc.quantity += item.quantity;
        acc.revenue += lineRev;
        acc.cost += lineCost;
      }
    }

    // 2. Fetch shifts in date range to calculate operating expenses (Cash-Outs)
    double totalExpenses = 0.0;
    try {
      final shiftsSnap = await _shiftsCollection
          .where('openedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('openedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      for (final doc in shiftsSnap.docs) {
        final shift = ShiftModel.fromMap(doc.data() as Map<String, dynamic>);
        totalExpenses += shift.cashOutTotal;
      }
    } catch (_) {
      // Fallback if index or shift query fails
    }

    final grossProfit = totalRev - totalCost;
    final grossMargin = totalRev > 0 ? (grossProfit / totalRev) * 100 : 0.0;
    final netProfit = grossProfit - totalExpenses;
    final netMargin = totalRev > 0 ? (netProfit / totalRev) * 100 : 0.0;

    final List<ProductProfitItem> productList = productMap.values.map((p) {
      final pProfit = p.revenue - p.cost;
      final pMargin = p.revenue > 0 ? (pProfit / p.revenue) * 100 : 0.0;
      return ProductProfitItem(
        productId: p.productId,
        productName: p.productName,
        quantitySold: p.quantity,
        revenue: p.revenue,
        cost: p.cost,
        profit: pProfit,
        marginPercent: pMargin,
      );
    }).toList();

    // Sort by most profitable
    productList.sort((a, b) => b.profit.compareTo(a.profit));

    return ProfitSummary(
      totalRevenue: totalRev,
      totalCOGS: totalCost,
      grossProfit: grossProfit,
      grossMarginPercent: grossMargin,
      operatingExpenses: totalExpenses,
      netProfit: netProfit,
      netMarginPercent: netMargin,
      transactionCount: salesSnap.docs.length,
      topProducts: productList,
    );
  }
}

class _ProductAccumulator {
  final String productId;
  final String productName;
  double quantity = 0.0;
  double revenue = 0.0;
  double cost = 0.0;

  _ProductAccumulator({required this.productId, required this.productName});
}

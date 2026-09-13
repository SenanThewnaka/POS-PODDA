import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierModel {
  final String id;
  final String name;
  final String? companyName;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  SupplierModel({
    required this.id,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  SupplierModel copyWith({
    String? id,
    String? name,
    String? companyName,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'companyName': companyName,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return SupplierModel(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? '',
      companyName: map['companyName'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      notes: map['notes'],
      isActive: map['isActive'] ?? true,
      createdAt: parseTime(map['createdAt']),
    );
  }
}

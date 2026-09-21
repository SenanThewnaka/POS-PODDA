import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String mobile;
  final String role; // 'owner', 'manager', 'cashier'
  final String shopId; // Critical for data access. For Owner, shopId == uid.
  
  final String? roleId; // Link to custom role
  final String? shopCode; // Unique short code for shop login (Owner only)
  final String? username; // Simplify login for employees
  final String? storedPassword; // Stored for simple employee management (Owner reset)
  final Map<String, bool> permissions; // Feature flags
  
  final String? shopName;
  final String? shopAddress;
  final String? shopMobile;
  
  // Invoice Customization
  final String? shopLogo; // Base64 or URL
  final String? invoiceFooterMessage; // "Thank you come again"
  final String? invoiceContactInfo; // "Tel: xxx"

  final bool isActive; // Logic delete for audit
  
  // Subscription
  final String plan; // 'trial', 'plus', 'pro'
  final String subscriptionStatus; // 'active', 'inactive'
  final String billingCycle; // 'monthly', 'quarterly', 'yearly', 'trial'
  final DateTime? expiryDate; // Nullable to handle legacy/loading, but logic should treat null as expired or trial? Best to default.
  final bool isVerified;
  final String? verificationCode;
  final bool welcomeSent;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.mobile,
    required this.role,
    required this.shopId,
    this.roleId,
    this.shopCode,
    this.username,
    this.storedPassword,
    this.permissions = const {},
    this.shopName,
    this.shopAddress,
    this.shopMobile,
    this.shopLogo,
    this.invoiceFooterMessage,
    this.invoiceContactInfo,
    this.isActive = true,
    this.plan = 'free',
    this.subscriptionStatus = 'active',
    this.billingCycle = 'lifetime',
    this.expiryDate,
    this.isVerified = true,
    this.verificationCode,
    this.welcomeSent = false,
  });

  bool hasPermission(String permission) {
    if (isAdmin) return true; // Owners have all permissions
    return permissions[permission] == true;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'mobile': mobile,
      'role': role,
      'shopId': shopId,
      'roleId': roleId,
      'shopCode': shopCode,
      'username': username,
      'storedPassword': storedPassword,
      'permissions': permissions,
      'shopName': shopName,
      'shopAddress': shopAddress,
      'shopMobile': shopMobile,
      'shopLogo': shopLogo,
      'invoiceFooterMessage': invoiceFooterMessage,
      'invoiceContactInfo': invoiceContactInfo,
      'isActive': isActive,
      'plan': plan,
      'subscriptionStatus': subscriptionStatus,
      'billingCycle': billingCycle,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isVerified': isVerified,
      'verificationCode': verificationCode,
      'welcomeSent': welcomeSent,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      role: map['role'] ?? 'owner',
      shopId: map['shopId'] ?? '',
      roleId: map['roleId'],
      shopCode: map['shopCode'],
      username: map['username'],
      storedPassword: map['storedPassword'],
      permissions: Map<String, bool>.from(map['permissions'] ?? {}),
      shopName: map['shopName'],
      shopAddress: map['shopAddress'],
      shopMobile: map['shopMobile'],
      shopLogo: map['shopLogo'],
      invoiceFooterMessage: map['invoiceFooterMessage'],
      invoiceContactInfo: map['invoiceContactInfo'],
      isActive: map['isActive'] ?? true,
      plan: map['currentPlan'] ?? map['plan'] ?? 'free',
      subscriptionStatus: map['subscriptionStatus'] ?? 'active',
      billingCycle: map['billingCycle'] ?? 'lifetime',
      expiryDate: map['expiryDate'] != null ? (map['expiryDate'] as Timestamp).toDate() : null,
      isVerified: map['isVerified'] ?? true,
      verificationCode: map['verificationCode'],
      welcomeSent: map['welcomeSent'] ?? false,
    );
  }

  // Helper to check if user has admin privileges
  bool get isAdmin => role == 'owner' || role == 'manager';

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? mobile,
    String? role,
    String? shopId,
    String? roleId,
    String? shopCode,
    String? username,
    String? storedPassword,
    Map<String, bool>? permissions,
    String? shopName,
    String? shopAddress,
    String? shopMobile,
    String? shopLogo,
    String? invoiceFooterMessage,
    String? invoiceContactInfo,
    String? plan,
    String? subscriptionStatus,
    String? billingCycle,
    DateTime? expiryDate,
    bool? isActive,
    bool? isVerified,
    String? verificationCode,
    bool? welcomeSent,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      shopId: shopId ?? this.shopId,
      roleId: roleId ?? this.roleId,
      shopCode: shopCode ?? this.shopCode,
      username: username ?? this.username,
      storedPassword: storedPassword ?? this.storedPassword,
      permissions: permissions ?? this.permissions,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopMobile: shopMobile ?? this.shopMobile,
      shopLogo: shopLogo ?? this.shopLogo,
      invoiceFooterMessage: invoiceFooterMessage ?? this.invoiceFooterMessage,
      invoiceContactInfo: invoiceContactInfo ?? this.invoiceContactInfo,
      isActive: isActive ?? this.isActive,
      plan: plan ?? this.plan,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      billingCycle: billingCycle ?? this.billingCycle,
      expiryDate: expiryDate ?? this.expiryDate,
      isVerified: isVerified ?? this.isVerified,
      verificationCode: verificationCode ?? this.verificationCode,
      welcomeSent: welcomeSent ?? this.welcomeSent,
    );
  }
}

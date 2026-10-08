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

  // Tax/VAT Fields
  final bool isVatRegistered;
  final String? vatNumber;
  final double vatPercentage;

  final bool isActive; // Logic delete for audit
  final bool isDeleted; // Account permanent deletion flag
  final DateTime? deletedAt; // Timestamp when account was deleted
  
  // Subscription
  final String plan; // 'trial', 'plus', 'pro'
  final String subscriptionStatus; // 'active', 'inactive'
  final String billingCycle; // 'monthly', 'quarterly', 'yearly', 'trial'
  final DateTime? expiryDate; // Nullable to handle legacy/loading, but logic should treat null as expired or trial? Best to default.
  final bool isVerified;
  final String? verificationCode;
  final bool welcomeSent;

  // Active Device Session (Single Device Enforcement for Plus Plan)
  final String? activeSessionId;
  final String? activeDeviceName;
  final DateTime? lastSessionClaimedAt;

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
    this.isVatRegistered = false,
    this.vatNumber,
    this.vatPercentage = 18.0,
    this.isActive = true,
    this.isDeleted = false,
    this.deletedAt,
    this.plan = 'trial',
    this.subscriptionStatus = 'active',
    this.billingCycle = 'trial',
    this.expiryDate,
    this.isVerified = true,
    this.verificationCode,
    this.welcomeSent = false,
    this.activeSessionId,
    this.activeDeviceName,
    this.lastSessionClaimedAt,
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
      'isVatRegistered': isVatRegistered,
      'vatNumber': vatNumber,
      'vatPercentage': vatPercentage,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'plan': plan,
      'currentPlan': plan,
      'subscriptionStatus': subscriptionStatus,
      'billingCycle': billingCycle,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isVerified': isVerified,
      'verificationCode': verificationCode,
      'welcomeSent': welcomeSent,
      'activeSessionId': activeSessionId,
      'activeDeviceName': activeDeviceName,
      'lastSessionClaimedAt': lastSessionClaimedAt != null ? Timestamp.fromDate(lastSessionClaimedAt!) : null,
    };
  }

  Map<String, dynamic> toCacheMap() {
    final map = toMap();
    // Do not cache sensitive credentials locally in SharedPreferences
    map.remove('storedPassword');
    map['isDeleted'] = isDeleted;
    if (deletedAt != null) {
      map['deletedAt'] = deletedAt!.toIso8601String();
    }
    if (expiryDate != null) {
      map['expiryDate'] = expiryDate!.toIso8601String();
    }
    if (lastSessionClaimedAt != null) {
      map['lastSessionClaimedAt'] = lastSessionClaimedAt!.toIso8601String();
    }
    return map;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime? parsedExpiry;
    final exp = map['expiryDate'];
    if (exp is Timestamp) {
      parsedExpiry = exp.toDate();
    } else if (exp is String) {
      parsedExpiry = DateTime.tryParse(exp);
    }

    DateTime? parsedDeletedAt;
    final del = map['deletedAt'];
    if (del is Timestamp) {
      parsedDeletedAt = del.toDate();
    } else if (del is String) {
      parsedDeletedAt = DateTime.tryParse(del);
    }

    DateTime? parsedSessionClaim;
    final sc = map['lastSessionClaimedAt'];
    if (sc is Timestamp) {
      parsedSessionClaim = sc.toDate();
    } else if (sc is String) {
      parsedSessionClaim = DateTime.tryParse(sc);
    }

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
      isVatRegistered: map['isVatRegistered'] ?? false,
      vatNumber: map['vatNumber'],
      vatPercentage: (map['vatPercentage'] ?? 18.0).toDouble(),
      isActive: map['isActive'] ?? true,
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: parsedDeletedAt,
      plan: map['plan'] ?? map['currentPlan'] ?? 'trial',
      subscriptionStatus: map['subscriptionStatus'] ?? 'active',
      billingCycle: map['billingCycle'] ?? 'trial',
      expiryDate: parsedExpiry,
      isVerified: map['isVerified'] ?? true,
      verificationCode: map['verificationCode'],
      welcomeSent: map['welcomeSent'] ?? false,
      activeSessionId: map['activeSessionId'],
      activeDeviceName: map['activeDeviceName'],
      lastSessionClaimedAt: parsedSessionClaim,
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
    bool? isVatRegistered,
    String? vatNumber,
    double? vatPercentage,
    String? plan,
    String? subscriptionStatus,
    String? billingCycle,
    DateTime? expiryDate,
    bool? isActive,
    bool? isDeleted,
    DateTime? deletedAt,
    bool? isVerified,
    String? verificationCode,
    bool? welcomeSent,
    String? activeSessionId,
    String? activeDeviceName,
    DateTime? lastSessionClaimedAt,
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
      isVatRegistered: isVatRegistered ?? this.isVatRegistered,
      vatNumber: vatNumber ?? this.vatNumber,
      vatPercentage: vatPercentage ?? this.vatPercentage,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      plan: plan ?? this.plan,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      billingCycle: billingCycle ?? this.billingCycle,
      expiryDate: expiryDate ?? this.expiryDate,
      isVerified: isVerified ?? this.isVerified,
      verificationCode: verificationCode ?? this.verificationCode,
      welcomeSent: welcomeSent ?? this.welcomeSent,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      activeDeviceName: activeDeviceName ?? this.activeDeviceName,
      lastSessionClaimedAt: lastSessionClaimedAt ?? this.lastSessionClaimedAt,
    );
  }
}

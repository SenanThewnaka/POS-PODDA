class AppPermissions {
  // Inventory & Stock
  static const String canManageInventory = 'CAN_MANAGE_INVENTORY'; // View list
  static const String canAddProducts = 'CAN_ADD_PRODUCTS';
  static const String canDeleteProducts = 'CAN_DELETE_PRODUCTS';
  static const String canViewCostPrice = 'CAN_VIEW_COST_PRICE'; // View wholesale cost & margins

  // POS & Checkout
  static const String canCheckout = 'CAN_CHECKOUT'; // POS
  static const String canGiveDiscount = 'CAN_GIVE_DISCOUNT'; // Manual discounts & price override

  // Procurement & ERP
  static const String canManageGRN = 'CAN_MANAGE_GRN'; // Receive & edit goods received notes

  // Financial, Shifts & Analytics
  static const String canManageShifts = 'CAN_MANAGE_SHIFTS'; // Open/close shifts & cash payouts
  static const String canViewSalesReports = 'CAN_VIEW_SALES_REPORTS'; // View sales & profit analytics

  // Credit Book (Potha) & CRM
  static const String canViewCredit = 'CAN_VIEW_CREDIT';
  static const String canEditCreditors = 'CAN_EDIT_CREDITORS'; // Add Customer
  static const String canSettleCredit = 'CAN_SETTLE_CREDIT'; // Add Payment

  // Staff & Role Management
  static const String canViewEmployees = 'CAN_VIEW_EMPLOYEES';
  static const String canAddEmployees = 'CAN_ADD_EMPLOYEES';
  static const String canEditEmployees = 'CAN_EDIT_EMPLOYEES';
  static const String canDeleteEmployees = 'CAN_DELETE_EMPLOYEES';

  static const List<String> allValues = [
    canCheckout,
    canGiveDiscount,
    canManageInventory,
    canAddProducts,
    canDeleteProducts,
    canViewCostPrice,
    canManageGRN,
    canManageShifts,
    canViewSalesReports,
    canViewCredit,
    canEditCreditors,
    canSettleCredit,
    canViewEmployees,
    canAddEmployees,
    canEditEmployees,
    canDeleteEmployees,
  ];

  static String getLabel(String key) {
    switch (key) {
      case canCheckout: return "Perform Sales (POS Checkout)";
      case canGiveDiscount: return "Apply Manual Discounts & Price Override";
      case canManageInventory: return "View Inventory Catalog & Stock";
      case canAddProducts: return "Add & Edit Products";
      case canDeleteProducts: return "Delete Products";
      case canViewCostPrice: return "View Wholesale Cost Price & Margins";
      case canManageGRN: return "Receive & Edit GRN (Procurement)";
      case canManageShifts: return "Manage Cash Drawer & Close Shift";
      case canViewSalesReports: return "View Sales & Profit Analytics";
      case canViewCredit: return "View Customer Credit Book";
      case canEditCreditors: return "Add & Edit Credit Customers";
      case canSettleCredit: return "Settle & Collect Credit Payments";
      case canViewEmployees: return "View Employee List";
      case canAddEmployees: return "Add New Employees";
      case canEditEmployees: return "Edit Employee Details";
      case canDeleteEmployees: return "Deactivate / Delete Employees";
      default: return key;
    }
  }

  // Pre-configured Default Role Presets
  static Map<String, bool> get defaultCashierPermissions => {
    canCheckout: true,
    canGiveDiscount: false, // Disallowed by default for standard cashiers
    canManageInventory: true,
    canAddProducts: false,
    canDeleteProducts: false,
    canViewCostPrice: false, // Masked by default
    canManageGRN: false,
    canManageShifts: true,
    canViewSalesReports: false,
    canViewCredit: true,
    canEditCreditors: true,
    canSettleCredit: true,
    canViewEmployees: false,
    canAddEmployees: false,
    canEditEmployees: false,
    canDeleteEmployees: false,
  };

  static Map<String, bool> get defaultStockKeeperPermissions => {
    canCheckout: false,
    canGiveDiscount: false,
    canManageInventory: true,
    canAddProducts: true,
    canDeleteProducts: false,
    canViewCostPrice: true,
    canManageGRN: true,
    canManageShifts: false,
    canViewSalesReports: false,
    canViewCredit: false,
    canEditCreditors: false,
    canSettleCredit: false,
    canViewEmployees: false,
    canAddEmployees: false,
    canEditEmployees: false,
    canDeleteEmployees: false,
  };

  static Map<String, bool> get defaultManagerPermissions => {
    canCheckout: true,
    canGiveDiscount: true,
    canManageInventory: true,
    canAddProducts: true,
    canDeleteProducts: true,
    canViewCostPrice: true,
    canManageGRN: true,
    canManageShifts: true,
    canViewSalesReports: true,
    canViewCredit: true,
    canEditCreditors: true,
    canSettleCredit: true,
    canViewEmployees: true,
    canAddEmployees: true,
    canEditEmployees: true,
    canDeleteEmployees: false, // Only owner deletes employees by default
  };
}

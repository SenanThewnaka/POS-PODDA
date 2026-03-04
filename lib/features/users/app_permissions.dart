class AppPermissions {
  static const String canManageInventory = 'CAN_MANAGE_INVENTORY'; // View list
  static const String canAddProducts = 'CAN_ADD_PRODUCTS';
  static const String canDeleteProducts = 'CAN_DELETE_PRODUCTS';
  
  static const String canCheckout = 'CAN_CHECKOUT'; // POS
  
  static const String canViewCredit = 'CAN_VIEW_CREDIT';
  static const String canEditCreditors = 'CAN_EDIT_CREDITORS'; // Add Customer
  static const String canSettleCredit = 'CAN_SETTLE_CREDIT'; // Add Payment

  static const String canViewEmployees = 'CAN_VIEW_EMPLOYEES';
  static const String canAddEmployees = 'CAN_ADD_EMPLOYEES';
  static const String canEditEmployees = 'CAN_EDIT_EMPLOYEES';
  static const String canDeleteEmployees = 'CAN_DELETE_EMPLOYEES';

  static const List<String> allValues = [
    canManageInventory,
    canAddProducts,
    canDeleteProducts,
    canCheckout,
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
      case canManageInventory: return "View Inventory";
      case canAddProducts: return "Add Products";
      case canDeleteProducts: return "Delete Products";
      case canCheckout: return "Perform Sales (POS)";
      case canViewCredit: return "View Credit Book";
      case canEditCreditors: return "Add/Edit Customers";
      case canSettleCredit: return "Settle/Collect Payments";
      case canViewEmployees: return "View Employee List";
      case canAddEmployees: return "Add New Employees";
      case canEditEmployees: return "Edit Employee Details";
      case canDeleteEmployees: return "Delete Employees";
      default: return key;
    }
  }
}

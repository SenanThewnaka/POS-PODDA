class RoleModel {
  final String id;
  final String shopId;
  final String name;
  final Map<String, bool> permissions;

  RoleModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.permissions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'name': name,
      'permissions': permissions,
    };
  }

  factory RoleModel.fromMap(Map<String, dynamic> map, String id) {
    return RoleModel(
      id: id,
      shopId: map['shopId'] ?? '',
      name: map['name'] ?? '',
      permissions: Map<String, bool>.from(map['permissions'] ?? {}),
    );
  }
}

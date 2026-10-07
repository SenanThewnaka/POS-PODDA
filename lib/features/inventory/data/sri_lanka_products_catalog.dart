import '../product_model.dart';

class PreloadCatalogItem {
  final String name;
  final String barcode;
  final String category;
  final double costPrice;
  final double sellingPrice;
  final String stockType; // 'unit' | 'weight'
  final String? baseUnit; // 'g', 'ml'
  final double defaultStock;
  final String brand;

  const PreloadCatalogItem({
    required this.name,
    required this.barcode,
    required this.category,
    required this.costPrice,
    required this.sellingPrice,
    this.stockType = 'unit',
    this.baseUnit,
    this.defaultStock = 10.0,
    required this.brand,
  });

  Product toProduct({double? initialStock, DateTime? createdAt}) {
    return Product(
      id: '',
      name: name,
      sellingPrice: sellingPrice,
      costPrice: costPrice,
      stockType: stockType,
      currentStock: initialStock ?? defaultStock,
      barcode: barcode,
      baseUnit: baseUnit,
      productType: 'PHYSICAL',
      isVariablePrice: false,
      isActive: true,
      isTaxable: true,
      createdAt: createdAt ?? DateTime.now(),
    );
  }
}

class SriLankaProductsCatalog {
  static const List<String> categories = [
    'All',
    'Biscuits & Bakery',
    'Dairy & Beverages',
    'Grocery & Cooking',
    'Personal Care & Cleaning',
    'Health & Stationery',
  ];

  static const List<PreloadCatalogItem> items = [
    // --- 1. BISCUITS & BAKERY ---
    PreloadCatalogItem(
      name: 'Munchee Super Cream Cracker 500g',
      barcode: '4792022011210',
      category: 'Biscuits & Bakery',
      costPrice: 380.0,
      sellingPrice: 420.0,
      brand: 'Munchee',
    ),
    PreloadCatalogItem(
      name: 'Munchee Super Cream Cracker 125g',
      barcode: '4792022011227',
      category: 'Biscuits & Bakery',
      costPrice: 100.0,
      sellingPrice: 120.0,
      brand: 'Munchee',
    ),
    PreloadCatalogItem(
      name: 'Munchee Chocolate Cream 400g',
      barcode: '4792022012019',
      category: 'Biscuits & Bakery',
      costPrice: 430.0,
      sellingPrice: 480.0,
      brand: 'Munchee',
    ),
    PreloadCatalogItem(
      name: 'Munchee Tikiri Marie 360g',
      barcode: '4792022013016',
      category: 'Biscuits & Bakery',
      costPrice: 280.0,
      sellingPrice: 320.0,
      brand: 'Munchee',
    ),
    PreloadCatalogItem(
      name: 'Munchee Hawaiian Cookies 200g',
      barcode: '4792022014013',
      category: 'Biscuits & Bakery',
      costPrice: 240.0,
      sellingPrice: 280.0,
      brand: 'Munchee',
    ),
    PreloadCatalogItem(
      name: 'Munchee Ginger Biscuits 200g',
      barcode: '4792022015010',
      category: 'Biscuits & Bakery',
      costPrice: 210.0,
      sellingPrice: 250.0,
      brand: 'Munchee',
    ),
    PreloadCatalogItem(
      name: 'Munchee Lemon Puff 200g',
      barcode: '4792022016017',
      category: 'Biscuits & Bakery',
      costPrice: 220.0,
      sellingPrice: 260.0,
      brand: 'Munchee',
    ),
    PreloadCatalogItem(
      name: 'Maliban Real Lemon Puff 200g',
      barcode: '4791007011018',
      category: 'Biscuits & Bakery',
      costPrice: 220.0,
      sellingPrice: 260.0,
      brand: 'Maliban',
    ),
    PreloadCatalogItem(
      name: 'Maliban Smart Cream Cracker 500g',
      barcode: '4791007012015',
      category: 'Biscuits & Bakery',
      costPrice: 380.0,
      sellingPrice: 420.0,
      brand: 'Maliban',
    ),
    PreloadCatalogItem(
      name: 'Maliban Chocolate Cream 400g',
      barcode: '4791007013012',
      category: 'Biscuits & Bakery',
      costPrice: 430.0,
      sellingPrice: 480.0,
      brand: 'Maliban',
    ),
    PreloadCatalogItem(
      name: 'Maliban Gold Marie 300g',
      barcode: '4791007014019',
      category: 'Biscuits & Bakery',
      costPrice: 270.0,
      sellingPrice: 310.0,
      brand: 'Maliban',
    ),
    PreloadCatalogItem(
      name: 'Maliban Cheese Bits 100g',
      barcode: '4791007015016',
      category: 'Biscuits & Bakery',
      costPrice: 170.0,
      sellingPrice: 200.0,
      brand: 'Maliban',
    ),
    PreloadCatalogItem(
      name: 'Ritzbury Milk Chocolate 50g',
      barcode: '4792022031010',
      category: 'Biscuits & Bakery',
      costPrice: 180.0,
      sellingPrice: 220.0,
      brand: 'Ritzbury',
    ),
    PreloadCatalogItem(
      name: 'Tiara Layer Cake Vanilla 30g',
      barcode: '4792022041019',
      category: 'Biscuits & Bakery',
      costPrice: 65.0,
      sellingPrice: 80.0,
      brand: 'Tiara',
    ),
    PreloadCatalogItem(
      name: 'Samaposha Pre-cooked Cereal 200g',
      barcode: '4792022051018',
      category: 'Biscuits & Bakery',
      costPrice: 190.0,
      sellingPrice: 230.0,
      brand: 'Samaposha',
    ),

    // --- 2. DAIRY, BEVERAGES & TEA ---
    PreloadCatalogItem(
      name: 'Anchor Full Cream Milk Powder 400g',
      barcode: '9414200115014',
      category: 'Dairy & Beverages',
      costPrice: 1040.0,
      sellingPrice: 1150.0,
      brand: 'Anchor',
    ),
    PreloadCatalogItem(
      name: 'Anchor Full Cream Milk Powder 1kg',
      barcode: '9414200115021',
      category: 'Dairy & Beverages',
      costPrice: 2550.0,
      sellingPrice: 2800.0,
      brand: 'Anchor',
    ),
    PreloadCatalogItem(
      name: 'Highland Full Cream Milk Powder 400g',
      barcode: '4792025011017',
      category: 'Dairy & Beverages',
      costPrice: 1000.0,
      sellingPrice: 1100.0,
      brand: 'Highland',
    ),
    PreloadCatalogItem(
      name: 'Highland Fresh Milk UHT 1L',
      barcode: '4792025012014',
      category: 'Dairy & Beverages',
      costPrice: 460.0,
      sellingPrice: 520.0,
      brand: 'Highland',
    ),
    PreloadCatalogItem(
      name: 'Highland Flavoured Milk Vanilla 180ml',
      barcode: '4792025013011',
      category: 'Dairy & Beverages',
      costPrice: 120.0,
      sellingPrice: 140.0,
      brand: 'Highland',
    ),
    PreloadCatalogItem(
      name: 'Highland Flavoured Milk Chocolate 180ml',
      barcode: '4792025013028',
      category: 'Dairy & Beverages',
      costPrice: 120.0,
      sellingPrice: 140.0,
      brand: 'Highland',
    ),
    PreloadCatalogItem(
      name: 'Pelwatte Milk Powder 400g',
      barcode: '4792031011010',
      category: 'Dairy & Beverages',
      costPrice: 990.0,
      sellingPrice: 1080.0,
      brand: 'Pelwatte',
    ),
    PreloadCatalogItem(
      name: 'Elephant House Ginger Beer (EGB) 400ml',
      barcode: '4792011011016',
      category: 'Dairy & Beverages',
      costPrice: 160.0,
      sellingPrice: 190.0,
      brand: 'Elephant House',
    ),
    PreloadCatalogItem(
      name: 'Elephant House Cream Soda 400ml',
      barcode: '4792011012013',
      category: 'Dairy & Beverages',
      costPrice: 160.0,
      sellingPrice: 190.0,
      brand: 'Elephant House',
    ),
    PreloadCatalogItem(
      name: 'Elephant House Necto 400ml',
      barcode: '4792011013010',
      category: 'Dairy & Beverages',
      costPrice: 160.0,
      sellingPrice: 190.0,
      brand: 'Elephant House',
    ),
    PreloadCatalogItem(
      name: 'Elephant House Apple Soda 400ml',
      barcode: '4792011014017',
      category: 'Dairy & Beverages',
      costPrice: 160.0,
      sellingPrice: 190.0,
      brand: 'Elephant House',
    ),
    PreloadCatalogItem(
      name: 'Milo Ready To Drink Pack 180ml',
      barcode: '8901058851013',
      category: 'Dairy & Beverages',
      costPrice: 130.0,
      sellingPrice: 150.0,
      brand: 'Nestlé',
    ),
    PreloadCatalogItem(
      name: 'Nestomalt Malted Drink 400g',
      barcode: '7613035011010',
      category: 'Dairy & Beverages',
      costPrice: 880.0,
      sellingPrice: 980.0,
      brand: 'Nestlé',
    ),
    PreloadCatalogItem(
      name: 'Milkmaid Condensed Milk 390g',
      barcode: '7613035022016',
      category: 'Dairy & Beverages',
      costPrice: 620.0,
      sellingPrice: 690.0,
      brand: 'Nestlé',
    ),
    PreloadCatalogItem(
      name: 'MD Mixed Fruit Cordial 750ml',
      barcode: '4792015011014',
      category: 'Dairy & Beverages',
      costPrice: 650.0,
      sellingPrice: 750.0,
      brand: 'MD',
    ),
    PreloadCatalogItem(
      name: 'Smak Mixed Fruit Nectar 200ml',
      barcode: '4792017011012',
      category: 'Dairy & Beverages',
      costPrice: 110.0,
      sellingPrice: 130.0,
      brand: 'Smak',
    ),
    PreloadCatalogItem(
      name: 'Watawala Pure Ceylon Tea 100g',
      barcode: '4792027011010',
      category: 'Dairy & Beverages',
      costPrice: 280.0,
      sellingPrice: 330.0,
      brand: 'Watawala',
    ),
    PreloadCatalogItem(
      name: 'Dilmah Premium Ceylon Tea 100g',
      barcode: '4791038011018',
      category: 'Dairy & Beverages',
      costPrice: 320.0,
      sellingPrice: 380.0,
      brand: 'Dilmah',
    ),
    PreloadCatalogItem(
      name: 'Zesta BOPF Pure Ceylon Tea 100g',
      barcode: '4791040011014',
      category: 'Dairy & Beverages',
      costPrice: 300.0,
      sellingPrice: 350.0,
      brand: 'Zesta',
    ),

    // --- 3. GROCERY, STAPLES & COOKING ---
    PreloadCatalogItem(
      name: 'Maggi 2-Minute Noodles Chicken 73g',
      barcode: '8901058862040',
      category: 'Grocery & Cooking',
      costPrice: 150.0,
      sellingPrice: 180.0,
      brand: 'Maggi',
    ),
    PreloadCatalogItem(
      name: 'Maggi 2-Minute Noodles Curry 73g',
      barcode: '8901058862057',
      category: 'Grocery & Cooking',
      costPrice: 150.0,
      sellingPrice: 180.0,
      brand: 'Maggi',
    ),
    PreloadCatalogItem(
      name: 'Prima Kottu Mee Hot & Spicy 80g',
      barcode: '4792024011010',
      category: 'Grocery & Cooking',
      costPrice: 160.0,
      sellingPrice: 190.0,
      brand: 'Prima',
    ),
    PreloadCatalogItem(
      name: 'Prima Special Wheat Flour 1kg',
      barcode: '4792024012017',
      category: 'Grocery & Cooking',
      costPrice: 220.0,
      sellingPrice: 260.0,
      brand: 'Prima',
    ),
    PreloadCatalogItem(
      name: 'Astra Margarine Fat Spread 250g',
      barcode: '8901030011015',
      category: 'Grocery & Cooking',
      costPrice: 360.0,
      sellingPrice: 410.0,
      brand: 'Astra',
    ),
    PreloadCatalogItem(
      name: 'Astra Margarine Fat Spread 500g',
      barcode: '8901030011022',
      category: 'Grocery & Cooking',
      costPrice: 680.0,
      sellingPrice: 770.0,
      brand: 'Astra',
    ),
    PreloadCatalogItem(
      name: 'MD Tomato Sauce Bottle 400g',
      barcode: '4792015021013',
      category: 'Grocery & Cooking',
      costPrice: 390.0,
      sellingPrice: 450.0,
      brand: 'MD',
    ),
    PreloadCatalogItem(
      name: 'MD Chili Sauce Bottle 400g',
      barcode: '4792015022010',
      category: 'Grocery & Cooking',
      costPrice: 410.0,
      sellingPrice: 480.0,
      brand: 'MD',
    ),
    PreloadCatalogItem(
      name: 'MD Mixed Fruit Jam 500g',
      barcode: '4792015031019',
      category: 'Grocery & Cooking',
      costPrice: 520.0,
      sellingPrice: 600.0,
      brand: 'MD',
    ),
    PreloadCatalogItem(
      name: 'Edinborough Tomato Sauce 400g',
      barcode: '4792035011016',
      category: 'Grocery & Cooking',
      costPrice: 380.0,
      sellingPrice: 440.0,
      brand: 'Edinborough',
    ),
    PreloadCatalogItem(
      name: 'Knorr Chicken Cubes 2x10g',
      barcode: '8901030021014',
      category: 'Grocery & Cooking',
      costPrice: 75.0,
      sellingPrice: 90.0,
      brand: 'Knorr',
    ),
    PreloadCatalogItem(
      name: 'Harischandra Pure Coffee 100g',
      barcode: '4792019011018',
      category: 'Grocery & Cooking',
      costPrice: 320.0,
      sellingPrice: 370.0,
      brand: 'Harischandra',
    ),
    PreloadCatalogItem(
      name: 'Harischandra Kurakkan Flour 400g',
      barcode: '4792019012015',
      category: 'Grocery & Cooking',
      costPrice: 280.0,
      sellingPrice: 330.0,
      brand: 'Harischandra',
    ),
    PreloadCatalogItem(
      name: 'Wijeya Pure Chili Powder 100g',
      barcode: '4792026011016',
      category: 'Grocery & Cooking',
      costPrice: 230.0,
      sellingPrice: 270.0,
      brand: 'Wijeya',
    ),
    PreloadCatalogItem(
      name: 'Wijeya Roasted Curry Powder 100g',
      barcode: '4792026012013',
      category: 'Grocery & Cooking',
      costPrice: 210.0,
      sellingPrice: 250.0,
      brand: 'Wijeya',
    ),
    PreloadCatalogItem(
      name: 'Wijeya Pure Turmeric Powder 50g',
      barcode: '4792026013010',
      category: 'Grocery & Cooking',
      costPrice: 190.0,
      sellingPrice: 230.0,
      brand: 'Wijeya',
    ),
    PreloadCatalogItem(
      name: 'Raigam Deveni Batha Rice Noodles 400g',
      barcode: '4792033011011',
      category: 'Grocery & Cooking',
      costPrice: 280.0,
      sellingPrice: 340.0,
      brand: 'Raigam',
    ),
    PreloadCatalogItem(
      name: 'Marina Pure Coconut Oil 1L',
      barcode: '4792037011014',
      category: 'Grocery & Cooking',
      costPrice: 880.0,
      sellingPrice: 990.0,
      brand: 'Marina',
    ),

    // --- 4. PERSONAL CARE & CLEANING ---
    PreloadCatalogItem(
      name: 'Sunlight Yellow Laundry Soap 115g',
      barcode: '8901030701015',
      category: 'Personal Care & Cleaning',
      costPrice: 120.0,
      sellingPrice: 140.0,
      brand: 'Sunlight',
    ),
    PreloadCatalogItem(
      name: 'Sunlight Care Rose Soap 115g',
      barcode: '8901030701022',
      category: 'Personal Care & Cleaning',
      costPrice: 120.0,
      sellingPrice: 140.0,
      brand: 'Sunlight',
    ),
    PreloadCatalogItem(
      name: 'Sunlight Washing Powder 500g',
      barcode: '8901030702012',
      category: 'Personal Care & Cleaning',
      costPrice: 320.0,
      sellingPrice: 370.0,
      brand: 'Sunlight',
    ),
    PreloadCatalogItem(
      name: 'Lifebuoy Total Hand & Body Soap 100g',
      barcode: '8901030801012',
      category: 'Personal Care & Cleaning',
      costPrice: 155.0,
      sellingPrice: 180.0,
      brand: 'Lifebuoy',
    ),
    PreloadCatalogItem(
      name: 'Lux Velvet Touch Beauty Soap 100g',
      barcode: '8901030802019',
      category: 'Personal Care & Cleaning',
      costPrice: 165.0,
      sellingPrice: 195.0,
      brand: 'Lux',
    ),
    PreloadCatalogItem(
      name: 'Signal Strong Teeth Toothpaste 120g',
      barcode: '8901030601018',
      category: 'Personal Care & Cleaning',
      costPrice: 230.0,
      sellingPrice: 270.0,
      brand: 'Signal',
    ),
    PreloadCatalogItem(
      name: 'Clogard Fresh Mint Toothpaste 120g',
      barcode: '4792021011013',
      category: 'Personal Care & Cleaning',
      costPrice: 220.0,
      sellingPrice: 260.0,
      brand: 'Clogard',
    ),
    PreloadCatalogItem(
      name: 'Baby Cheramy Floral Soap 100g',
      barcode: '4792020011015',
      category: 'Personal Care & Cleaning',
      costPrice: 170.0,
      sellingPrice: 200.0,
      brand: 'Baby Cheramy',
    ),
    PreloadCatalogItem(
      name: 'Kumarika Hair Fall Control Oil 100ml',
      barcode: '4792020013019',
      category: 'Personal Care & Cleaning',
      costPrice: 360.0,
      sellingPrice: 420.0,
      brand: 'Kumarika',
    ),
    PreloadCatalogItem(
      name: 'Diva Power Washing Powder 400g',
      barcode: '4792020014016',
      category: 'Personal Care & Cleaning',
      costPrice: 250.0,
      sellingPrice: 290.0,
      brand: 'Diva',
    ),
    PreloadCatalogItem(
      name: 'Vim Dishwash Bar 100g',
      barcode: '8901030901019',
      category: 'Personal Care & Cleaning',
      costPrice: 90.0,
      sellingPrice: 110.0,
      brand: 'Vim',
    ),
    PreloadCatalogItem(
      name: 'Surf Excel Washing Powder 500g',
      barcode: '8901030703019',
      category: 'Personal Care & Cleaning',
      costPrice: 410.0,
      sellingPrice: 470.0,
      brand: 'Surf Excel',
    ),
    PreloadCatalogItem(
      name: 'Harpic Power Plus Cleaner 500ml',
      barcode: '5000158022010',
      category: 'Personal Care & Cleaning',
      costPrice: 480.0,
      sellingPrice: 550.0,
      brand: 'Harpic',
    ),
    PreloadCatalogItem(
      name: 'Dettol Antiseptic Liquid 100ml',
      barcode: '5000158012011',
      category: 'Personal Care & Cleaning',
      costPrice: 340.0,
      sellingPrice: 395.0,
      brand: 'Dettol',
    ),
    PreloadCatalogItem(
      name: 'Dettol Original Bath Soap 100g',
      barcode: '5000158011014',
      category: 'Personal Care & Cleaning',
      costPrice: 180.0,
      sellingPrice: 210.0,
      brand: 'Dettol',
    ),

    // --- 5. HEALTH & STATIONERY ---
    PreloadCatalogItem(
      name: 'Link Samahan Herbal Infusion Sachet',
      barcode: '4792028010012',
      category: 'Health & Stationery',
      costPrice: 45.0,
      sellingPrice: 55.0,
      brand: 'Link Natural',
    ),
    PreloadCatalogItem(
      name: 'Siddhalepa Herbal Balm 10g',
      barcode: '4792023011011',
      category: 'Health & Stationery',
      costPrice: 120.0,
      sellingPrice: 150.0,
      brand: 'Siddhalepa',
    ),
    PreloadCatalogItem(
      name: 'Siddhalepa Herbal Balm 25g',
      barcode: '4792023011028',
      category: 'Health & Stationery',
      costPrice: 240.0,
      sellingPrice: 290.0,
      brand: 'Siddhalepa',
    ),
    PreloadCatalogItem(
      name: 'Panadol Paracetamol 500mg (10 Tabs)',
      barcode: '8901067011012',
      category: 'Health & Stationery',
      costPrice: 65.0,
      sellingPrice: 80.0,
      brand: 'Panadol',
    ),
    PreloadCatalogItem(
      name: 'Atlas CR Single Rule Book 120 Pages',
      barcode: '4792039011012',
      category: 'Health & Stationery',
      costPrice: 190.0,
      sellingPrice: 230.0,
      brand: 'Atlas',
    ),
    PreloadCatalogItem(
      name: 'Atlas Exercise Book 80 Pages Single Rule',
      barcode: '4792039012019',
      category: 'Health & Stationery',
      costPrice: 110.0,
      sellingPrice: 140.0,
      brand: 'Atlas',
    ),
    PreloadCatalogItem(
      name: 'Atlas Chooty Ballpoint Pen (Blue)',
      barcode: '4792039013016',
      category: 'Health & Stationery',
      costPrice: 30.0,
      sellingPrice: 40.0,
      brand: 'Atlas',
    ),
  ];

  static PreloadCatalogItem? findByBarcode(String barcode) {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;
    for (final item in items) {
      if (item.barcode == clean) return item;
    }
    return null;
  }

  static List<PreloadCatalogItem> getByCategory(String category) {
    if (category == 'All') return items;
    return items.where((i) => i.category == category).toList();
  }

  static List<PreloadCatalogItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((i) {
      return i.name.toLowerCase().contains(q) ||
          i.barcode.contains(q) ||
          i.brand.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q);
    }).toList();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/models/user_model.dart';
import 'package:hypermart/core/providers/product_provider.dart';
import 'package:hypermart/core/providers/order_provider.dart';
import 'package:hypermart/core/providers/config_provider.dart';
import 'package:hypermart/domain/repositories/product_repository.dart';
import 'package:hypermart/domain/repositories/order_repository.dart';
import 'package:hypermart/domain/repositories/config_repository.dart';
import 'package:hypermart/domain/entities/product.dart';
import 'package:hypermart/domain/entities/order.dart';
import 'package:hypermart/domain/entities/inventory_ledger.dart';
import 'package:hypermart/domain/entities/app_config.dart';
import 'package:hypermart/domain/entities/dashboard_stats.dart';

class MockProductRepository implements ProductRepository {
  bool shouldFail = false;

  @override
  Future<void> addProduct(Product product) async {
    if (shouldFail) throw Exception("DB Error");
  }

  @override
  Future<void> updateProduct(Product product) async {
    if (shouldFail) throw Exception("DB Error");
  }

  @override
  Future<void> deleteProduct(String id) async {
    if (shouldFail) throw Exception("DB Error");
  }

  @override
  Stream<List<Product>> streamProducts() => Stream.value([]);

  @override
  Future<Product?> getProductById(String id) async => null;

  @override
  Stream<List<InventoryLedger>> streamInventoryLogs(String productId, {int limit = 200}) =>
      Stream.value([]);

  @override
  Stream<List<InventoryLedger>> streamAllInventoryLogs({int limit = 50}) => Stream.value([]);

  @override
  Future<void> adjustStock({
    required String productId,
    required int physicalDelta,
    required int reservedDelta,
    required String changeType,
    required String notes,
    required String adminId,
  }) async {
    if (shouldFail) throw Exception("DB Error");
  }
}

class MockOrderRepository implements OrderRepository {
  bool shouldFail = false;

  @override
  Future<PlaceOrderResult> placeOrder({
    required List<OrderItem> items,
    required String deliveryAddress,
    double? latitude,
    double? longitude,
  }) async {
    if (shouldFail) return const PlaceOrderResult.failure("DB Error");
    return const PlaceOrderResult.success(orderId: "order_123", otp: "1234");
  }

  @override
  Future<String?> verifyDeliveryOtp(String orderId, String otp) async {
    if (shouldFail) return "Incorrect OTP";
    return null;
  }

  @override
  Future<String?> getOrderOtp(String orderId) async {
    return "1234";
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    if (shouldFail) throw Exception("DB Error");
  }

  @override
  Future<void> submitOrderRating(String orderId, int rating, String? comment) async {
    if (shouldFail) throw Exception("DB Error");
  }

  @override
  Future<String?> acceptOrder(String orderId) async {
    if (shouldFail) return "DB Error";
    return null;
  }

  @override
  Future<void> updateDeliveryBoyActiveStatus(String riderId, bool isActive) async {
    if (shouldFail) throw Exception("DB Error");
  }

  @override
  Future<void> updateDeliveryBoyDutyStatus(String riderId, bool onDuty) async {
    if (shouldFail) throw Exception("DB Error");
  }

  @override
  Future<String> whitelistDeliveryBoy(
      String name, String email, String phone, String village,
      {String? vehicleNo, String? licenseNo}) async {
    if (shouldFail) throw Exception("DB Error");
    return "temp-password";
  }

  @override
  Future<void> updateDeliveryBoyDetails({
    required String docId,
    required String name,
    required String email,
    required String phone,
    required String village,
    String? vehicleNo,
    String? licenseNo,
  }) async {
    if (shouldFail) throw Exception("DB Error");
  }

  @override
  Future<void> deleteDeliveryBoy(String docId) async {
    if (shouldFail) throw Exception("DB Error");
  }

  @override
  Stream<List<Order>> streamCustomerOrders(String customerId) => Stream.value([]);

  @override
  Stream<List<Order>> streamDeliveryBoyOrders(String deliveryBoyId) => Stream.value([]);

  @override
  Stream<List<Order>> streamAllOrders({int limit = 300}) => Stream.value([]);

  @override
  Stream<List<Order>> streamIncomingOffers({int limit = 30}) => Stream.value([]);

  @override
  Stream<List<UserModel>> streamAllDeliveryBoys({int limit = 200}) => Stream.value([]);

  @override
  Stream<Order> streamOrder(String orderId) => Stream.value(Order(
        id: orderId,
        customerId: "c1",
        customerName: "Customer",
        customerPhone: "123",
        deliveryAddress: "Addr",
        village: "Village",
        items: [],
        totalAmount: 100,
        paymentMethod: "COD",
        status: "pending",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
}

class MockConfigRepository implements ConfigRepository {
  bool shouldFail = false;
  AppConfig lastUpdatedConfig = AppConfig(
    storeOpen: true,
    deliveryFee: 30,
    freeDeliveryAbove: 300,
    updatedAt: DateTime.now(),
  );

  @override
  Stream<AppConfig> streamAppConfig() => Stream.value(lastUpdatedConfig);

  @override
  Stream<DashboardStats> streamDashboardStats() => Stream.value(DashboardStats(
        activeOrdersCount: 2,
        activeRidersCount: 3,
        completedRevenue: 1500,
        productCount: 12,
        lastUpdated: DateTime.now(),
      ));

  @override
  Future<void> updateAppConfig(AppConfig config) async {
    if (shouldFail) throw Exception("DB Error");
    lastUpdatedConfig = config;
  }
}

void main() {
  group('ProductProvider Unit Tests', () {
    late MockProductRepository repo;
    late ProductProvider provider;

    setUp(() {
      repo = MockProductRepository();
      provider = ProductProvider(repository: repo);
    });

    test('addProduct sets loading state and succeeds', () async {
      final product = Product(
        id: '1',
        name: 'Milk',
        description: 'Fresh milk',
        price: 30.0,
        imageUrl: 'http://example.com/image.png',
        category: 'Dairy',
        stock: 10,
        unit: 'packet',
        physicalStock: 10,
        reservedStock: 0,
        availableStock: 10,
      );

      expect(provider.isLoading, false);
      expect(provider.errorMessage, null);

      final future = provider.addProduct(product);
      expect(provider.isLoading, true);

      final success = await future;
      expect(success, true);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, null);
    });

    test('addProduct handles repo exception and sets error', () async {
      repo.shouldFail = true;
      final product = Product(
        id: '1',
        name: 'Milk',
        description: 'Fresh milk',
        price: 30.0,
        imageUrl: 'http://example.com/image.png',
        category: 'Dairy',
        stock: 10,
        unit: 'packet',
        physicalStock: 10,
        reservedStock: 0,
        availableStock: 10,
      );

      final success = await provider.addProduct(product);
      expect(success, false);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, contains('DB Error'));
    });

    test('adjustStock updates correctly', () async {
      final success = await provider.adjustStock(
        productId: '1',
        physicalDelta: 5,
        reservedDelta: 0,
        changeType: 'restock',
        notes: 'restocked',
        adminId: 'admin_1',
      );
      expect(success, true);
      expect(provider.errorMessage, null);
    });
  });

  group('OrderProvider Unit Tests', () {
    late MockOrderRepository repo;
    late OrderProvider provider;

    setUp(() {
      repo = MockOrderRepository();
      provider = OrderProvider(repository: repo);
    });

    test('verifyDelivery returns null on success', () async {
      final error = await provider.verifyDelivery('order_1', '1234');
      expect(error, null);
    });

    test('verifyDelivery returns message on failure', () async {
      repo.shouldFail = true;
      final error = await provider.verifyDelivery('order_1', '1234');
      expect(error, equals('Incorrect OTP'));
    });
  });

  group('ConfigProvider Unit Tests', () {
    late MockConfigRepository repo;
    late ConfigProvider provider;

    setUp(() {
      repo = MockConfigRepository();
      provider = ConfigProvider(repository: repo);
    });

    test('updateAppConfig sets loading state and succeeds', () async {
      final config = AppConfig(
        storeOpen: false,
        deliveryFee: 50,
        freeDeliveryAbove: 500,
        updatedAt: DateTime.now(),
      );

      expect(provider.isLoading, false);
      expect(provider.errorMessage, null);

      final future = provider.updateAppConfig(config);
      expect(provider.isLoading, true);

      final success = await future;
      expect(success, true);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, null);
      expect(repo.lastUpdatedConfig.storeOpen, false);
      expect(repo.lastUpdatedConfig.deliveryFee, 50);
    });

    test('updateAppConfig handles repo exception and sets error', () async {
      repo.shouldFail = true;
      final config = AppConfig(
        storeOpen: false,
        deliveryFee: 50,
        freeDeliveryAbove: 500,
        updatedAt: DateTime.now(),
      );

      final success = await provider.updateAppConfig(config);
      expect(success, false);
      expect(provider.isLoading, false);
      expect(provider.errorMessage, contains('DB Error'));
    });
  });
}

class AppConfig {
  final bool storeOpen;
  final double deliveryFee;
  final double freeDeliveryAbove;
  final DateTime updatedAt;
  final String? etaLabel;
  final double riderPayoutPerDelivery;
  final String? supportPhone;
  final String? supportWhatsapp;
  final List<String> categories;
  final bool maintenanceMode;
  final double minimumOrderAmount;
  final int maxOrdersPerSlot;

  AppConfig({
    required this.storeOpen,
    required this.deliveryFee,
    required this.freeDeliveryAbove,
    required this.updatedAt,
    this.etaLabel,
    this.riderPayoutPerDelivery = 30.0,
    this.supportPhone,
    this.supportWhatsapp,
    this.categories = const [],
    this.maintenanceMode = false,
    this.minimumOrderAmount = 0.0,
    this.maxOrdersPerSlot = 20,
  });
}

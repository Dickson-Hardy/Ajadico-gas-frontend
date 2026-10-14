class NozzleItem {
  /// Permanent database UUID. Names and legacy numeric keys are not identities.
  final String id;
  final String? displayName;
  final int nozzleNumber;
  final String productName; // 'PMS' or 'AGO'
  final String tankCode; // 'T1', 'T2', 'T3'
  double openingReading;
  double? closingReading;
  final double pricePerLitre;
  bool isOpeningConfirmed;

  NozzleItem({
    this.id = '',
    this.displayName,
    required this.nozzleNumber,
    required this.productName,
    required this.tankCode,
    required this.openingReading,
    this.closingReading,
    required this.pricePerLitre,
    this.isOpeningConfirmed = false,
  });

  String get label => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : 'Pump$nozzleNumber';

  static String validateName(String name) {
    final value = name.trim();
    if (value.isEmpty ||
        value.length > 80 ||
        RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(value)) {
      throw const FormatException(
          'Enter a pump name of 1–80 characters without control characters.');
    }
    return value;
  }

  double get litresSold {
    if (closingReading == null || closingReading! < openingReading) {
      return 0.0;
    }
    return closingReading! - openingReading;
  }

  double get salesValue {
    return litresSold * pricePerLitre;
  }
}

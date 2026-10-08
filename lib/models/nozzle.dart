class NozzleItem {
  final int nozzleNumber;
  final String productName; // 'PMS' or 'AGO'
  final String tankCode;    // 'T1', 'T2', 'T3'
  double openingReading;
  double? closingReading;
  final double pricePerLitre;
  bool isOpeningConfirmed;

  NozzleItem({
    required this.nozzleNumber,
    required this.productName,
    required this.tankCode,
    required this.openingReading,
    this.closingReading,
    required this.pricePerLitre,
    this.isOpeningConfirmed = false,
  });

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

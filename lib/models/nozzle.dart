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

  static List<NozzleItem> getDemoNozzles() {
    return [
      NozzleItem(
        nozzleNumber: 1,
        productName: 'PMS',
        tankCode: 'T1',
        openingReading: 412380.5,
        pricePerLitre: 1050.0,
        isOpeningConfirmed: true,
      ),
      NozzleItem(
        nozzleNumber: 2,
        productName: 'PMS',
        tankCode: 'T1',
        openingReading: 388102.0,
        pricePerLitre: 1050.0,
        isOpeningConfirmed: false,
      ),
      NozzleItem(
        nozzleNumber: 3,
        productName: 'AGO',
        tankCode: 'T3',
        openingReading: 201775.5,
        pricePerLitre: 1320.0,
        isOpeningConfirmed: true,
      ),
    ];
  }
}

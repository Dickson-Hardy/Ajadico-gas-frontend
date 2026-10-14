import '../lib/models/nozzle.dart';
import '../lib/models/shift_adjustment.dart';

void main() {
  var count = 0;
  void check(bool value) {
    if (!value) throw StateError('Pump check ${count + 1} failed');
    count++;
  }

  for (final name in [
    'Pump1',
    'Pump1a',
    'Pump1b',
    'Diesel Left',
    'East / PMS',
    '燃油 A'
  ]) {
    check(NozzleItem.validateName(name) == name);
  }
  check(NozzleItem.validateName('  Pump1a  ') == 'Pump1a');
  for (final name in [
    '',
    '   ',
    'x' * 81,
    'Pump\n1',
    'Pump\t1',
    'Pump\u00851'
  ]) {
    var rejected = false;
    try {
      NozzleItem.validateName(name);
    } on FormatException {
      rejected = true;
    }
    check(rejected);
  }
  final a = NozzleItem(
      id: '00000000-0000-4000-8000-000000000001',
      displayName: 'Pump1a',
      nozzleNumber: 1,
      productName: 'PMS',
      tankCode: 'T1',
      openingReading: 100,
      closingReading: 120,
      pricePerLitre: 10);
  final b = NozzleItem(
      id: '00000000-0000-4000-8000-000000000002',
      displayName: 'Pump1b',
      nozzleNumber: 2,
      productName: 'PMS',
      tankCode: 'T1',
      openingReading: 200,
      closingReading: 205,
      pricePerLitre: 10);
  check(a.id != b.id);
  check(a.label == 'Pump1a' && b.label == 'Pump1b');
  check(a.litresSold == 20 && b.litresSold == 5);
  final renamed = NozzleItem(
      id: a.id,
      displayName: 'Diesel Left',
      nozzleNumber: a.nozzleNumber,
      productName: a.productName,
      tankCode: a.tankCode,
      openingReading: a.openingReading,
      closingReading: a.closingReading,
      pricePerLitre: a.pricePerLitre);
  check(renamed.id == a.id && renamed.nozzleNumber == a.nozzleNumber);
  check(
      renamed.salesValue == a.salesValue && renamed.litresSold == a.litresSold);
  check(
      a.label == 'Pump1a'); // An earlier shift snapshot isn't renamed in place.
  final adjustment = ShiftAdjustment(
      id: 'entry',
      shiftId: 'shift',
      stationCode: 'branch',
      attendantId: 'staff',
      attendantName: 'Test staff',
      kind: ShiftAdjustmentKind.generatorFuel,
      reason: 'Test fuel',
      amount: 10,
      createdAt: DateTime.utc(2026),
      nozzleNumber: 1,
      pumpId: a.id,
      pumpName: a.label);
  final restored = ShiftAdjustment.fromJson(adjustment.toJson());
  check(restored.pumpId == a.id && restored.pumpLabel == 'Pump1a');
  check(restored.pumpLabel != renamed.label);
  check(NozzleItem(
              nozzleNumber: 4,
              productName: 'PMS',
              tankCode: 'T1',
              openingReading: 0,
              pricePerLitre: 1)
          .label ==
      'Pump4');
  print('$count named-pump identity and validation checks passed');
}

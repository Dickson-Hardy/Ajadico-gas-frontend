import 'package:shared_preferences/shared_preferences.dart';

enum DeviceMode { personal, station }

/// Presentation preferences only. These never grant account permissions.
class DeviceModePreferences {
  static const modeKey = 'device_mode_v1';
  static const stationKey = 'device_station_id_v1';
  DeviceMode? mode;
  String? stationId;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(modeKey);
    mode = DeviceMode.values.where((m) => m.name == value).firstOrNull;
    stationId = prefs.getString(stationKey);
  }

  Future<void> save(DeviceMode value, {String? stationId}) async {
    final prefs = await SharedPreferences.getInstance();
    // Persist the branch before the mode so a partial write cannot silently
    // make a shared tablet operate at an unrelated branch.
    final branchSaved = stationId == null
        ? await prefs.remove(stationKey)
        : await prefs.setString(stationKey, stationId);
    if (!branchSaved || !await prefs.setString(modeKey, value.name)) {
      throw StateError('Device preference could not be saved');
    }
    mode = value;
    this.stationId = stationId;
  }
}

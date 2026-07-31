import '../../models/Userdata.dart';
import 'church_birthday_celebration_api.dart';
import 'church_birthday_celebration_models.dart';

class ChurchBirthdayCelebrationAvailability {
  ChurchBirthdayCelebrationAvailability({ChurchBirthdayCelebrationApi? api})
      : _api = api ?? ChurchBirthdayCelebrationApi();

  final ChurchBirthdayCelebrationApi _api;

  Future<ChurchBirthdayCapability> check(Userdata user) async {
    if (!user.isVerified) return const ChurchBirthdayCapability(active: false);
    final capability = await _api.fetchCapability(user);
    if (!capability.active) return capability;
    try {
      return (await _api.context(user)).capability;
    } catch (_) {
      return capability.withEligibility(false);
    }
  }
}

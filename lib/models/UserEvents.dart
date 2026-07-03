import 'Userdata.dart';

class UserLoggedInEvent {
  Userdata? user;
  UserLoggedInEvent(this.user);
}

class OnAppStateChanged {
  String state;
  OnAppStateChanged(this.state);
}

class OnAppOffline {
  Map<String, dynamic> items;
  OnAppOffline(this.items);
}

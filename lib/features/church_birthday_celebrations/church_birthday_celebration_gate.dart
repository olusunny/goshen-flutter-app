import 'package:flutter/material.dart';

import '../../models/Userdata.dart';
import 'church_birthday_celebration_availability.dart';
import 'church_birthday_celebration_screen.dart';

class ChurchBirthdayCelebrationGate extends StatefulWidget {
  const ChurchBirthdayCelebrationGate({
    super.key,
    required this.user,
    this.celebrationId,
  });

  final Userdata user;
  final String? celebrationId;

  @override
  State<ChurchBirthdayCelebrationGate> createState() =>
      _ChurchBirthdayCelebrationGateState();
}

class _ChurchBirthdayCelebrationGateState
    extends State<ChurchBirthdayCelebrationGate> {
  late Future<bool> _allowed;

  @override
  void initState() {
    super.initState();
    _allowed = ChurchBirthdayCelebrationAvailability().check(widget.user).then(
          (capability) => capability.canOpenMemberExperience,
        );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _allowed,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.data != true) {
            return Scaffold(
              appBar: AppBar(title: const Text('Birthday Celebrations')),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Birthday celebrations are only available to verified church members.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          return ChurchBirthdayCelebrationScreen(
            user: widget.user,
            celebrationId: widget.celebrationId,
          );
        },
      );
}

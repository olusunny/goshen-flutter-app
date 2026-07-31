import 'dart:io';

import 'package:churchapp_flutter/features/church_birthday_celebrations/church_birthday_celebration_api.dart';
import 'package:churchapp_flutter/features/church_birthday_celebrations/church_birthday_celebration_availability.dart';
import 'package:churchapp_flutter/features/church_birthday_celebrations/church_birthday_celebration_link.dart';
import 'package:churchapp_flutter/features/church_birthday_celebrations/church_birthday_celebration_models.dart';
import 'package:churchapp_flutter/models/Userdata.dart';
import 'package:churchapp_flutter/utils/ApiUrl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final member = Userdata(apiToken: 'member-token', activated: 0);

  test('the birthday hub stays hidden until capability and eligibility pass',
      () {
    const inactive = ChurchBirthdayCapability(active: false);
    const unchecked = ChurchBirthdayCapability(active: true);
    const eligible = ChurchBirthdayCapability(
      active: true,
      eligible: true,
      eligibilityVerified: true,
    );

    expect(inactive.canOpenMemberExperience, isFalse);
    expect(unchecked.canOpenMemberExperience, isFalse);
    expect(eligible.canOpenMemberExperience, isTrue);
  });

  test('inactive, ineligible, and revoked members cannot pass the server gate',
      () async {
    Future<ChurchBirthdayCapability> checkWith(
        Response<dynamic> Function(RequestOptions) respond) async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(respond(options)),
      ));
      return ChurchBirthdayCelebrationAvailability(
        api: ChurchBirthdayCelebrationApi(dio: dio),
      ).check(member);
    }

    final inactive = await checkWith((options) => Response(
          requestOptions: options,
          statusCode: 200,
          data: const {
            'data': {'capabilities': []}
          },
        ));
    expect(inactive.canOpenMemberExperience, isFalse);

    final ineligible = await checkWith((options) => Response(
          requestOptions: options,
          statusCode: 200,
          data: options.path == ApiUrl.ADDON_CAPABILITIES
              ? const {
                  'data': {
                    'capabilities': [
                      {'key': 'church_birthday_celebrations'},
                    ],
                  },
                }
              : const {
                  'status': 'ok',
                  'data': {
                    'capability': 'church_birthday_celebrations',
                    'eligible': false,
                    'preferences': {},
                  },
                },
        ));
    expect(ineligible.canOpenMemberExperience, isFalse);

    final revoked = await checkWith((options) => Response(
          requestOptions: options,
          statusCode: options.path == ApiUrl.ADDON_CAPABILITIES ? 200 : 403,
          data: options.path == ApiUrl.ADDON_CAPABILITIES
              ? const {
                  'data': {
                    'capabilities': [
                      {'key': 'church_birthday_celebrations'},
                    ],
                  },
                }
              : const {'message': 'Membership is no longer eligible.'},
        ));
    expect(revoked.canOpenMemberExperience, isFalse);
  });

  test('detail failures retain closed and purged server state', () async {
    Future<BirthdayApiException> failure(int status, String message) async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(Response(
          requestOptions: options,
          statusCode: status,
          data: {'message': message},
        )),
      ));
      try {
        await ChurchBirthdayCelebrationApi(dio: dio).detail(member, 'cb_1');
      } on BirthdayApiException catch (error) {
        return error;
      }
      throw StateError('Expected a birthday API failure.');
    }

    final closed = await failure(409, 'Celebration is closed.');
    final purged = await failure(410, 'Celebration has been purged.');
    expect(closed.isClosed, isTrue);
    expect(purged.isUnavailable, isTrue);
  });

  test('server interaction state wins over a future device-facing close time',
      () {
    final detail = BirthdayCelebrationDetail.fromJson(const {
      'id': 'cb_1',
      'status': 'published',
      'is_interactive': false,
      'closes_at': '2099-01-01T00:00:00Z',
      'greetings': [],
      'reactions': {},
    });

    expect(detail.isInteractive, isFalse);
  });

  test('server-owned greetings survive restart and expose edit/delete identity',
      () {
    final detail = BirthdayCelebrationDetail.fromJson(const {
      'id': 'cb_1',
      'status': 'published',
      'is_interactive': true,
      'my_greeting_id': 42,
      'greetings': [
        {'id': 42, 'body': 'Happy birthday!', 'is_mine': true},
      ],
      'reactions': {},
    });

    expect(detail.myGreetingId, 42);
    expect(detail.greetings.single.isMine, isTrue);
  });

  test('hub parser deliberately omits private date fields', () {
    final hub = BirthdayCelebrationHub.fromJson(const {
      'today': [
        {
          'id': 'celebration_1',
          'name': 'Ada',
          'birthday_month_day': '07-30',
          'date_of_birth': '1992-07-30',
          'age': 34,
        },
      ],
      'upcoming': [],
    });

    expect(hub.today.single.displayName, 'Ada');
    expect(hub.today.single.dayMonth, '07-30');
    expect(hub.today.single.state, isEmpty);
  });

  test('birthday links and notifications are narrowly routed', () {
    final web = parseChurchBirthdayCelebrationLink(Uri.parse(
      'https://portal.goshenretreat.uk/church-birthday-celebrations?celebration_id=cb_123',
    ));
    final app = parseChurchBirthdayCelebrationLink(Uri.parse(
      'triumphant://church-birthday-celebrations?celebration_id=cb_456',
    ));

    expect(web?.celebrationId, 'cb_123');
    expect(app?.celebrationId, 'cb_456');
    expect(
      parseChurchBirthdayCelebrationLink(
        Uri.parse('https://example.org/church-birthday-celebrations'),
      ),
      isNull,
    );
    expect(
      parseChurchBirthdayCelebrationLink(
        Uri.parse('https://portal.goshenretreat.uk/goshen-retreat'),
      ),
      isNull,
    );
    expect(
      isChurchBirthdayCelebrationNotification(
        const {'action': 'church_birthday_celebrations'},
      ),
      isTrue,
    );
  });

  test('birthday API and Android link declarations match the add-on contract',
      () async {
    expect(ApiUrl.CHURCH_BIRTHDAY_CELEBRATION_CONTEXT, endsWith('/context'));
    expect(ApiUrl.CHURCH_BIRTHDAY_CELEBRATION_PREFERENCES,
        endsWith('/preferences'));
    expect(ApiUrl.churchBirthdayCelebrationCard('cb_123'),
        contains('/card?variant=portrait'));
    expect(ApiUrl.CHURCH_BIRTHDAY_CELEBRATION_CORRECTIONS,
        endsWith('/birthday-correction-requests'));

    final manifest =
        await File('android/app/src/main/AndroidManifest.xml').readAsString();
    expect(manifest, contains('church-birthday-celebrations'));
    expect(manifest, contains('portal.goshenretreat.uk'));
  });

  test('birthday cards use the server PNG variants and correct file type',
      () async {
    final preview = await File(
      'lib/features/church_birthday_celebrations/church_birthday_celebration_detail_screen.dart',
    ).readAsString();
    final files = await File(
      'lib/features/church_birthday_celebrations/church_birthday_card_file_service.dart',
    ).readAsString();

    expect(preview, contains('Image.memory'));
    expect(preview, contains("variant: 'square'"));
    expect(preview, contains("_api.card(widget.user, detail.id)"));
    expect(files, contains(r'birthday-card-$celebrationId.png'));
    expect(files, contains("mimeType: 'image/png'"));
  });

  test('preferences send approved presentation choices and corrections',
      () async {
    Map<String, dynamic>? preferencesBody;
    Map<String, dynamic>? correctionBody;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.endsWith('/preferences')) {
          preferencesBody = Map<String, dynamic>.from(options.data as Map);
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: const {
              'status': 'ok',
              'data': {
                'eligible': true,
                'preferences': {'template_id': 3, 'verse_id': 7},
                'templates': [
                  {'id': 3, 'name': 'Gold', 'version': 1},
                ],
                'verses': [
                  {'id': 7, 'reference': 'Psalm 1:3', 'body': 'Blessed'},
                ],
              },
            },
          ));
        }
        correctionBody = Map<String, dynamic>.from(options.data as Map);
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: const {'status': 'ok', 'data': {}},
        ));
      },
    ));
    final api = ChurchBirthdayCelebrationApi(dio: dio);
    final result = await api.updatePreferences(
      member,
      const BirthdayCelebrationPreferences(
        eligible: true,
        visibilityEnabled: true,
        greetingsEnabled: true,
        useProfilePhoto: true,
        templateId: 3,
        verseId: 7,
      ),
    );
    await api.requestCorrection(member,
        month: 2, day: 29, reason: 'Please fix');

    expect(preferencesBody?['template_id'], 3);
    expect(preferencesBody?['verse_id'], 7);
    expect(result.templates.single.id, 3);
    expect(result.verses.single.id, 7);
    expect(correctionBody, {
      'birthday_month': 2,
      'birthday_day': 29,
      'reason': 'Please fix',
    });
  });

  test('birthday inputs keep the server 280 character boundary', () async {
    final source = await File(
      'lib/features/church_birthday_celebrations/church_birthday_celebration_detail_screen.dart',
    ).readAsString();

    expect(RegExp(r'maxLength: 280').allMatches(source).length,
        greaterThanOrEqualTo(2));
    expect('a' * 280, hasLength(280));
    expect('a' * 281, hasLength(281));
  });

  test('greeting fallback is persisted from and cleared by server ownership',
      () async {
    final source = await File(
      'lib/features/church_birthday_celebrations/church_birthday_celebration_detail_screen.dart',
    ).readAsString();

    expect(source, contains('_applyServerGreeting(detail)'));
    expect(source, contains('_greetingStore.write'));
    expect(source, contains('_greetingStore.clear'));
  });
}

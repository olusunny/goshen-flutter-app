class ApiUrl {
  static const String BASEURL = "https://portal.goshenretreat.uk/";
  static const String TERMS = BASEURL + "content_page/terms";
  static const String PRIVACY = BASEURL + "content_page/privacy";
  static const String ABOUT = BASEURL + "content_page/about";
  static const String CONTENT_PAGE = BASEURL + "content_page/";
  static const String SUBMIT_SUGGESTION = BASEURL + "submit_suggestion";
  static const String SUBMIT_CONTACT = BASEURL + "submit_contact";

  //DO NOT EDIT THE LINES BELOW, ELSE THE APPLICATION WILL MISBEHAVE
  static const String GET_BIBLE = BASEURL + "getBibleVersions";
  static const String DONATION_ACCOUNTS = BASEURL + "donation_accounts";
  static const String GIVING_STRIPE_STATUS =
      BASEURL + "api/giving/stripe/status";
  static const String GIVING_STRIPE_CHECKOUT =
      BASEURL + "api/giving/stripe/checkout";
  static const String GIVING_WALLET_PAY = BASEURL + "api/giving/wallet/pay";
  static const String APP_SPLASH_MEDIA = BASEURL + "api/v1/app/splash-media";
  static const String DYNAMIC_FORMS = BASEURL + "api/dynamic-forms";
  static const String DYNAMIC_FORMS_MANAGEMENT =
      BASEURL + "api/dynamic-forms/management";
  static String dynamicForm(String form) =>
      BASEURL + "api/dynamic-forms/${Uri.encodeComponent(form)}";
  static String dynamicFormSubmit(String form) => "${dynamicForm(form)}/submit";
  static String dynamicFormManagement(String form) =>
      BASEURL +
      "api/dynamic-forms/management/forms/${Uri.encodeComponent(form)}";
  static String dynamicFormManagementSave(String form) =>
      "${dynamicFormManagement(form)}/save";
  static String dynamicFormManagementStatus(String form) =>
      "${dynamicFormManagement(form)}/status";
  static String dynamicFormManagementDelete(String form) =>
      "${dynamicFormManagement(form)}/delete";
  static String dynamicFormManagementSubmissions(String form) =>
      "${dynamicFormManagement(form)}/submissions";
  static const String FUNDRAISING_ACTIVE_CAMPAIGN =
      BASEURL + "api/fundraising/campaigns/active";
  static const String FUNDRAISING_MANAGEMENT_SUMMARY =
      BASEURL + "api/fundraising/management/summary";
  static String fundraisingManagementCampaignStatus(String campaign) =>
      BASEURL +
      "api/fundraising/management/campaigns/${Uri.encodeComponent(campaign)}/status";
  static String fundraisingCampaign(String campaign) =>
      BASEURL + "api/fundraising/campaigns/${Uri.encodeComponent(campaign)}";
  static String fundraisingCampaignContribute(String campaign) =>
      "${fundraisingCampaign(campaign)}/contribute";
  static String fundraisingCampaignCheckout(String campaign) =>
      "${fundraisingCampaign(campaign)}/checkout";
  static const String DISCOVER = BASEURL + "discover";
  static const String CATEGORIES = BASEURL + "fetch_categories";
  static const String GALLERY_IMAGES = BASEURL + "gallery_images";
  static const String LIVESTREAMS = BASEURL + "discoverLivestreams";
  static const String TRENDING = BASEURL + "discoverTrends";
  static const String FETCH_MEDIA = BASEURL + "fetch_media";
  static const String FETCH_BRANCHES = BASEURL + "church_branches";
  static const String FETCH_PASTORS = BASEURL + "church_pastors";
  static const String FETCH_GROUPS = BASEURL + "church_groups";
  static const String MANAGE_GROUPS = BASEURL + "church_groups/manage";
  static const String TRANSPORTATION_ARRANGEMENTS =
      BASEURL + "transportation_arrangements";
  static const String DEVOTIONALS = BASEURL + "devotionals";
  static const String EVENTS = BASEURL + "fetch_events";
  static const String SUBMIT_PRAYER = BASEURL + "submitprayer";
  static const String PRAYERS = BASEURL + "fetch_prayerpoints";
  static const String PRAYER_POINTS = BASEURL + "api/prayer-points";
  static const String CONTROL_HUB_PRAYER_POINTS =
      BASEURL + "api/control-hub/prayer-points";
  static const String CONTROL_HUB_PRAYER_POINTS_SEARCH =
      BASEURL + "api/control-hub/prayer-points/search";
  static String controlHubPrayerPoint(String id) =>
      BASEURL + "api/control-hub/prayer-points/$id";
  static String controlHubPrayerPointStatus(String id) =>
      "${controlHubPrayerPoint(id)}/status";
  static String controlHubPrayerPointDelete(String id) =>
      "${controlHubPrayerPoint(id)}/delete";
  static const String PRAYER_COMMUNITY = BASEURL + "prayer-community";
  static const String PROPHETIC_DECREE =
      BASEURL + "prayer-community/prophetic-decree";
  static const String PRAYER_AI_REWRITE =
      BASEURL + "prayer-community/ai/rewrite";
  static const String PRAYER_AI_SUGGEST =
      BASEURL + "prayer-community/ai/suggestions";
  static const String AI_BIBLE_EXPLAIN =
      BASEURL + "prayer-community/ai/bible-explain";
  static const String AI_BIBLE_SEARCH =
      BASEURL + "prayer-community/ai/bible-search";
  static const String UPDATE_PROFILE_PHOTO =
      BASEURL + "prayer-community/profile/avatar";
  static const String TESTIMONIES = BASEURL + "testimonies";
  static const String TESTIMONIES_STATUS = BASEURL + "testimonies/status";
  static const String COUNSELING = BASEURL + "api/v1/counseling";
  static const String COUNSELING_CASES = COUNSELING + "/cases";
  static String counselingCase(String caseId) => "$COUNSELING_CASES/$caseId";
  static String counselingCaseClose(String caseId) =>
      "${counselingCase(caseId)}/close";
  static String counselingCaseMessages(String caseId) =>
      "${counselingCase(caseId)}/messages";
  static const String GOSHEN_RETREAT_STATUS =
      BASEURL + "api/goshen-retreat/status";
  static const String GOSHEN_RETREAT_EVENTS =
      BASEURL + "api/goshen-retreat/events";
  static String goshenRetreatEvent(String publicId) =>
      BASEURL + "api/goshen-retreat/events/$publicId";
  static const String GOSHEN_RETREAT_BOOKINGS =
      BASEURL + "api/goshen-retreat/bookings";
  static const String GOSHEN_RETREAT_MEMBERS_SEARCH =
      BASEURL + "api/goshen-retreat/members/search";
  static const String GOSHEN_RETREAT_MEMBERS =
      BASEURL + "api/goshen-retreat/members";
  static String goshenRetreatCheckout(String bookingId, String paymentId) =>
      BASEURL +
      "api/goshen-retreat/bookings/$bookingId/payments/$paymentId/checkout";
  static String goshenRetreatWalletPay(String bookingId) =>
      BASEURL + "api/goshen-retreat/bookings/$bookingId/wallet-pay";
  static String goshenRetreatVoucherPay(String bookingId) =>
      BASEURL + "api/goshen-retreat/bookings/$bookingId/voucher-pay";
  static String goshenRetreatCancel(String bookingId) =>
      BASEURL + "api/goshen-retreat/bookings/$bookingId/cancel";
  static String goshenRetreatRegistrationStatus(String eventId) =>
      BASEURL + "api/goshen-retreat/events/$eventId/registration-status";
  static String goshenRetreatManagementSummary(String eventId) =>
      BASEURL + "api/goshen-retreat/events/$eventId/management-summary";
  static String goshenRetreatSetup(String eventId) =>
      BASEURL + "api/goshen-retreat/events/$eventId/setup";
  static String goshenRetreatSetupOverview(String eventId) =>
      BASEURL + "api/goshen-retreat/events/$eventId/setup/overview";
  static String goshenRetreatSetupSchedules(String eventId) =>
      BASEURL + "api/goshen-retreat/events/$eventId/setup/schedules";
  static String goshenRetreatSetupScheduleDelete(
          String eventId, String scheduleId) =>
      BASEURL +
      "api/goshen-retreat/events/$eventId/setup/schedules/$scheduleId/delete";
  static String goshenRetreatSetupTicketTypes(String eventId) =>
      BASEURL + "api/goshen-retreat/events/$eventId/setup/ticket-types";
  static String goshenRetreatSetupTicketTypeDelete(
          String eventId, String ticketTypeId) =>
      BASEURL +
      "api/goshen-retreat/events/$eventId/setup/ticket-types/$ticketTypeId/delete";
  static String goshenRetreatSetupRegistrationFields(String eventId) =>
      BASEURL + "api/goshen-retreat/events/$eventId/setup/registration-fields";
  static String goshenRetreatSetupRegistrationFieldDelete(
          String eventId, String fieldId) =>
      BASEURL +
      "api/goshen-retreat/events/$eventId/setup/registration-fields/$fieldId/delete";
  static String goshenRetreatAccommodationManagement(String eventId) =>
      BASEURL + "api/goshen-retreat/events/$eventId/accommodation-management";
  static const String GOSHEN_ACCOMMODATION_ALLOCATIONS =
      BASEURL + "api/goshen-retreat/accommodation-allocations";
  static String goshenAccommodationAllocation(String allocationId) =>
      BASEURL + "api/goshen-retreat/accommodation-allocations/$allocationId";
  static const String GOSHEN_RETREAT_ME = BASEURL + "api/goshen-retreat/me";
  static const String GOSHEN_RETREAT_VOUCHER_VERIFY =
      BASEURL + "api/goshen-retreat/vouchers/verify";
  static const String GOSHEN_RETREAT_VOUCHERS_GENERATE =
      BASEURL + "api/goshen-retreat/vouchers/generate";
  static const String GOSHEN_RETREAT_VOUCHER_USAGES =
      BASEURL + "api/goshen-retreat/vouchers/usages";
  static const String GOSHEN_RETREAT_REFERRAL_CONVERT =
      BASEURL + "api/goshen-retreat/referrals/convert";
  static const String GOSHEN_WALLET = BASEURL + "api/goshen-wallet";
  static const String GOSHEN_WALLET_GOAL = BASEURL + "api/goshen-wallet/goal";
  static const String GOSHEN_WALLET_GOAL_CANCEL =
      BASEURL + "api/goshen-wallet/goal/cancel";
  static const String GOSHEN_WALLET_GOALS = BASEURL + "api/goshen-wallet/goals";
  static String goshenWalletGoal(String goalId) =>
      BASEURL + "api/goshen-wallet/goals/$goalId";
  static String goshenWalletGoalCancel(String goalId) =>
      BASEURL + "api/goshen-wallet/goals/$goalId/cancel";
  static const String GOSHEN_WALLET_TRANSFER =
      BASEURL + "api/goshen-wallet/transfer";
  static const String GOSHEN_WALLET_SECURITY_RESET_STATUS =
      BASEURL + "api/goshen-wallet/security-reset/status";
  static const String GOSHEN_WALLET_SECURITY_RESET_ACK =
      BASEURL + "api/goshen-wallet/security-reset/acknowledge";
  static const String GOSHEN_WALLET_TOP_UP_CHECKOUT =
      BASEURL + "api/goshen-wallet/top-up/checkout";
  static const String GOSHEN_WALLET_TOP_UP_VOUCHER =
      BASEURL + "api/goshen-wallet/top-up/voucher";
  static const String GOSHEN_WALLET_WITHDRAWALS =
      BASEURL + "api/goshen-wallet/withdrawals";
  static const String GOSHEN_WALLET_WITHDRAWALS_MANAGEMENT =
      BASEURL + "api/goshen-wallet/withdrawals/management";
  static String goshenWalletWithdrawalCancel(String withdrawalId) =>
      BASEURL + "api/goshen-wallet/withdrawals/$withdrawalId/cancel";
  static String goshenWalletWithdrawalManagementStatus(String withdrawalId) =>
      BASEURL + "api/goshen-wallet/withdrawals/$withdrawalId/management-status";
  static const String GOSHEN_WALLET_SAVINGS_PLANS =
      BASEURL + "api/goshen-wallet/savings-plans";
  static String goshenWalletSavingsPlan(String planId) =>
      BASEURL + "api/goshen-wallet/savings-plans/$planId";
  static const String CONTROL_HUB_MESSAGE_OPTIONS =
      BASEURL + "api/control-hub/messages/options";
  static const String CONTROL_HUB_MESSAGE_SEND =
      BASEURL + "api/control-hub/messages/send";
  static const String CONTROL_HUB_MOBILE_USERS =
      BASEURL + "api/control-hub/mobile-users";
  static const String CONTROL_HUB_MOBILE_USERS_SEARCH =
      BASEURL + "api/control-hub/mobile-users/search";
  static String controlHubMobileUser(String userId) =>
      BASEURL + "api/control-hub/mobile-users/$userId";
  static const String CONTROL_HUB_CHURCH_EVENTS =
      BASEURL + "api/control-hub/church-events";
  static const String CONTROL_HUB_CHURCH_EVENTS_SEARCH =
      BASEURL + "api/control-hub/church-events/search";
  static String controlHubChurchEvent(String eventId) =>
      BASEURL + "api/control-hub/church-events/$eventId";
  static String controlHubChurchEventStatus(String eventId) =>
      BASEURL + "api/control-hub/church-events/$eventId/status";
  static String controlHubChurchEventDelete(String eventId) =>
      BASEURL + "api/control-hub/church-events/$eventId/delete";
  static const String CONTROL_HUB_VERSE_OF_DAY =
      BASEURL + "api/control-hub/verse-of-day";
  static const String CONTROL_HUB_VERSE_OF_DAY_SEARCH =
      BASEURL + "api/control-hub/verse-of-day/search";
  static String controlHubVerseOfDay(String verseId) =>
      BASEURL + "api/control-hub/verse-of-day/$verseId";
  static String controlHubVerseOfDayStatus(String verseId) =>
      BASEURL + "api/control-hub/verse-of-day/$verseId/status";
  static String controlHubVerseOfDayDelete(String verseId) =>
      BASEURL + "api/control-hub/verse-of-day/$verseId/delete";
  static const String GOSHEN_EXPERIENCE =
      BASEURL + "api/goshen-retreat/experience";
  static String goshenExperienceSurvey(String surveyId) =>
      BASEURL + "api/goshen-retreat/experience/surveys/$surveyId";
  static String goshenExperienceSurveySettings(String surveyId) =>
      BASEURL + "api/goshen-retreat/experience/surveys/$surveyId/settings";
  static const String GOSHEN_QUIZZES = BASEURL + "api/goshen-quizzes";
  static const String GOSHEN_QUIZ_MANAGEMENT_SUMMARY =
      BASEURL + "api/goshen-quizzes/management/summary";
  static String goshenQuiz(String quizId) =>
      BASEURL + "api/goshen-quizzes/$quizId";
  static String goshenQuizSettings(String quizId) =>
      BASEURL + "api/goshen-quizzes/$quizId/settings";
  static String goshenQuizStart(String quizId) =>
      BASEURL + "api/goshen-quizzes/$quizId/start";
  static String goshenQuizSubmit(String quizId) =>
      BASEURL + "api/goshen-quizzes/$quizId/submit";
  static String goshenQuizWinners(String quizId) =>
      BASEURL + "api/goshen-quizzes/$quizId/winners";
  static String goshenQuizWinnerPrize(String quizId, String winnerId) =>
      BASEURL + "api/goshen-quizzes/$quizId/winners/$winnerId/wallet-prize";
  static String goshenExperienceStats(String eventId) =>
      BASEURL + "api/goshen-retreat/experience/events/$eventId/stats";
  static const String GOSHEN_SCANNER_STATUS =
      BASEURL + "api/goshen-retreat/scanner/status";
  static const String GOSHEN_SCANNER_OPERATORS =
      BASEURL + "api/goshen-retreat/scanner/operators";
  static String goshenScannerOperatorToggle(int userId) =>
      BASEURL + "api/goshen-retreat/scanner/operators/$userId/toggle";
  static const String GOSHEN_SCANNER_LOOKUP =
      BASEURL + "api/goshen-retreat/scanner/lookup";
  static const String GOSHEN_SCANNER_CHECK_IN =
      BASEURL + "api/goshen-retreat/scanner/check-in";
  static const String GOSHEN_SCANNER_SYNC =
      BASEURL + "api/goshen-retreat/scanner/sync";
  static String goshenScannerStats(String eventId) =>
      BASEURL + "api/goshen-retreat/events/$eventId/scanner-stats";
  static String goshenScannerManifest(String eventId) =>
      BASEURL + "api/goshen-retreat/events/$eventId/scanner-manifest";
  static const String INBOX = BASEURL + "fetch_inbox";
  static const String DELETE_INBOX = BASEURL + "delete_inbox";
  static const String HYMNS = BASEURL + "fetch_hymns";
  static const String FETCH_CATEGORIES_MEDIA =
      BASEURL + "fetch_categories_media";
  static const String SEARCH = BASEURL + "search";
  static const String REGISTER = BASEURL + "registerUser";
  static const String LOGIN = BASEURL + "loginUser";
  static const String SYNC_MOBILE_SESSION = BASEURL + "syncMobileSession";
  static const String GOOGLE_AUTH = BASEURL + "googleAuth";
  static const String PHONE_AUTH = BASEURL + "phoneAuth";
  static const String VERIFY_EMAIL = BASEURL + "verifyMobileEmail";
  static const String RESEND_VERIFICATION =
      BASEURL + "resendMobileVerification";
  static const String REQUEST_PASSWORD_RESET = BASEURL + "requestPasswordReset";
  static const String RESET_MOBILE_PASSWORD = BASEURL + "resetMobilePassword";
  static const String RESETPASSWORD = BASEURL + "resetPassword";
  static const String getmediatotallikesandcommentsviews =
      BASEURL + "getmediatotallikesandcommentsviews";
  static const String update_media_total_views =
      BASEURL + "update_media_total_views";
  static const String likeunlikemedia = BASEURL + "likeunlikemedia";
  static const String storeFcmToken = BASEURL + "storefcmtoken";

  static const String fetchUserSettings = BASEURL + "fetch_user_settings";
  static const String updateUserSettings = BASEURL + "update_user_settings";
  static const String updateUserSocialFcmToken =
      BASEURL + "updateUserSocialFcmToken";
  static const String DELETE_ACCOUNT = BASEURL + "deleteaccount";
}

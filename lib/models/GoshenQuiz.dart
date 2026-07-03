class GoshenQuiz {
  const GoshenQuiz({
    required this.id,
    required this.title,
    required this.description,
    required this.startInstructions,
    required this.completionMessage,
    required this.audience,
    required this.eligibleToStart,
    required this.autoGrade,
    required this.trackTiming,
    required this.timerSeconds,
    required this.winnersCount,
    required this.showPrize,
    required this.prizeLabel,
    required this.walletPrizeEnabled,
    required this.showWinnersImmediately,
    required this.celebrationEnabled,
    required this.opensAt,
    required this.closesAt,
    required this.eventName,
    required this.attempt,
    required this.questions,
    required this.winners,
    required this.celebrationMedia,
  });

  final int id;
  final String title;
  final String description;
  final String startInstructions;
  final String completionMessage;
  final String audience;
  final bool eligibleToStart;
  final bool autoGrade;
  final bool trackTiming;
  final int timerSeconds;
  final int winnersCount;
  final bool showPrize;
  final String? prizeLabel;
  final bool walletPrizeEnabled;
  final bool showWinnersImmediately;
  final bool celebrationEnabled;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final String? eventName;
  final GoshenQuizAttempt? attempt;
  final List<GoshenQuizQuestion> questions;
  final List<GoshenQuizWinner> winners;
  final GoshenQuizCelebrationMedia? celebrationMedia;

  bool get hasStarted => attempt != null;
  bool get isSubmitted => attempt?.status == 'submitted';
  bool get isTimedOut => attempt?.status == 'timed_out';
  bool get canAnswer => hasStarted && !isSubmitted && !isTimedOut;
  bool get isNotYetOpen =>
      opensAt != null && opensAt!.toLocal().isAfter(DateTime.now());
  bool get isClosed =>
      closesAt != null && closesAt!.toLocal().isBefore(DateTime.now());
  bool get isOpenNow => !isNotYetOpen && !isClosed;

  factory GoshenQuiz.fromJson(Map<String, dynamic> json) {
    final event = _map(json['event']);
    return GoshenQuiz(
      id: _int(json['id']),
      title: '${json['title'] ?? 'Goshen Quiz'}',
      description: '${json['description'] ?? ''}',
      startInstructions: '${json['start_instructions'] ?? ''}',
      completionMessage: '${json['completion_message'] ?? ''}',
      audience: '${json['audience'] ?? 'all_users'}',
      eligibleToStart: _bool(json['eligible_to_start']),
      autoGrade: _bool(json['auto_grade']),
      trackTiming: _bool(json['track_timing']),
      timerSeconds: _int(json['timer_seconds']),
      winnersCount: _int(json['winners_count']),
      showPrize: _bool(json['show_prize']),
      prizeLabel: _stringOrNull(json['prize_label']),
      walletPrizeEnabled: _bool(json['wallet_prize_enabled']),
      showWinnersImmediately: _bool(json['show_winners_immediately']),
      celebrationEnabled: _bool(json['celebration_enabled']),
      opensAt: _date(json['opens_at']),
      closesAt: _date(json['closes_at']),
      eventName: _stringOrNull(event['name']),
      attempt: json['attempt'] is Map
          ? GoshenQuizAttempt.fromJson(_map(json['attempt']))
          : null,
      questions: _list(json['questions'])
          .map((item) => GoshenQuizQuestion.fromJson(_map(item)))
          .toList(),
      winners: _list(json['winners'])
          .map((item) => GoshenQuizWinner.fromJson(_map(item)))
          .toList(),
      celebrationMedia: json['celebration_media'] is Map
          ? GoshenQuizCelebrationMedia.fromJson(_map(json['celebration_media']))
          : null,
    );
  }
}

class GoshenQuizAttempt {
  const GoshenQuizAttempt({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.dueAt,
    required this.submittedAt,
    required this.timedOutAt,
    required this.score,
    required this.maxScore,
    required this.correctCount,
    required this.answeredCount,
    required this.totalQuestions,
    required this.elapsedSeconds,
  });

  final int id;
  final String status;
  final DateTime? startedAt;
  final DateTime? dueAt;
  final DateTime? submittedAt;
  final DateTime? timedOutAt;
  final double? score;
  final double? maxScore;
  final int correctCount;
  final int answeredCount;
  final int totalQuestions;
  final int? elapsedSeconds;

  factory GoshenQuizAttempt.fromJson(Map<String, dynamic> json) {
    return GoshenQuizAttempt(
      id: _int(json['id']),
      status: '${json['status'] ?? ''}',
      startedAt: _date(json['started_at']),
      dueAt: _date(json['due_at']),
      submittedAt: _date(json['submitted_at']),
      timedOutAt: _date(json['timed_out_at']),
      score: _doubleOrNull(json['score']),
      maxScore: _doubleOrNull(json['max_score']),
      correctCount: _int(json['correct_count']),
      answeredCount: _int(json['answered_count']),
      totalQuestions: _int(json['total_questions']),
      elapsedSeconds: json['elapsed_seconds'] == null
          ? null
          : _int(json['elapsed_seconds']),
    );
  }
}

class GoshenQuizQuestion {
  const GoshenQuizQuestion({
    required this.id,
    required this.prompt,
    required this.type,
    required this.points,
    required this.isRequired,
    required this.sortOrder,
    required this.options,
  });

  final int id;
  final String prompt;
  final String type;
  final double points;
  final bool isRequired;
  final int sortOrder;
  final List<GoshenQuizOption> options;

  bool get isMultiChoice => type == 'multi_choice';
  bool get isText => type == 'short_text';

  factory GoshenQuizQuestion.fromJson(Map<String, dynamic> json) {
    return GoshenQuizQuestion(
      id: _int(json['id']),
      prompt: '${json['prompt'] ?? ''}',
      type: '${json['type'] ?? 'single_choice'}',
      points: _double(json['points']),
      isRequired: _bool(json['is_required']),
      sortOrder: _int(json['sort_order']),
      options: _list(json['options'])
          .map((item) => GoshenQuizOption.fromJson(_map(item)))
          .toList(),
    );
  }
}

class GoshenQuizOption {
  const GoshenQuizOption({required this.label, required this.value});

  final String label;
  final String value;

  factory GoshenQuizOption.fromJson(Map<String, dynamic> json) {
    return GoshenQuizOption(
      label: '${json['label'] ?? ''}',
      value: '${json['value'] ?? ''}',
    );
  }
}

class GoshenQuizWinner {
  const GoshenQuizWinner({
    required this.id,
    required this.rank,
    required this.name,
    required this.score,
    required this.elapsedSeconds,
    required this.prizeLabel,
    required this.walletPrizeAmount,
    required this.walletPrizeCurrency,
    required this.walletPrizeStatus,
  });

  final int id;
  final int rank;
  final String name;
  final double? score;
  final int? elapsedSeconds;
  final String? prizeLabel;
  final double? walletPrizeAmount;
  final String? walletPrizeCurrency;
  final String walletPrizeStatus;

  factory GoshenQuizWinner.fromJson(Map<String, dynamic> json) {
    return GoshenQuizWinner(
      id: _int(json['id']),
      rank: _int(json['rank']),
      name: '${json['name'] ?? 'Winner'}',
      score: _doubleOrNull(json['score']),
      elapsedSeconds: json['elapsed_seconds'] == null
          ? null
          : _int(json['elapsed_seconds']),
      prizeLabel: _stringOrNull(json['prize_label']),
      walletPrizeAmount: _doubleOrNull(json['wallet_prize_amount']),
      walletPrizeCurrency: _stringOrNull(json['wallet_prize_currency']),
      walletPrizeStatus: '${json['wallet_prize_status'] ?? ''}',
    );
  }
}

class GoshenQuizManagementSummary {
  const GoshenQuizManagementSummary({
    required this.totals,
    required this.quizzes,
  });

  final GoshenQuizManagementTotals totals;
  final List<GoshenQuizManagementRow> quizzes;

  factory GoshenQuizManagementSummary.fromJson(Map<String, dynamic> json) {
    return GoshenQuizManagementSummary(
      totals: GoshenQuizManagementTotals.fromJson(_map(json['totals'])),
      quizzes: _list(json['quizzes'])
          .map((item) => GoshenQuizManagementRow.fromJson(_map(item)))
          .toList(),
    );
  }
}

class GoshenQuizManagementTotals {
  const GoshenQuizManagementTotals({
    required this.quizzes,
    required this.activeQuizzes,
    required this.inactiveQuizzes,
    required this.attempts,
    required this.submittedAttempts,
    required this.timedOutAttempts,
    required this.winners,
    required this.pendingWalletPrizes,
    required this.paidWalletPrizes,
  });

  final int quizzes;
  final int activeQuizzes;
  final int inactiveQuizzes;
  final int attempts;
  final int submittedAttempts;
  final int timedOutAttempts;
  final int winners;
  final int pendingWalletPrizes;
  final int paidWalletPrizes;

  factory GoshenQuizManagementTotals.fromJson(Map<String, dynamic> json) {
    return GoshenQuizManagementTotals(
      quizzes: _int(json['quizzes']),
      activeQuizzes: _int(json['active_quizzes']),
      inactiveQuizzes: _int(json['inactive_quizzes']),
      attempts: _int(json['attempts']),
      submittedAttempts: _int(json['submitted_attempts']),
      timedOutAttempts: _int(json['timed_out_attempts']),
      winners: _int(json['winners']),
      pendingWalletPrizes: _int(json['pending_wallet_prizes']),
      paidWalletPrizes: _int(json['paid_wallet_prizes']),
    );
  }
}

class GoshenQuizManagementRow {
  const GoshenQuizManagementRow({
    required this.id,
    required this.title,
    required this.eventName,
    required this.isActive,
    required this.audience,
    required this.questionsCount,
    required this.attemptsCount,
    required this.submittedAttemptsCount,
    required this.timedOutAttemptsCount,
    required this.winnersCount,
    required this.selectedWinnersCount,
    required this.autoSelectWinners,
    required this.showWinnersImmediately,
    required this.walletPrizeEnabled,
    required this.walletPrizeAmount,
    required this.walletPrizeCurrency,
    required this.opensAt,
    required this.closesAt,
    required this.winners,
  });

  final int id;
  final String title;
  final String eventName;
  final bool isActive;
  final String audience;
  final int questionsCount;
  final int attemptsCount;
  final int submittedAttemptsCount;
  final int timedOutAttemptsCount;
  final int winnersCount;
  final int selectedWinnersCount;
  final bool autoSelectWinners;
  final bool showWinnersImmediately;
  final bool walletPrizeEnabled;
  final double? walletPrizeAmount;
  final String? walletPrizeCurrency;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final List<GoshenQuizWinner> winners;

  factory GoshenQuizManagementRow.fromJson(Map<String, dynamic> json) {
    return GoshenQuizManagementRow(
      id: _int(json['id']),
      title: '${json['title'] ?? 'Goshen Quiz'}',
      eventName: '${json['event_name'] ?? ''}',
      isActive: _bool(json['is_active']),
      audience: '${json['audience'] ?? ''}',
      questionsCount: _int(json['questions_count']),
      attemptsCount: _int(json['attempts_count']),
      submittedAttemptsCount: _int(json['submitted_attempts_count']),
      timedOutAttemptsCount: _int(json['timed_out_attempts_count']),
      winnersCount: _int(json['winners_count']),
      selectedWinnersCount: _int(json['selected_winners_count']),
      autoSelectWinners: _bool(json['auto_select_winners']),
      showWinnersImmediately: _bool(json['show_winners_immediately']),
      walletPrizeEnabled: _bool(json['wallet_prize_enabled']),
      walletPrizeAmount: _doubleOrNull(json['wallet_prize_amount']),
      walletPrizeCurrency: _stringOrNull(json['wallet_prize_currency']),
      opensAt: _date(json['opens_at']),
      closesAt: _date(json['closes_at']),
      winners: _list(json['winners'])
          .map((item) => GoshenQuizWinner.fromJson(_map(item)))
          .toList(),
    );
  }

  String get displayTitle => title.trim().isEmpty ? 'Goshen Quiz' : title;
  String get statusLabel => isActive ? 'Active' : 'Inactive';
  String get prizeLabel {
    final amount = walletPrizeAmount;
    final currency = walletPrizeCurrency;
    if (!walletPrizeEnabled || amount == null || currency == null) {
      return 'No wallet prize';
    }
    return '$currency ${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}';
  }
}

class GoshenQuizCelebrationMedia {
  const GoshenQuizCelebrationMedia({
    required this.id,
    required this.name,
    required this.description,
    required this.videoUrl,
    required this.imageUrls,
  });

  final int id;
  final String name;
  final String description;
  final String? videoUrl;
  final List<String> imageUrls;

  factory GoshenQuizCelebrationMedia.fromJson(Map<String, dynamic> json) {
    return GoshenQuizCelebrationMedia(
      id: _int(json['id']),
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      videoUrl: _stringOrNull(json['video_url']),
      imageUrls: _list(json['image_urls'])
          .map((item) => item?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> _list(dynamic value) => value is List ? value : const [];

bool _bool(dynamic value) =>
    value == true || value == 1 || value?.toString() == '1';

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

double? _doubleOrNull(dynamic value) => value == null ? null : _double(value);

DateTime? _date(dynamic value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

String? _stringOrNull(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

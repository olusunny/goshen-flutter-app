import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/LoginScreen.dart';
import '../models/GoshenQuiz.dart';
import '../models/Userdata.dart';
import '../providers/AppStateManager.dart';
import '../service/GoshenQuizApi.dart';
import '../service/MobileSessionService.dart';
import '../wallet_security/wallet_security_guard.dart';

const _primary = Color(0xFF0C2230);
const _gold = Color(0xFFFFB82E);
const _page = Color(0xFFF4F8FA);
const _muted = Color(0xFF64727D);
const _line = Color(0xFFE3EAEE);

class GoshenQuizScreen extends StatefulWidget {
  const GoshenQuizScreen({super.key});

  static const routeName = '/goshen-quiz';

  @override
  State<GoshenQuizScreen> createState() => _GoshenQuizScreenState();
}

class _GoshenQuizScreenState extends State<GoshenQuizScreen>
    with SingleTickerProviderStateMixin {
  final _api = GoshenQuizApi();
  final Map<int, dynamic> _answers = {};
  late final AnimationController _celebrationController;
  late Future<List<GoshenQuiz>> _future;
  Timer? _timer;
  GoshenQuiz? _selected;
  bool _starting = false;
  bool _submitting = false;
  int? _fundingWinnerId;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    final cached = user == null ? null : _api.cachedQuizzes(user);
    _future = user == null
        ? Future.value(const [])
        : (cached == null ? _load() : Future.value(cached));
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final selected = _selected;
      if (mounted &&
          selected?.canAnswer == true &&
          selected?.trackTiming == true) {
        setState(() {});
      }
    });
    if (cached != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _refresh(silent: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _celebrationController.dispose();
    super.dispose();
  }

  Future<List<GoshenQuiz>> _load() async {
    final manager = Provider.of<AppStateManager>(context, listen: false);
    final user = manager.userdata;
    if (user == null) return const [];
    try {
      return await _api.fetchQuizzes(user);
    } on MobileSessionExpiredException catch (error) {
      await manager.unsetUserData();
      if (mounted) _messageText(error.message);
      return const [];
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    final next = _load();
    if (!silent) {
      setState(() => _future = next);
    }
    try {
      final quizzes = await next;
      if (!mounted) return;
      final selected = _selected;
      setState(() {
        _future = Future.value(quizzes);
        if (selected != null) {
          final matches = quizzes.where((quiz) => quiz.id == selected.id);
          _selected = matches.isEmpty ? null : matches.first;
        }
      });
    } catch (_) {
      if (!silent) rethrow;
    }
  }

  Future<void> _startQuiz(Userdata user, GoshenQuiz quiz) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final started = await _api.startQuiz(user, quiz.id);
      if (!mounted) return;
      setState(() {
        _answers.clear();
        _selected = started;
      });
      await _refresh(silent: true);
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _submitQuiz(Userdata user, GoshenQuiz quiz) async {
    if (_submitting) return;
    if (_remaining(quiz) == Duration.zero && quiz.trackTiming) {
      _messageText('The quiz timer has ended.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final submitted = await _api.submitQuiz(user, quiz.id, _cleanAnswers());
      if (!mounted) return;
      setState(() {
        _selected = submitted;
        _answers.clear();
      });
      await _refresh(silent: true);
      _messageText(submitted.completionMessage.isNotEmpty
          ? submitted.completionMessage
          : 'Your quiz has been submitted.');
    } catch (error) {
      _message(error);
      await _refresh(silent: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _fundWinnerPrize(
    Userdata user,
    GoshenQuiz quiz,
    GoshenQuizWinner winner,
  ) async {
    if (_fundingWinnerId != null) return;

    final amount = winner.walletPrizeAmount ?? 0;
    final currency = winner.walletPrizeCurrency ?? 'GBP';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fund winner prize?'),
        content: Text(
          'This will transfer $currency ${amount.toStringAsFixed(2)} from your Goshen wallet to ${winner.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _fundingWinnerId = winner.id);
    try {
      final unlocked = await WalletSecurityGuard.ensureWalletUnlocked(
        context,
        requireFreshVerification: true,
      );
      if (!unlocked || !mounted) return;

      await _api.payWinnerPrize(user, quiz.id, winner.id);
      final refreshed = await _api.fetchQuiz(user, quiz.id);
      if (!mounted) return;
      setState(() => _selected = refreshed);
      _messageText('Winner wallet prize funded.');
    } catch (error) {
      _message(error);
    } finally {
      if (mounted) setState(() => _fundingWinnerId = null);
    }
  }

  Map<int, dynamic> _cleanAnswers() {
    final cleaned = <int, dynamic>{};
    _answers.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        cleaned[key] = value;
      } else if (value is String && value.trim().isNotEmpty) {
        cleaned[key] = value.trim();
      } else if (value != null && value is! List && value is! String) {
        cleaned[key] = value;
      }
    });
    return cleaned;
  }

  Duration? _remaining(GoshenQuiz quiz) {
    final dueAt = quiz.attempt?.dueAt;
    if (dueAt == null) return null;
    final remaining = dueAt.toLocal().difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _message(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    _messageText(text.isEmpty ? 'Unable to complete quiz action.' : text);
  }

  void _messageText(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppStateManager>(context).userdata;

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(title: const Text('Goshen Quiz')),
      body: user == null
          ? _LoginState(
              onLogin: () =>
                  Navigator.pushNamed(context, LoginScreen.routeName))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<GoshenQuiz>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _StateMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Unable to load quizzes',
                      message: snapshot.error
                              ?.toString()
                              .replaceFirst('Exception: ', '') ??
                          'Please check your connection and try again.',
                      actionLabel: 'Retry',
                      onAction: () => _refresh(),
                    );
                  }

                  final selected = _selected;
                  if (selected != null) {
                    return _QuizDetail(
                      quiz: selected,
                      userCanFundPrizes: user.canManageQuizTools,
                      answers: _answers,
                      starting: _starting,
                      submitting: _submitting,
                      remaining: _remaining(selected),
                      celebration: _celebrationController,
                      fundingWinnerId: _fundingWinnerId,
                      onBack: () => setState(() => _selected = null),
                      onStart: () => _startQuiz(user, selected),
                      onSubmit: () => _submitQuiz(user, selected),
                      onFundWinner: (winner) =>
                          _fundWinnerPrize(user, selected, winner),
                      onAnswer: (question, value) {
                        setState(() => _answers[question.id] = value);
                      },
                    );
                  }

                  final quizzes = snapshot.data ?? const [];
                  if (quizzes.isEmpty) {
                    return _StateMessage(
                      icon: Icons.quiz_outlined,
                      title: 'No active quiz yet',
                      message:
                          'When a Goshen quiz opens, it will appear here for eligible app users.',
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      const _QuizHero(),
                      const SizedBox(height: 18),
                      for (final quiz in quizzes) ...[
                        _QuizCard(
                          quiz: quiz,
                          onTap: () => setState(() => _selected = quiz),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _QuizDetail extends StatelessWidget {
  const _QuizDetail({
    required this.quiz,
    required this.userCanFundPrizes,
    required this.answers,
    required this.starting,
    required this.submitting,
    required this.remaining,
    required this.celebration,
    required this.fundingWinnerId,
    required this.onBack,
    required this.onStart,
    required this.onSubmit,
    required this.onFundWinner,
    required this.onAnswer,
  });

  final GoshenQuiz quiz;
  final bool userCanFundPrizes;
  final Map<int, dynamic> answers;
  final bool starting;
  final bool submitting;
  final Duration? remaining;
  final Animation<double> celebration;
  final int? fundingWinnerId;
  final VoidCallback onBack;
  final VoidCallback onStart;
  final VoidCallback onSubmit;
  final ValueChanged<GoshenQuizWinner> onFundWinner;
  final ValueChanged2<GoshenQuizQuestion, dynamic> onAnswer;

  @override
  Widget build(BuildContext context) {
    final expired = remaining == Duration.zero && quiz.canAnswer;
    final canSubmit = quiz.canAnswer && !expired && !submitting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('All quizzes'),
          style: TextButton.styleFrom(alignment: Alignment.centerLeft),
        ),
        const SizedBox(height: 8),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconTile(icon: Icons.quiz_rounded, color: _gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      quiz.title,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              if ((quiz.eventName ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  quiz.eventName!,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
              if (quiz.description.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  quiz.description,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 15,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(icon: Icons.timer_outlined, label: _timerLabel(quiz)),
                  _Pill(
                    icon: Icons.emoji_events_outlined,
                    label:
                        '${quiz.winnersCount} winner${quiz.winnersCount == 1 ? '' : 's'}',
                  ),
                  if (quiz.showPrize && (quiz.prizeLabel ?? '').isNotEmpty)
                    _Pill(icon: Icons.card_giftcard, label: quiz.prizeLabel!),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (quiz.winners.isNotEmpty)
          _WinnersPanel(
            winners: quiz.winners,
            media: quiz.celebrationMedia,
            animation: celebration,
            fundingWinnerId: fundingWinnerId,
            userCanFundPrizes: userCanFundPrizes,
            onFundWinner: onFundWinner,
          ),
        if (quiz.winners.isNotEmpty) const SizedBox(height: 14),
        if (!quiz.hasStarted)
          _StartPanel(
            quiz: quiz,
            starting: starting,
            onStart: onStart,
          )
        else if (quiz.isSubmitted)
          _ResultPanel(quiz: quiz)
        else if (quiz.isTimedOut || expired)
          const _StatePanel(
            icon: Icons.timer_off_outlined,
            title: 'Time is up',
            message:
                'This attempt is locked because the countdown has ended. Please refresh to see the latest status.',
          )
        else ...[
          _CountdownPanel(remaining: remaining, quiz: quiz),
          const SizedBox(height: 14),
          for (final question in quiz.questions) ...[
            _QuestionCard(
              question: question,
              value: answers[question.id],
              onChanged: (value) => onAnswer(question, value),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: canSubmit ? onSubmit : null,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(submitting ? 'Submitting...' : 'Submit quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _primary,
                disabledBackgroundColor: _gold.withOpacity(0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'You can submit now, even if some answers are blank.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  static String _timerLabel(GoshenQuiz quiz) {
    if (!quiz.trackTiming) return 'No timer';
    final minutes = (quiz.timerSeconds / 60).ceil();
    return minutes <= 1 ? '${quiz.timerSeconds}s' : '$minutes min';
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final GoshenQuizQuestion question;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.prompt,
            style: const TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          if (question.isText)
            TextField(
              minLines: 2,
              maxLines: 4,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Type your answer',
                filled: true,
                fillColor: _page,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            )
          else if (question.isMultiChoice)
            for (final option in question.options)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: ((value as List?) ?? const []).contains(option.value),
                onChanged: (checked) {
                  final next = List<String>.from((value as List?) ?? const []);
                  if (checked == true) {
                    if (!next.contains(option.value)) next.add(option.value);
                  } else {
                    next.remove(option.value);
                  }
                  onChanged(next);
                },
                title: Text(option.label),
                controlAffinity: ListTileControlAffinity.leading,
              )
          else
            for (final option in question.options)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: option.value,
                groupValue: value is String ? value : null,
                onChanged: onChanged,
                title: Text(option.label),
              ),
        ],
      ),
    );
  }
}

class _WinnersPanel extends StatelessWidget {
  const _WinnersPanel({
    required this.winners,
    required this.media,
    required this.animation,
    required this.fundingWinnerId,
    required this.userCanFundPrizes,
    required this.onFundWinner,
  });

  final List<GoshenQuizWinner> winners;
  final GoshenQuizCelebrationMedia? media;
  final Animation<double> animation;
  final int? fundingWinnerId;
  final bool userCanFundPrizes;
  final ValueChanged<GoshenQuizWinner> onFundWinner;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFF14513F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CelebrationPainter(animation.value),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Winners',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  if ((media?.name ?? '').isNotEmpty)
                    Text(
                      media!.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 14),
                  for (final winner in winners)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _gold,
                            foregroundColor: _primary,
                            child: Text('${winner.rank}'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  winner.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Score ${winner.score ?? 0} · ${_elapsedLabel(winner.elapsedSeconds)}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          if (userCanFundPrizes && _canFund(winner)) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: fundingWinnerId == null
                                  ? () => onFundWinner(winner)
                                  : null,
                              style: TextButton.styleFrom(
                                backgroundColor: _gold,
                                foregroundColor: _primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: fundingWinnerId == winner.id
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Fund',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canFund(GoshenQuizWinner winner) {
    final amount = winner.walletPrizeAmount ?? 0;
    return winner.walletPrizeStatus == 'pending' && amount > 0;
  }
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter(this.progress);

  final double progress;
  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(7);
    for (var index = 0; index < 34; index++) {
      final x = random.nextDouble() * size.width;
      final drift = sin((progress * pi * 2) + index) * 18;
      final y = ((progress + random.nextDouble()) % 1) * size.height;
      _paint.color = index.isEven ? _gold.withOpacity(0.75) : Colors.white70;
      canvas.drawCircle(
          Offset(x + drift, y), 2 + random.nextDouble() * 4, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CountdownPanel extends StatelessWidget {
  const _CountdownPanel({required this.remaining, required this.quiz});

  final Duration? remaining;
  final GoshenQuiz quiz;

  @override
  Widget build(BuildContext context) {
    final value = remaining;
    if (value == null) {
      return const _StatePanel(
        icon: Icons.timer_outlined,
        title: 'Quiz started',
        message: 'This quiz does not have a countdown timer.',
      );
    }

    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours.toString().padLeft(2, '0');

    return _Panel(
      child: Row(
        children: [
          _IconTile(icon: Icons.timer_outlined, color: _gold),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Time left',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            '$hours:$minutes:$seconds',
            style: const TextStyle(
              color: _primary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.quiz,
    required this.starting,
    required this.onStart,
  });

  final GoshenQuiz quiz;
  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    if (!quiz.eligibleToStart) {
      return const _StatePanel(
        icon: Icons.lock_outline_rounded,
        title: 'Not eligible',
        message:
            'This quiz is limited to the selected Goshen Retreat audience for now.',
      );
    }

    if (quiz.isNotYetOpen) {
      return _StatePanel(
        icon: Icons.schedule_rounded,
        title: 'Quiz opens soon',
        message:
            'This quiz opens on ${_dateTimeLabel(quiz.opensAt!)}. Check back then to start the timer.',
      );
    }

    if (quiz.isClosed) {
      return const _StatePanel(
        icon: Icons.event_busy_rounded,
        title: 'Quiz closed',
        message: 'This quiz is no longer accepting new attempts.',
      );
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to begin?',
            style: TextStyle(
              color: _primary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          if (quiz.startInstructions.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              quiz.startInstructions,
              style: const TextStyle(color: _muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: starting ? null : onStart,
              icon: starting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(starting ? 'Starting...' : 'Start quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.quiz});

  final GoshenQuiz quiz;

  @override
  Widget build(BuildContext context) {
    final attempt = quiz.attempt;
    return _StatePanel(
      icon: Icons.check_circle_outline_rounded,
      title: 'Submitted',
      message: attempt?.score == null
          ? 'Your quiz has been submitted.'
          : 'Score: ${attempt!.score} / ${attempt.maxScore ?? 0}. Winners will appear here when available.',
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.quiz, required this.onTap});

  final GoshenQuiz quiz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: _Panel(
        child: Row(
          children: [
            _IconTile(icon: Icons.quiz_rounded, color: _gold),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quiz.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    quiz.isNotYetOpen
                        ? 'Opens ${_dateTimeLabel(quiz.opensAt!)}'
                        : quiz.isClosed
                            ? 'Closed'
                            : quiz.isSubmitted
                                ? 'Submitted'
                                : quiz.hasStarted
                                    ? 'Continue quiz'
                                    : 'Open quiz',
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _QuizHero extends StatelessWidget {
  const _QuizHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFF14513F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          _IconTile(icon: Icons.emoji_events_outlined, color: _gold),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Join active Goshen quizzes, beat the clock, and watch winners appear here.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.3,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(icon: icon, color: _gold),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _primary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: _muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        _StatePanel(icon: icon, title: title, message: message),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LoginState extends StatelessWidget {
  const _LoginState({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        _StatePanel(
          icon: Icons.lock_outline_rounded,
          title: 'Sign in to play',
          message:
              'Goshen quizzes are available to signed-in app users and eligible checked-in attendees.',
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: onLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Sign in'),
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _page,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _elapsedLabel(int? seconds) {
  if (seconds == null) return 'time not recorded';
  final minutes = seconds ~/ 60;
  final rest = seconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

String _dateTimeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} $hour:$minute';
}

typedef ValueChanged2<A, B> = void Function(A first, B second);

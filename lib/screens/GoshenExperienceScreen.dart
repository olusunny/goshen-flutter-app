import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/GoshenExperience.dart';
import '../models/Userdata.dart';
import '../prayers/voice_recording_dialog.dart';
import '../providers/AppStateManager.dart';
import '../service/GoshenExperienceApi.dart';

class GoshenExperienceScreen extends StatefulWidget {
  const GoshenExperienceScreen({super.key});

  static const routeName = '/goshen-experience';

  @override
  State<GoshenExperienceScreen> createState() => _GoshenExperienceScreenState();
}

class _GoshenExperienceScreenState extends State<GoshenExperienceScreen> {
  final _api = GoshenExperienceApi();
  late Future<List<GoshenExperienceSurvey>> _future;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    final cached = _api.cachedSurveys(user);
    _future = cached == null ? _load() : Future.value(cached);
    if (cached != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _refresh(silent: true));
    }
  }

  Future<List<GoshenExperienceSurvey>> _load() {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    return _api.fetchSurveys(user);
  }

  Future<void> _refresh({bool silent = false}) async {
    final next = _load();
    if (!silent) {
      setState(() {
        _future = next;
      });
    }
    try {
      final surveys = await next;
      if (mounted && silent) {
        setState(() {
          _future = Future.value(surveys);
        });
      }
    } catch (_) {
      if (!silent) rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _GoshenExperiencePalette.of(context);
    final user = Provider.of<AppStateManager>(context).userdata;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Goshen Experience')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<GoshenExperienceSurvey>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _MessageState(
                colors: colors,
                icon: Icons.cloud_off_rounded,
                title: 'Unable to load Goshen Experience',
                message: 'Please check your connection and try again.',
                actionLabel: 'Retry',
                onAction: () => _refresh(),
              );
            }

            final surveys = snapshot.data ?? const [];
            if (surveys.isEmpty) {
              return _MessageState(
                colors: colors,
                icon: Icons.auto_awesome_rounded,
                title: 'No active survey yet',
                message:
                    'When Goshen Experience feedback opens, it will appear here.',
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                _HeroCard(colors: colors),
                const SizedBox(height: 18),
                if (user == null)
                  _AccessCard(
                    colors: colors,
                    title: 'Sign in to share',
                    message:
                        'Please sign in to view the Goshen Experience surveys available to your account.',
                  ),
                for (final survey in surveys) ...[
                  _SurveyCard(
                    colors: colors,
                    survey: survey,
                    userSignedIn: user != null,
                    currentUser: user,
                    onSubmitted: _refresh,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SurveyCard extends StatefulWidget {
  const _SurveyCard({
    required this.colors,
    required this.survey,
    required this.userSignedIn,
    required this.currentUser,
    required this.onSubmitted,
  });

  final _GoshenExperiencePalette colors;
  final GoshenExperienceSurvey survey;
  final bool userSignedIn;
  final Userdata? currentUser;
  final VoidCallback onSubmitted;

  @override
  State<_SurveyCard> createState() => _SurveyCardState();
}

class _SurveyCardState extends State<_SurveyCard> {
  final _storyController = TextEditingController();
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, dynamic> _answers = {};
  bool _submitting = false;
  String? _audioPath;
  int? _audioDurationSeconds;

  @override
  void dispose() {
    _storyController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final survey = widget.survey;
    final colors = widget.colors;
    final canSubmit = widget.userSignedIn &&
        survey.eligibleToSubmit &&
        !survey.alreadySubmitted &&
        !_submitting;
    final visibleQuestions = _visibleQuestions();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.24 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.auto_stories_rounded, color: colors.gold),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      survey.title,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    if ((survey.eventName ?? '').isNotEmpty)
                      Text(
                        survey.eventName!,
                        style: TextStyle(
                          color: colors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (survey.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              survey.description,
              style: TextStyle(
                color: colors.muted,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (survey.alreadySubmitted)
            _AccessCard(
              colors: colors,
              title: 'Already submitted',
              message:
                  'Thank you for sharing your Goshen Experience. Your response has been received.',
            )
          else if (!widget.userSignedIn)
            _AccessCard(
              colors: colors,
              title: 'Login required',
              message: survey.allowAllAuthenticatedUsers
                  ? 'Please sign in to share this survey response.'
                  : 'Please sign in with the account used for your Goshen registration before sharing your experience.',
            )
          else if (!survey.eligibleToSubmit)
            _AccessCard(
              colors: colors,
              title: survey.allowAllAuthenticatedUsers
                  ? 'Not available'
                  : 'For checked-in attendees',
              message: survey.allowAllAuthenticatedUsers
                  ? 'This survey is not available to your account right now.'
                  : 'This page opens after you have checked in for the retreat. We look forward to seeing you at Goshen.',
            )
          else ...[
            _InputBox(
              colors: colors,
              controller: _storyController,
              hint: 'Share what God did for you at Goshen...',
              maxLines: 5,
            ),
            const SizedBox(height: 14),
            for (final question in visibleQuestions) ...[
              _QuestionInput(
                colors: colors,
                question: question,
                controller: _controllerFor(question.id),
                reasonController: _controllerFor(-question.id),
                selected: _answers[question.id],
                onChanged: (value) => _setQuestionAnswer(question.id, value),
              ),
              const SizedBox(height: 12),
            ],
            if (survey.allowAudio)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _submitting ? null : _recordAudio,
                    icon: const Icon(Icons.mic_rounded),
                    label: Text(_audioPath == null
                        ? 'Record audio'
                        : 'Re-record audio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.deep,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                    ),
                  ),
                  if (_audioPath != null)
                    Chip(
                      label: Text('${_audioDurationSeconds ?? 0}s attached'),
                      avatar: const Icon(Icons.graphic_eq_rounded, size: 18),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canSubmit ? _submit : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label:
                    Text(_submitting ? 'Submitting...' : 'Submit experience'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.gold,
                  foregroundColor: const Color(0xFF0C2230),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
          if (widget.currentUser?.canViewGoshenExperienceStats == true &&
              ((widget.survey.eventPublicId ?? '').trim().isNotEmpty ||
                  widget.survey.eventId != null)) ...[
            const SizedBox(height: 16),
            _SurveyStatsCard(
              colors: colors,
              user: widget.currentUser!,
              eventId: (widget.survey.eventPublicId ?? '').trim().isNotEmpty
                  ? widget.survey.eventPublicId!
                  : '${widget.survey.eventId!}',
            ),
          ],
        ],
      ),
    );
  }

  TextEditingController _controllerFor(int questionId) {
    return _controllers.putIfAbsent(questionId, TextEditingController.new);
  }

  Future<void> _recordAudio() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VoiceRecordingDialog(
        maxDuration: 300,
        title: 'Goshen Experience',
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _audioPath = result['path']?.toString();
      _audioDurationSeconds = int.tryParse('${result['duration']}') ?? 0;
    });
  }

  Future<void> _submit() async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      final answers = <String, dynamic>{};
      for (final question in _visibleQuestions()) {
        if (question.type == 'choice' ||
            question.type == 'multi_choice' ||
            question.type == 'image_choice' ||
            question.type == 'color_choice') {
          final answer = _answers[question.id];
          if (answer is List && answer.isNotEmpty) {
            answers['${question.id}'] = answer;
          } else if (answer is String && answer.isNotEmpty) {
            answers['${question.id}'] = answer;
          }
        } else if (question.type == 'rating') {
          final answer = _answers[question.id];
          if (answer is Map && answer['rating'] != null) {
            final reason = '${answer['reason'] ?? ''}'.trim();
            if (question.requireRatingReason && reason.isEmpty) {
              throw Exception(
                'Please add the reason for your rating: ${question.prompt}',
              );
            }
            answers['${question.id}'] = answer;
          }
        } else {
          final value = _controllerFor(question.id).text.trim();
          if (value.isNotEmpty) answers['${question.id}'] = value;
        }
      }

      final message = await GoshenExperienceApi().submitSurvey(
        user: user,
        survey: widget.survey,
        story: _storyController.text.trim(),
        answers: answers,
        audioPath: _audioPath,
        audioDurationSeconds: _audioDurationSeconds,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      widget.onSubmitted();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _setQuestionAnswer(int questionId, dynamic value) {
    setState(() {
      final ratingMapWithoutRating = value is Map &&
          value.containsKey('rating') &&
          value['rating'] == null;
      final empty = value == null ||
          value == '' ||
          (value is List && value.isEmpty) ||
          (value is Map && value.values.every((item) => '$item'.isEmpty)) ||
          ratingMapWithoutRating;
      if (empty) {
        _answers.remove(questionId);
      } else {
        _answers[questionId] = value;
      }
    });
  }

  List<GoshenExperienceQuestion> _visibleQuestions() {
    return widget.survey.questions
        .where((question) => _questionIsVisible(question))
        .toList();
  }

  bool _questionIsVisible(GoshenExperienceQuestion question) {
    final condition = question.conditionalLogic;
    if (!condition.enabled || condition.questionId <= 0) return true;

    final values = _comparisonValues(_answers[condition.questionId]);
    final expected = condition.value.trim().toLowerCase();
    final answered = values.any((value) => value.trim().isNotEmpty);

    switch (condition.operator) {
      case 'answered':
        return answered;
      case 'not_answered':
        return !answered;
      case 'not_equals':
        return !values.any((value) => value.trim().toLowerCase() == expected);
      case 'contains':
        return values.any((value) => value.toLowerCase().contains(expected));
      case 'not_contains':
        return !values.any((value) => value.toLowerCase().contains(expected));
      case 'equals':
      default:
        return values.any((value) => value.trim().toLowerCase() == expected);
    }
  }

  List<String> _comparisonValues(dynamic raw) {
    if (raw is Map && raw.containsKey('rating')) {
      return ['${raw['rating']}'];
    }
    if (raw is List) {
      return raw.map((item) => '$item').toList();
    }
    if (raw == null) return const [''];
    return ['$raw'];
  }
}

class _SurveyStatsCard extends StatefulWidget {
  const _SurveyStatsCard({
    required this.colors,
    required this.user,
    required this.eventId,
  });

  final _GoshenExperiencePalette colors;
  final Userdata user;
  final String eventId;

  @override
  State<_SurveyStatsCard> createState() => _SurveyStatsCardState();
}

class _SurveyStatsCardState extends State<_SurveyStatsCard> {
  late Future<GoshenExperienceStats> _future;

  @override
  void initState() {
    super.initState();
    _future = GoshenExperienceApi().fetchStats(
      user: widget.user,
      eventId: widget.eventId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return FutureBuilder<GoshenExperienceStats>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _StatsShell(
            colors: colors,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _StatsShell(
            colors: colors,
            child: Text(
              'Stats are not available right now.',
              style:
                  TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
            ),
          );
        }

        final stats = snapshot.data!;
        return _StatsShell(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights_rounded, color: colors.gold),
                  const SizedBox(width: 8),
                  Text(
                    'Experience stats',
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricPill(
                      colors: colors,
                      label: 'Checked in',
                      value: '${stats.checkedInAttendees}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricPill(
                      colors: colors,
                      label: 'Responses',
                      value: '${stats.responses}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricPill(
                      colors: colors,
                      label: 'Rate',
                      value: '${stats.responseRate.toStringAsFixed(1)}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _BreakdownBars(
                colors: colors,
                title: 'Gender',
                values: stats.byGender,
              ),
              const SizedBox(height: 12),
              _BreakdownBars(
                colors: colors,
                title: 'Country',
                values: stats.byCountry,
              ),
              if (stats.byState.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BreakdownBars(
                  colors: colors,
                  title: 'State / province',
                  values: stats.byState,
                ),
              ],
              if (stats.byAgeGroup.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BreakdownBars(
                  colors: colors,
                  title: 'Age group',
                  values: stats.byAgeGroup,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatsShell extends StatelessWidget {
  const _StatsShell({required this.colors, required this.child});

  final _GoshenExperiencePalette colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.colors,
    required this.label,
    required this.value,
  });

  final _GoshenExperiencePalette colors;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.muted, fontSize: 11)),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownBars extends StatelessWidget {
  const _BreakdownBars({
    required this.colors,
    required this.title,
    required this.values,
  });

  final _GoshenExperiencePalette colors;
  final String title;
  final Map<String, int> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final total = values.values.fold<int>(0, (sum, item) => sum + item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final entry in values.entries) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ),
              Text(
                '${entry.value}',
                style:
                    TextStyle(color: colors.text, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: total == 0 ? 0 : entry.value / total,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation(colors.gold),
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _QuestionInput extends StatelessWidget {
  const _QuestionInput({
    required this.colors,
    required this.question,
    required this.controller,
    required this.reasonController,
    required this.selected,
    required this.onChanged,
  });

  final _GoshenExperiencePalette colors;
  final GoshenExperienceQuestion question;
  final TextEditingController controller;
  final TextEditingController reasonController;
  final dynamic selected;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    if (question.type == 'choice' && question.options.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuestionLabel(colors: colors, question: question),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in question.options)
                ChoiceChip(
                  selected: selected == option.value,
                  label: Text(option.label),
                  onSelected: (_) => onChanged(option.value),
                ),
            ],
          ),
        ],
      );
    }

    if (question.type == 'multi_choice' && question.options.isNotEmpty) {
      final selectedValues = selected is List
          ? (selected as List).map((item) => '$item').toSet()
          : <String>{};

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuestionLabel(colors: colors, question: question),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in question.options)
                FilterChip(
                  selected: selectedValues.contains(option.value),
                  label: Text(option.label),
                  onSelected: (checked) {
                    final next = {...selectedValues};
                    if (checked) {
                      next.add(option.value);
                    } else {
                      next.remove(option.value);
                    }
                    onChanged(next.toList());
                  },
                ),
            ],
          ),
        ],
      );
    }

    if (question.type == 'image_choice' && question.options.isNotEmpty) {
      final selectedValue = '${selected ?? ''}';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuestionLabel(colors: colors, question: question),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in question.options)
                _ImageOptionTile(
                  colors: colors,
                  option: option,
                  selected: selectedValue == option.value,
                  onTap: () => onChanged(option.value),
                ),
            ],
          ),
        ],
      );
    }

    if (question.type == 'color_choice' && question.options.isNotEmpty) {
      final selectedValue = '${selected ?? ''}';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuestionLabel(colors: colors, question: question),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in question.options)
                _ColorOptionChip(
                  colors: colors,
                  option: option,
                  selected: selectedValue == option.value,
                  onTap: () => onChanged(option.value),
                ),
            ],
          ),
        ],
      );
    }

    if (question.type == 'rating') {
      final map = selected is Map
          ? Map<String, dynamic>.from(selected)
          : <String, dynamic>{};
      final rating = int.tryParse('${map['rating'] ?? 0}') ?? 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuestionLabel(colors: colors, question: question),
          const SizedBox(height: 8),
          Wrap(
            children: [
              for (var index = 1; index <= question.ratingMax; index++)
                IconButton(
                  tooltip: '$index star${index == 1 ? '' : 's'}',
                  onPressed: () {
                    onChanged({
                      'rating': index,
                      'reason': reasonController.text.trim(),
                    });
                  },
                  icon: Icon(
                    index <= rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: colors.gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _InputBox(
            colors: colors,
            controller: reasonController,
            hint: question.ratingReasonLabel,
            maxLines: 2,
            onChanged: (value) {
              onChanged({
                'rating': rating == 0 ? null : rating,
                'reason': value.trim(),
              });
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuestionLabel(colors: colors, question: question),
        const SizedBox(height: 8),
        _InputBox(
          colors: colors,
          controller: controller,
          hint: 'Your answer',
          maxLines: question.type == 'text' ? 1 : 3,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _QuestionLabel extends StatelessWidget {
  const _QuestionLabel({required this.colors, required this.question});

  final _GoshenExperiencePalette colors;
  final GoshenExperienceQuestion question;

  @override
  Widget build(BuildContext context) {
    return Text(
      question.isRequired ? '${question.prompt} *' : question.prompt,
      style: TextStyle(
        color: colors.text,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
    );
  }
}

class _ImageOptionTile extends StatelessWidget {
  const _ImageOptionTile({
    required this.colors,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _GoshenExperiencePalette colors;
  final GoshenExperienceQuestionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (option.imageUrl ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 142,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                selected ? colors.gold.withValues(alpha: 0.16) : colors.input,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? colors.gold : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    color: colors.card,
                    child: imageUrl.isEmpty
                        ? Icon(
                            Icons.image_not_supported_rounded,
                            color: colors.muted,
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.gold,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Icon(
                              Icons.broken_image_rounded,
                              color: colors.muted,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: colors.gold,
                      size: 18,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorOptionChip extends StatelessWidget {
  const _ColorOptionChip({
    required this.colors,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _GoshenExperiencePalette colors;
  final GoshenExperienceQuestionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = _colorFromHex(option.colorHex);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.gold.withValues(alpha: 0.15) : colors.input,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.gold : colors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_rounded, color: colors.gold, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.colors,
    required this.controller,
    required this.hint,
    required this.maxLines,
    this.onChanged,
  });

  final _GoshenExperiencePalette colors;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: colors.input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.gold, width: 1.4),
        ),
      ),
    );
  }
}

Color _colorFromHex(String? value) {
  final clean = (value ?? '').replaceFirst('#', '').trim();
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean)) {
    return Colors.white;
  }

  return Color(int.parse('FF$clean', radix: 16));
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.colors});

  final _GoshenExperiencePalette colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.deep, const Color(0xFF0E4C3F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.celebration_rounded,
                color: Color(0xFFFFC857), size: 30),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share your Goshen Experience',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 23,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tell us what God did, leave feedback, or record a short reflection after check-in.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({
    required this.colors,
    required this.title,
    required this.message,
  });

  final _GoshenExperiencePalette colors;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(color: colors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.colors,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final _GoshenExperiencePalette colors;
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 64, color: colors.gold),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.muted, height: 1.45),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}

class _GoshenExperiencePalette {
  const _GoshenExperiencePalette({
    required this.isDark,
    required this.background,
    required this.card,
    required this.input,
    required this.text,
    required this.muted,
    required this.border,
    required this.deep,
    required this.gold,
  });

  final bool isDark;
  final Color background;
  final Color card;
  final Color input;
  final Color text;
  final Color muted;
  final Color border;
  final Color deep;
  final Color gold;

  static _GoshenExperiencePalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _GoshenExperiencePalette(
      isDark: isDark,
      background: isDark ? const Color(0xFF06151D) : const Color(0xFFF4F9FB),
      card: isDark ? const Color(0xFF0C2633) : Colors.white,
      input: isDark ? const Color(0xFF0A202B) : const Color(0xFFF4F8FA),
      text: isDark ? Colors.white : const Color(0xFF0C2230),
      muted: isDark ? Colors.white70 : const Color(0xFF667085),
      border: isDark ? Colors.white12 : const Color(0xFFE4EBEF),
      deep: const Color(0xFF0C2230),
      gold: const Color(0xFFFFB72B),
    );
  }
}

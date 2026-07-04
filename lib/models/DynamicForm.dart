class DynamicForm {
  const DynamicForm({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.isActive,
    required this.isOpen,
    required this.visibility,
    required this.requiresLogin,
    required this.oneSubmissionPerUser,
    required this.maxSubmissions,
    required this.submitButtonLabel,
    required this.thankYouMessage,
    required this.payment,
    required this.fields,
    required this.alreadySubmitted,
    required this.submissionsCount,
    this.opensAt,
    this.closesAt,
  });

  final int id;
  final String title;
  final String slug;
  final String description;
  final bool isActive;
  final bool isOpen;
  final String visibility;
  final bool requiresLogin;
  final bool oneSubmissionPerUser;
  final int? maxSubmissions;
  final String submitButtonLabel;
  final String thankYouMessage;
  final DynamicFormPayment payment;
  final List<DynamicFormField> fields;
  final bool alreadySubmitted;
  final int submissionsCount;
  final DateTime? opensAt;
  final DateTime? closesAt;

  String get identifier => slug.trim().isNotEmpty ? slug.trim() : '$id';
  bool get requiresPayment => payment.required && payment.amount > 0;

  factory DynamicForm.fromJson(Map<String, dynamic> json) {
    return DynamicForm(
      id: _readInt(json['id']),
      title: '${json['title'] ?? 'Form'}',
      slug: '${json['slug'] ?? ''}',
      description: '${json['description'] ?? ''}',
      isActive: _readBool(json['is_active'] ?? json['isOpen']),
      isOpen: _readBool(json['is_open']),
      visibility: '${json['visibility'] ?? 'public'}',
      requiresLogin: _readBool(json['requires_login']),
      oneSubmissionPerUser: _readBool(json['one_submission_per_user']),
      maxSubmissions: _readNullableInt(json['max_submissions']),
      submitButtonLabel: '${json['submit_button_label'] ?? 'Submit'}',
      thankYouMessage: '${json['thank_you_message'] ?? ''}',
      payment: DynamicFormPayment.fromJson(json['payment']),
      fields: _readList(json['fields'])
          .map((item) => DynamicFormField.fromJson(item))
          .toList(),
      alreadySubmitted: _readBool(json['already_submitted']),
      submissionsCount: _readInt(json['submissions_count']),
      opensAt: _readDate(json['opens_at']),
      closesAt: _readDate(json['closes_at']),
    );
  }
}

class DynamicFormPayment {
  const DynamicFormPayment({
    required this.type,
    required this.required,
    required this.amount,
    required this.currency,
    required this.allowStripe,
    required this.allowWallet,
  });

  final String type;
  final bool required;
  final double amount;
  final String currency;
  final bool allowStripe;
  final bool allowWallet;

  factory DynamicFormPayment.fromJson(dynamic value) {
    if (value is! Map) {
      return const DynamicFormPayment(
        type: 'free',
        required: false,
        amount: 0,
        currency: 'GBP',
        allowStripe: true,
        allowWallet: true,
      );
    }

    final json = Map<String, dynamic>.from(value);
    return DynamicFormPayment(
      type: '${json['type'] ?? 'free'}',
      required: _readBool(json['required']),
      amount: _readDouble(json['amount']),
      currency: '${json['currency'] ?? 'GBP'}'.toUpperCase(),
      allowStripe: _readBool(json['allow_stripe']),
      allowWallet: _readBool(json['allow_wallet']),
    );
  }
}

class DynamicFormField {
  const DynamicFormField({
    required this.id,
    required this.key,
    required this.label,
    required this.type,
    required this.placeholder,
    required this.helpText,
    required this.options,
    required this.settings,
    required this.conditionalLogic,
    required this.isRequired,
    required this.sortOrder,
  });

  final int id;
  final String key;
  final String label;
  final String type;
  final String placeholder;
  final String helpText;
  final List<DynamicFormOption> options;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> conditionalLogic;
  final bool isRequired;
  final int sortOrder;

  bool get isTextLike => const {
        'text',
        'textarea',
        'email',
        'phone',
        'number',
        'date',
      }.contains(type);

  bool get isChoice => const {
        'choice',
        'multi_choice',
        'image_choice',
        'color_choice',
      }.contains(type);

  List<String> get allowedFileExtensions {
    final raw = settings['allowed_extensions'];
    final items = raw is List ? raw : [raw];
    return items
        .expand((item) => '$item'.split(RegExp(r'[\s,;|]+')))
        .map((item) => item.trim().toLowerCase().replaceFirst('.', ''))
        .where(
            (item) => item.isNotEmpty && RegExp(r'^[a-z0-9]+$').hasMatch(item))
        .toSet()
        .toList();
  }

  int get maxFileSizeKb {
    final value = settings['max_kb'];
    final parsed =
        value is num ? value.toInt() : (int.tryParse('$value') ?? 10240);
    return parsed.clamp(1, 51200);
  }

  factory DynamicFormField.fromJson(Map<String, dynamic> json) {
    return DynamicFormField(
      id: _readInt(json['id']),
      key: '${json['key'] ?? ''}',
      label: '${json['label'] ?? 'Field'}',
      type: '${json['type'] ?? 'text'}',
      placeholder: '${json['placeholder'] ?? ''}',
      helpText: '${json['help_text'] ?? ''}',
      options: _readRawList(json['options'])
          .map((item) => DynamicFormOption.fromDynamic(item))
          .where((option) => option.value.isNotEmpty)
          .toList(),
      settings: _readMap(json['settings']),
      conditionalLogic: _readMap(json['conditional_logic']),
      isRequired: _readBool(json['is_required']),
      sortOrder: _readInt(json['sort_order']),
    );
  }
}

class DynamicFormOption {
  const DynamicFormOption({
    required this.label,
    required this.value,
    required this.imageUrl,
    required this.colorHex,
  });

  final String label;
  final String value;
  final String imageUrl;
  final String colorHex;

  factory DynamicFormOption.fromDynamic(dynamic value) {
    if (value is Map) {
      final json = Map<String, dynamic>.from(value);
      final label = '${json['label'] ?? json['value'] ?? ''}'.trim();
      final optionValue = '${json['value'] ?? label}'.trim();
      return DynamicFormOption(
        label: label.isEmpty ? optionValue : label,
        value: optionValue,
        imageUrl: '${json['image_url'] ?? json['url'] ?? ''}'.trim(),
        colorHex: _normalizeColor('${json['color_hex'] ?? ''}'),
      );
    }

    final label = '${value ?? ''}'.trim();
    return DynamicFormOption(
      label: label,
      value: label,
      imageUrl: '',
      colorHex: '#ffffff',
    );
  }
}

class DynamicFormSubmitResult {
  const DynamicFormSubmitResult({
    required this.message,
    required this.mode,
    required this.checkoutUrl,
    required this.reference,
  });

  final String message;
  final String mode;
  final String checkoutUrl;
  final String reference;

  bool get hasCheckout => checkoutUrl.trim().isNotEmpty;

  factory DynamicFormSubmitResult.fromJson(Map<String, dynamic> json) {
    final checkout = _readMap(json['checkout']);
    final submission = _readMap(json['submission']);
    return DynamicFormSubmitResult(
      message:
          '${json['message'] ?? 'Thank you. Your form has been submitted.'}',
      mode: '${json['mode'] ?? ''}',
      checkoutUrl: '${checkout['checkout_url'] ?? ''}'.trim(),
      reference: '${submission['reference'] ?? ''}'.trim(),
    );
  }
}

class DynamicFormSubmissionRecord {
  const DynamicFormSubmissionRecord({
    required this.id,
    required this.reference,
    required this.formTitle,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    required this.paymentStatus,
    required this.paymentProvider,
    required this.amount,
    required this.currency,
    required this.answers,
    this.submittedAt,
    this.paidAt,
  });

  final int id;
  final String reference;
  final String formTitle;
  final String name;
  final String email;
  final String phone;
  final String status;
  final String paymentStatus;
  final String paymentProvider;
  final double? amount;
  final String currency;
  final Map<String, DynamicFormSubmissionAnswer> answers;
  final DateTime? submittedAt;
  final DateTime? paidAt;

  factory DynamicFormSubmissionRecord.fromJson(Map<String, dynamic> json) {
    final answers = _readMap(json['answers']).map(
      (key, value) => MapEntry(
        key,
        DynamicFormSubmissionAnswer.fromJson(_readMap(value)),
      ),
    );

    return DynamicFormSubmissionRecord(
      id: _readInt(json['id']),
      reference: '${json['reference'] ?? ''}',
      formTitle: '${json['form_title'] ?? ''}',
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      status: '${json['status'] ?? ''}',
      paymentStatus: '${json['payment_status'] ?? ''}',
      paymentProvider: '${json['payment_provider'] ?? ''}',
      amount: json['amount'] == null ? null : _readDouble(json['amount']),
      currency: '${json['currency'] ?? ''}'.toUpperCase(),
      answers: answers,
      submittedAt: _readDate(json['submitted_at']),
      paidAt: _readDate(json['paid_at']),
    );
  }
}

class DynamicFormSubmissionAnswer {
  const DynamicFormSubmissionAnswer({
    required this.label,
    required this.type,
    required this.answer,
  });

  final String label;
  final String type;
  final dynamic answer;

  String get displayValue {
    if (answer is Map) {
      final map = Map<String, dynamic>.from(answer as Map);
      final fileName = '${map['original_name'] ?? ''}'.trim();
      if (fileName.isNotEmpty) return fileName;
      final label = '${map['label'] ?? ''}'.trim();
      if (label.isNotEmpty) return label;
      final value = '${map['value'] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    if (answer is List) {
      return (answer as List).map((item) => '$item').join(', ');
    }
    return '${answer ?? ''}'.trim();
  }

  String get downloadUrl {
    if (answer is! Map) return '';
    return '${(answer as Map)['download_url'] ?? ''}'.trim();
  }

  factory DynamicFormSubmissionAnswer.fromJson(Map<String, dynamic> json) {
    return DynamicFormSubmissionAnswer(
      label: '${json['label'] ?? json['key'] ?? 'Answer'}',
      type: '${json['type'] ?? ''}',
      answer: json['answer'],
    );
  }
}

List<Map<String, dynamic>> _readList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<dynamic> _readRawList(dynamic value) => value is List ? value : const [];

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '${value ?? ''}'.toLowerCase().trim();
  return text == '1' || text == 'true' || text == 'yes' || text == 'on';
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

int? _readNullableInt(dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return null;
  return _readInt(value);
}

double _readDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

DateTime? _readDate(dynamic value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

String _normalizeColor(String value) {
  final color = value.trim();
  final hex = color.startsWith('#') ? color.substring(1) : color;
  if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
    return '#${hex.toLowerCase()}';
  }
  return '#ffffff';
}

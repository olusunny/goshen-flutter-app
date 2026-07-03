class DynamicForm {
  const DynamicForm({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.isOpen,
    required this.visibility,
    required this.requiresLogin,
    required this.oneSubmissionPerUser,
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
  final bool isOpen;
  final String visibility;
  final bool requiresLogin;
  final bool oneSubmissionPerUser;
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
      isOpen: _readBool(json['is_open']),
      visibility: '${json['visibility'] ?? 'public'}',
      requiresLogin: _readBool(json['requires_login']),
      oneSubmissionPerUser: _readBool(json['one_submission_per_user']),
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

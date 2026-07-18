enum GoshenPaymentReturnFlow {
  retreat,
  wallet,
  giving,
}

class GoshenPaymentReturnLink {
  const GoshenPaymentReturnLink({
    required this.success,
    required this.flow,
  });

  final bool success;
  final GoshenPaymentReturnFlow flow;

  bool get wallet => flow == GoshenPaymentReturnFlow.wallet;
}

GoshenPaymentReturnLink? parseGoshenPaymentReturnLink(Uri uri) {
  final custom = _parseCustomSchemePaymentLink(uri);
  if (custom != null) return custom;

  return _parsePortalPaymentLink(uri);
}

GoshenPaymentReturnLink? _parseCustomSchemePaymentLink(Uri uri) {
  if (uri.scheme != 'triumphant') return null;

  final host = uri.host.toLowerCase();
  final flow = switch (host) {
    'goshen-wallet' => GoshenPaymentReturnFlow.wallet,
    'goshen-payment' => _flowFromQuery(uri.queryParameters['flow']),
    _ => null,
  };
  if (flow == null) return null;

  final status = uri.pathSegments.isNotEmpty
      ? uri.pathSegments.first
      : uri.queryParameters['status'];
  final success = _paymentReturnStatusIsSuccess(status);
  if (success == null) return null;

  return GoshenPaymentReturnLink(success: success, flow: flow);
}

GoshenPaymentReturnFlow _flowFromQuery(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'giving' => GoshenPaymentReturnFlow.giving,
    _ => GoshenPaymentReturnFlow.retreat,
  };
}

GoshenPaymentReturnLink? _parsePortalPaymentLink(Uri uri) {
  if (uri.scheme != 'https') return null;
  if (uri.host.toLowerCase() != 'portal.goshenretreat.uk') return null;
  if (uri.pathSegments.isEmpty || uri.pathSegments.first != 'app') return null;

  final params = uri.queryParameters;

  final walletStatus = params['wallet'];
  final walletSuccess = _paymentReturnStatusIsSuccess(walletStatus);
  if (walletSuccess != null) {
    return GoshenPaymentReturnLink(
      success: walletSuccess,
      flow: GoshenPaymentReturnFlow.wallet,
    );
  }

  final checkoutStatus = params['checkout'];
  final checkoutSuccess = _paymentReturnStatusIsSuccess(checkoutStatus);
  if (checkoutSuccess != null) {
    return GoshenPaymentReturnLink(
      success: checkoutSuccess,
      flow: GoshenPaymentReturnFlow.retreat,
    );
  }

  final givingStatus = params['giving'];
  final givingSuccess = _paymentReturnStatusIsSuccess(givingStatus);
  if (givingSuccess != null) {
    return GoshenPaymentReturnLink(
      success: givingSuccess,
      flow: GoshenPaymentReturnFlow.giving,
    );
  }

  return null;
}

bool? _paymentReturnStatusIsSuccess(String? status) {
  final normalized = status?.trim().toLowerCase();
  return switch (normalized) {
    'success' || 'succeeded' || 'complete' || 'completed' => true,
    'cancel' || 'cancelled' || 'canceled' || 'failed' => false,
    _ => null,
  };
}

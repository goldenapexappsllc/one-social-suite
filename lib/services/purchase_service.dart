import 'dart:async';
import 'dart:io' show Platform;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three AI Assist subscription tiers. Product IDs must match exactly
/// what's configured in App Store Connect and Google Play Console.
enum AiAssistTier {
  starter('com.goldenapexapps.onesocial.aiassist.starter', 'aiassist_starter',
      'AI Assist Starter', 300),
  plus('com.goldenapexapps.onesocial.aiassist.plusv2', 'aiassist_plus',
      'AI Assist Plus', 600),
  pro('com.goldenapexapps.onesocial.aiassist.prov2', 'aiassist_pro',
      'AI Assist Pro', 1200);

  const AiAssistTier(this.iosProductId, this.androidProductId, this.displayName,
      this.monthlyCallLimit);

  final String iosProductId;
  final String androidProductId;
  final String displayName;
  final int monthlyCallLimit;

  String get productId => Platform.isIOS ? iosProductId : androidProductId;
}

/// Handles the real App Store / Play Store subscription purchase flow for
/// AI Assist, including usage-limit enforcement and periodic re-verification
/// of subscription status against the store.
///
/// This app has no backend server, so it can't listen for Apple/Google's
/// real-time subscription-change notifications the way a server-backed app
/// could. Instead, it re-checks with the store every time the app opens
/// (and periodically thereafter), and if a previously-active subscription
/// no longer comes back confirmed within a short window, local access is
/// cleared. Not instant, but never more than a few days stale, with zero
/// server infrastructure required.
class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  static const bool _devUnlockAll =
      bool.fromEnvironment('DEV_UNLOCK_ALL', defaultValue: false);

  static Set<String> get _productIds =>
      AiAssistTier.values.map((AiAssistTier t) => t.productId).toSet();

  static const _keyActiveTier = 'ai_assist_active_tier';
  static const _keyPurchaseDate = 'ai_assist_purchase_date';
  static const _keyLastVerified = 'ai_assist_last_verified';
  static const _keyCallCount = 'ai_assist_call_count';
  static const _keyPeriodStart = 'ai_assist_period_start';

  static const int _reverifyAfterDays = 3;
  static const int _billingPeriodDays = 30;
  static const Duration _restoreWindow = Duration(seconds: 5);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = <ProductDetails>[];
  bool _initialized = false;
  bool _sawActiveProductThisRound = false;

  List<ProductDetails> get products => _products;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final bool available = await _iap.isAvailable();
    if (!available) return;

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );

    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_productIds);
    _products = response.productDetails;

    await _verifyAgainstStore();
  }

  /// Call this every time the app resumes from the background. Only
  /// actually re-checks with the store if enough time has passed since
  /// the last verification, so it's cheap to call on every resume.
  Future<void> reverifyIfStale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastVerifiedStr = prefs.getString(_keyLastVerified);
    if (lastVerifiedStr != null) {
      final DateTime lastVerified = DateTime.parse(lastVerifiedStr);
      final int daysSince = DateTime.now().difference(lastVerified).inDays;
      if (daysSince < _reverifyAfterDays) return;
    }
    await _verifyAgainstStore();
  }

  /// The actual re-verification: asks the store to restore purchases,
  /// waits a short window for a response, and clears local access if a
  /// previously-active subscription doesn't come back confirmed.
  Future<void> _verifyAgainstStore() async {
    final AiAssistTier? tierBefore = await currentTier();
    _sawActiveProductThisRound = false;

    await _iap.restorePurchases();
    await Future<void>.delayed(_restoreWindow);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastVerified, DateTime.now().toIso8601String());

    if (tierBefore != null && !_sawActiveProductThisRound) {
      // Had a subscription before, store didn't confirm it this round --
      // treat as expired/cancelled and clear local access.
      await prefs.remove(_keyActiveTier);
      await prefs.remove(_keyPurchaseDate);
    }
  }

  Future<void> _handlePurchaseUpdates(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _sawActiveProductThisRound = true;
        await _recordActiveTier(purchase.productID);
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _recordActiveTier(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveTier, productId);
    await prefs.setString(_keyPurchaseDate, DateTime.now().toIso8601String());
    await prefs.setString(_keyLastVerified, DateTime.now().toIso8601String());
  }

  Future<void> purchaseTier(AiAssistTier tier) async {
    final ProductDetails? product = _products
        .where((ProductDetails p) => p.id == tier.productId)
        .firstOrNull;
    if (product == null) {
      throw StateError(
          'Product ${tier.productId} not available from the store yet. '
          'This usually means the subscription hasn\'t finished processing '
          'on the store side, or you are not signed into a test account.');
    }

    final PurchaseParam param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// User-facing manual restore, e.g. a "Restore Purchases" button.
  Future<void> restorePurchases() async {
    await _verifyAgainstStore();
  }

  Future<bool> hasActiveSubscription() async {
    final AiAssistTier? tier = await currentTier();
    return tier != null;
  }

  Future<AiAssistTier?> currentTier() async {
    if (_devUnlockAll) return AiAssistTier.pro;
    final prefs = await SharedPreferences.getInstance();
    final String? productId = prefs.getString(_keyActiveTier);
    if (productId == null) return null;
    return AiAssistTier.values
        .where((AiAssistTier t) => t.productId == productId)
        .firstOrNull;
  }

  // ---- Usage limit tracking ----

  /// Call before actually making an AI Assist request. Returns false if
  /// the current tier's monthly call limit has been reached.
  Future<bool> canMakeCall() async {
    final AiAssistTier? tier = await currentTier();
    if (tier == null) return false;
    final int used = await _currentPeriodCallCount();
    return used < tier.monthlyCallLimit;
  }

  /// Call immediately after a successful AI Assist response.
  Future<void> recordCallUsed() async {
    await _resetPeriodIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final int count = prefs.getInt(_keyCallCount) ?? 0;
    await prefs.setInt(_keyCallCount, count + 1);
  }

  Future<int> _currentPeriodCallCount() async {
    await _resetPeriodIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCallCount) ?? 0;
  }

  /// Rolls the usage counter over every ~30 days. A local approximation
  /// of the billing cycle, not tied to the exact receipt renewal date --
  /// good enough for fair-use enforcement without server-side receipt
  /// parsing this app doesn't have.
  Future<void> _resetPeriodIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final String? periodStartStr = prefs.getString(_keyPeriodStart);
    final DateTime now = DateTime.now();

    if (periodStartStr == null) {
      await prefs.setString(_keyPeriodStart, now.toIso8601String());
      await prefs.setInt(_keyCallCount, 0);
      return;
    }

    final DateTime periodStart = DateTime.parse(periodStartStr);
    if (now.difference(periodStart).inDays >= _billingPeriodDays) {
      await prefs.setString(_keyPeriodStart, now.toIso8601String());
      await prefs.setInt(_keyCallCount, 0);
    }
  }

  /// Calls remaining in the current period, for showing in the UI.
  Future<int?> callsRemaining() async {
    final AiAssistTier? tier = await currentTier();
    if (tier == null) return null;
    final int used = await _currentPeriodCallCount();
    final int remaining = tier.monthlyCallLimit - used;
    return remaining < 0 ? 0 : remaining;
  }

  void dispose() {
    _subscription?.cancel();
  }
}

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
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

/// The usage numbers the proxy last reported for this subscriber.
class _ServerMeter {
  const _ServerMeter({
    required this.monthlyLeft,
    required this.bonusLeft,
    required this.resetMs,
  });

  final int monthlyLeft;
  final int bonusLeft;
  final int resetMs;
}

/// Handles the real App Store / Play Store subscription purchase flow for
/// AI Assist, including usage-limit enforcement and periodic re-verification
/// of subscription status against the store.
///
/// Usage counting lives on the proxy server, keyed to the subscriber's
/// store purchase (not to this device), so deleting and reinstalling the
/// app cannot reset the allowance. The app stores proof of the purchase,
/// sends it with each AI request, and shows the numbers the server reports
/// back. The local counters below are only a fallback for when the server
/// has not reported yet.
///
/// The app also re-checks with the store every time it opens (and
/// periodically thereafter), and if a previously-active subscription no
/// longer comes back confirmed within a short window, local access is
/// cleared.
///
/// In debug builds, lines starting with [STORE] print what the store
/// returned (product counts, ids not found, errors, purchase updates).
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

  // Bonus balance carried over from the earlier welcome bonus. Nothing
  // grants it any more; people who already received it keep what is left.
  // Spent only after the monthly allowance runs out.
  static const _keyBonusLeft = 'ai_assist_bonus_left';

  // Purchase proof sent to the server, and the server's last-reported numbers.
  static const _keyProof = 'ai_assist_proof';
  static const _keySrvMonthlyLeft = 'ai_assist_srv_monthly_left';
  static const _keySrvBonusLeft = 'ai_assist_srv_bonus_left';
  static const _keySrvReset = 'ai_assist_srv_reset';

  static const int _reverifyAfterDays = 3;
  static const int _billingPeriodDays = 30;
  static const Duration _restoreWindow = Duration(seconds: 5);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = <ProductDetails>[];
  bool _initialized = false;
  bool _loadingProducts = false;
  bool _sawActiveProductThisRound = false;

  /// Plain-words note about why plans could not be loaded, or null.
  String? storeNote;

  // How many successful AI calls the server has already counted that the
  // caller has not yet reported through recordCallUsed().
  int _serverCountedPending = 0;

  List<ProductDetails> get products => _products;

  static void _log(String m) {
    if (kDebugMode) debugPrint('[STORE] $m');
  }

  Future<void> initialize() async {
    if (_initialized) {
      // If the first attempt found no plans, try again when the plans
      // screen opens (without re-running the slow purchase check).
      if (_products.isEmpty && !_loadingProducts) await _loadProducts();
      return;
    }
    _initialized = true;

    final bool available = await _iap.isAvailable();
    _log('store available: $available');
    if (!available) {
      storeNote = 'The App Store is not available right now.';
      _initialized = false; // allow another try next time
      return;
    }

    _subscription ??= _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (Object e) => _log('purchase stream error: ${e.runtimeType}'),
    );

    await _loadProducts();
    await _verifyAgainstStore();
  }

  /// Asks the store for the three plans and logs exactly what came back.
  Future<void> _loadProducts() async {
    _loadingProducts = true;
    try {
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(_productIds);
      _products = response.productDetails;
      _log('asked for ${_productIds.length} plans, got ${_products.length}');
      for (final ProductDetails p in _products) {
        _log('found ${p.id} price=${p.price}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        _log('NOT FOUND: ${response.notFoundIDs.join(', ')}');
      }
      final IAPError? err = response.error;
      if (err != null) {
        _log('store error: code=${err.code} message=${err.message}');
      }
      storeNote = _products.isEmpty
          ? 'No plans came back from the store. Check your connection and '
              'that you are signed in to the App Store, then try again.'
          : null;
    } catch (e) {
      _log('plan query failed: ${e.runtimeType}');
      storeNote = 'Plans could not be loaded from the store right now.';
    } finally {
      _loadingProducts = false;
    }
  }

  /// Bonus AI Assists still available, on top of the monthly allowance.
  /// Uses the server's number once the server has reported one. Only
  /// people who received the earlier welcome bonus have any.
  Future<int> bonusRemaining() async {
    final _ServerMeter? srv = await _readServerMeter();
    if (srv != null) return srv.bonusLeft < 0 ? 0 : srv.bonusLeft;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBonusLeft) ?? 0;
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

    _log('restore check: had plan=${tierBefore != null}, '
        'store confirmed=$_sawActiveProductThisRound');

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
      _log('purchase update: ${purchase.productID} ${purchase.status.name}'
          '${purchase.error == null ? '' : ' error=${purchase.error!.code}'}');
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _sawActiveProductThisRound = true;
        await _recordActiveTier(purchase.productID);
        await _recordProof(purchase);
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

  // ---- Purchase proof + server meter ----

  /// What the server needs to verify this purchase with Apple/Google.
  /// iOS: the original transaction ID (falls back to the purchase ID).
  /// Android: the Play purchase token.
  String? _proofFrom(PurchaseDetails purchase) {
    if (Platform.isIOS) {
      try {
        final dynamic tx = (purchase as dynamic).skPaymentTransaction;
        final String? original =
            tx?.originalTransaction?.transactionIdentifier as String?;
        if (original != null && original.isNotEmpty) return original;
      } catch (_) {}
      final String? id = purchase.purchaseID;
      return (id == null || id.isEmpty) ? null : id;
    }
    final String token = purchase.verificationData.serverVerificationData;
    return token.isEmpty ? null : token;
  }

  Future<void> _recordProof(PurchaseDetails purchase) async {
    final String? proof = _proofFrom(purchase);
    _log('proof stored: ${proof != null}');
    if (proof == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProof, proof);
  }

  /// Headers that go with every AI request. Empty if this device has no
  /// stored purchase proof yet.
  Future<Map<String, String>> serverHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? proof = prefs.getString(_keyProof);
    if (proof == null || proof.isEmpty) return <String, String>{};
    return <String, String>{
      'x-sub-proof': proof,
      'x-platform': Platform.isIOS ? 'ios' : 'android',
    };
  }

  /// Stores the usage numbers the server reported in its response headers.
  /// Returns true if the server sent them (meaning it counted the call).
  Future<bool> applyServerMeter(Map<String, String> headers) async {
    final int? monthly = int.tryParse(headers['x-ai-monthly-left'] ?? '');
    final int? bonus = int.tryParse(headers['x-ai-bonus-left'] ?? '');
    final int? reset = int.tryParse(headers['x-ai-reset'] ?? '');
    if (monthly == null || bonus == null || reset == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySrvMonthlyLeft, monthly);
    await prefs.setInt(_keySrvBonusLeft, bonus);
    await prefs.setInt(_keySrvReset, reset);
    return true;
  }

  /// Tells the service the server already counted one successful call, so
  /// the next recordCallUsed() must not count it again locally.
  void noteServerCountedCall() {
    _serverCountedPending++;
  }

  /// The server says there is no active subscription for our proof. Clear
  /// local access, and force a fresh store check on the next app resume so
  /// a paying user recovers quickly if the store still confirms them.
  Future<void> handleSubscriptionInactive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActiveTier);
    await prefs.remove(_keyPurchaseDate);
    await prefs.remove(_keyLastVerified);
    await prefs.remove(_keySrvMonthlyLeft);
    await prefs.remove(_keySrvBonusLeft);
    await prefs.remove(_keySrvReset);
  }

  Future<_ServerMeter?> _readServerMeter() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_keySrvReset)) return null;
    return _ServerMeter(
      monthlyLeft: prefs.getInt(_keySrvMonthlyLeft) ?? 0,
      bonusLeft: prefs.getInt(_keySrvBonusLeft) ?? 0,
      resetMs: prefs.getInt(_keySrvReset) ?? 0,
    );
  }

  Future<void> purchaseTier(AiAssistTier tier) async {
    final ProductDetails? product = _products
        .where((ProductDetails p) => p.id == tier.productId)
        .firstOrNull;
    if (product == null) {
      _log('buy blocked: ${tier.productId} is not in the loaded plans '
          '(${_products.map((ProductDetails p) => p.id).join(', ')})');
      throw StateError(
          'Product ${tier.productId} not available from the store yet. '
          'This usually means the subscription hasn\'t finished processing '
          'on the store side, or you are not signed into a test account.');
    }

    _log('starting purchase of ${tier.productId}');
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

  /// Call before actually making an AI Assist request. Returns false only
  /// if the monthly allowance AND the bonus are both used up. (The server
  /// enforces the same limit no matter what the app says.)
  Future<bool> canMakeCall() async {
    final AiAssistTier? tier = await currentTier();
    if (tier == null) return false;
    final int? left = await callsRemaining();
    return (left ?? 0) > 0;
  }

  /// Call immediately after a successful AI Assist response. If the server
  /// already counted the call, this does nothing. Otherwise (no server
  /// numbers) it spends the monthly allowance first, then any bonus left.
  Future<void> recordCallUsed() async {
    if (_serverCountedPending > 0) {
      _serverCountedPending--;
      return;
    }

    await _resetPeriodIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final int count = prefs.getInt(_keyCallCount) ?? 0;
    final AiAssistTier? tier = await currentTier();

    if (tier != null && count >= tier.monthlyCallLimit) {
      final int bonus = prefs.getInt(_keyBonusLeft) ?? 0;
      if (bonus > 0) {
        await prefs.setInt(_keyBonusLeft, bonus - 1);
        return;
      }
    }
    await prefs.setInt(_keyCallCount, count + 1);
  }

  Future<int> _currentPeriodCallCount() async {
    await _resetPeriodIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCallCount) ?? 0;
  }

  /// Rolls the local fallback counter over every ~30 days. Only used when
  /// the server has not reported numbers; the server tracks the real
  /// billing period.
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

  /// Calls remaining right now: what's left of the monthly allowance plus
  /// any bonus. Can be higher than the tier's monthly limit.
  Future<int?> callsRemaining() async {
    final int? monthly = await monthlyRemaining();
    if (monthly == null) return null;
    return monthly + await bonusRemaining();
  }

  /// What's left of the monthly allowance only, not counting the bonus.
  Future<int?> monthlyRemaining() async {
    final AiAssistTier? tier = await currentTier();
    if (tier == null) return null;

    final _ServerMeter? srv = await _readServerMeter();
    if (srv != null) {
      // If the billing period has rolled over since the server last
      // reported, the new period starts with the full allowance.
      if (srv.resetMs <= DateTime.now().millisecondsSinceEpoch) {
        return tier.monthlyCallLimit;
      }
      return srv.monthlyLeft < 0 ? 0 : srv.monthlyLeft;
    }

    final int used = await _currentPeriodCallCount();
    final int left = tier.monthlyCallLimit - used;
    return left < 0 ? 0 : left;
  }

  /// When the monthly count next rolls over, for showing in the UI. Uses
  /// the subscription's real renewal date once the server has reported it.
  Future<DateTime?> nextResetDate() async {
    final AiAssistTier? tier = await currentTier();
    if (tier == null) return null;

    final _ServerMeter? srv = await _readServerMeter();
    if (srv != null) {
      DateTime next = DateTime.fromMillisecondsSinceEpoch(srv.resetMs);
      final DateTime now = DateTime.now();
      while (!next.isAfter(now)) {
        next = next.add(const Duration(days: _billingPeriodDays));
      }
      return next;
    }

    await _resetPeriodIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final String? startStr = prefs.getString(_keyPeriodStart);
    if (startStr == null) return null;
    return DateTime.parse(startStr)
        .add(const Duration(days: _billingPeriodDays));
  }

  void dispose() {
    _subscription?.cancel();
  }
}

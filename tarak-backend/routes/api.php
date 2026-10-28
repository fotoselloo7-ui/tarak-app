<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\HealthController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes - Tarak
|--------------------------------------------------------------------------
*/

// Health Check
Route::get('/health', [HealthController::class, 'index']);
Route::get('/health/ready', [HealthController::class, 'ready']);

// Address lookup during existing customer/provider registration. Keep the server key private.
Route::get('/geo/search', [App\Http\Controllers\Api\GeoController::class, 'search'])->middleware('throttle:20,1');
Route::get('/geo/reverse', [App\Http\Controllers\Api\GeoController::class, 'reverse'])->middleware('throttle:20,1');
Route::get('/geo/config', [App\Http\Controllers\Api\GeoController::class, 'config'])->middleware('throttle:60,1');

// Public Auth Routes (Rate limited to 20 req/min to protect against brute-force)
Route::prefix('auth')->middleware('throttle:20,1')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
    Route::get('/social/config', [App\Http\Controllers\Api\SocialAuthController::class, 'config']);
    Route::get('/social/nonce', [App\Http\Controllers\Api\SocialAuthController::class, 'nonce'])->middleware('throttle:10,1');
    Route::get('/verification/config', [App\Http\Controllers\Api\RegistrationVerificationController::class, 'config']);
    Route::post('/social/{provider}/prefill', [App\Http\Controllers\Api\SocialAuthController::class, 'prefill'])
        ->where('provider', 'google|apple')->middleware('throttle:10,1');
    Route::post('/social/{provider}/login', [App\Http\Controllers\Api\SocialAuthController::class, 'login'])
        ->where('provider', 'google|apple')->middleware('throttle:10,1');
    Route::post('/verification/{channel}/send', [App\Http\Controllers\Api\RegistrationVerificationController::class, 'send'])
        ->where('channel', 'email|sms')->middleware('throttle:5,1');
    Route::post('/verification/{channel}/confirm', [App\Http\Controllers\Api\RegistrationVerificationController::class, 'confirm'])
        ->where('channel', 'email|sms')->middleware('throttle:10,1');
});

// Authenticated Auth Routes
Route::prefix('auth')->middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/change-password', [AuthController::class, 'changePassword'])->middleware('throttle:10,1');
    Route::post('/social/{provider}/link', [App\Http\Controllers\Api\SocialAuthController::class, 'link'])
        ->where('provider', 'google|apple')->middleware('throttle:5,1');

    // Active session (Sanctum token) management — no raw tokens exposed.
    Route::get('/sessions', [App\Http\Controllers\Api\SessionController::class, 'index']);
    Route::delete('/sessions/{id}', [App\Http\Controllers\Api\SessionController::class, 'destroy'])->whereNumber('id');
    Route::post('/sessions/revoke-others', [App\Http\Controllers\Api\SessionController::class, 'destroyOthers']);
});

// Profile media (avatar) — canonical for ALL authenticated roles (users.avatar_url).
Route::middleware(['auth:sanctum'])->prefix('profile')->group(function () {
    Route::post('/avatar', [App\Http\Controllers\Api\ProfileMediaController::class, 'uploadAvatar'])->middleware('throttle:15,1');
    Route::delete('/avatar', [App\Http\Controllers\Api\ProfileMediaController::class, 'destroyAvatar']);
    // Self-service account deletion/deactivation (any authenticated role).
    Route::delete('/account', [AuthController::class, 'deleteAccount'])->middleware('throttle:5,1');
});

// Public Service Catalog Endpoints
Route::get('/service-categories', [App\Http\Controllers\Api\ServiceCatalogController::class, 'categories']);
Route::get('/services', [App\Http\Controllers\Api\ServiceCatalogController::class, 'services']);

// Public landing page content (admin-managed)
Route::get('/site-config', [App\Http\Controllers\Api\SiteContentController::class, 'show'])->middleware('throttle:120,1');

// Public: every listable provider, paginated + filterable ("Tüm uzmanlar"):
// ?type=barber|coiffeur &min_rating= &min_reviews= &q= &sort=rating|reviews|newest &page= &per_page=
Route::get('/providers', [App\Http\Controllers\Api\PublicProviderController::class, 'index'])->middleware('throttle:120,1');
// Public: verified providers ranked by Tarak puanı (real data only; ?type=barber|coiffeur&limit=)
Route::get('/providers/featured', [App\Http\Controllers\Api\PublicProviderController::class, 'featured'])->middleware('throttle:120,1');
// Public: "Öne Çıkan Profesyoneller" — providers with a running paid öne çıkarma period
Route::get('/providers/spotlight', [App\Http\Controllers\Api\PublicProviderController::class, 'spotlight'])->middleware('throttle:120,1');
// Public: "Yeni Katılan Profesyoneller" — most recently approved providers
Route::get('/providers/newest', [App\Http\Controllers\Api\PublicProviderController::class, 'newest'])->middleware('throttle:120,1');
// Public: home-page statistics (real or admin-typed, per the admin's mode; ?audience=all|customer|provider)
Route::get('/stats/home', [App\Http\Controllers\Api\HomeStatsController::class, 'home'])->middleware('throttle:120,1');

// Public: single provider card (homepage card -> real profile, no dead route)
Route::get('/providers/{provider}', [App\Http\Controllers\Api\PublicProviderController::class, 'show'])
    ->whereNumber('provider')->middleware('throttle:120,1');

// Public: provider public rating summary + reviews
Route::get('/providers/{provider}/reviews', [App\Http\Controllers\Api\ReviewController::class, 'providerSummary'])->whereNumber('provider')->middleware('throttle:120,1');

// Public: support tickets (contact form; links user if a token is present)
Route::post('/support/tickets', [App\Http\Controllers\Api\SupportController::class, 'store'])->middleware('throttle:10,1');

// Public: newsletter subscribe / unsubscribe
Route::post('/newsletter', [App\Http\Controllers\Api\NewsletterController::class, 'subscribe'])->middleware('throttle:10,1');
Route::get('/newsletter/unsubscribe/{token}', [App\Http\Controllers\Api\NewsletterController::class, 'unsubscribe'])->middleware('throttle:30,1');

// Role-protected test & boundary endpoints
Route::middleware(['auth:sanctum', 'role:ADMIN'])->prefix('admin')->group(function () {
    Route::get('/ping', function () {
        return response()->json([
            'success' => true,
            'message' => 'Admin erişimi başarılı.',
            'role' => 'ADMIN',
        ]);
    });

    // Provider Applications & Approval Management
    Route::get('/provider-applications', [App\Http\Controllers\Api\AdminProviderApplicationController::class, 'index']);
    Route::get('/provider-applications/{id}', [App\Http\Controllers\Api\AdminProviderApplicationController::class, 'show']);
    Route::post('/provider-applications/{id}/review', [App\Http\Controllers\Api\AdminProviderApplicationController::class, 'reviewApplication']);

    // KYC Document Review & Private Document Preview
    Route::post('/provider-documents/{id}/review', [App\Http\Controllers\Api\AdminProviderApplicationController::class, 'reviewDocument']);
    Route::get('/provider-documents/{id}/preview', [App\Http\Controllers\Api\AdminProviderApplicationController::class, 'previewDocument']);

    // Landing page content management
    Route::put('/site-config', [App\Http\Controllers\Api\SiteContentController::class, 'update']);
    Route::post('/site-config/branding/{type}', [App\Http\Controllers\Api\SiteContentController::class, 'uploadBrandingImage'])
        ->where('type', 'logo|logo_dark|favicon|hero_image|og_image');
    Route::delete('/site-config/branding/{type}', [App\Http\Controllers\Api\SiteContentController::class, 'deleteBrandingImage'])
        ->where('type', 'logo|logo_dark|favicon|hero_image|og_image');

    // Support tickets & newsletter administration
    Route::get('/support-tickets', [App\Http\Controllers\Api\SupportController::class, 'index']);
    Route::patch('/support-tickets/{id}', [App\Http\Controllers\Api\SupportController::class, 'update'])->whereNumber('id');
    Route::get('/newsletter', [App\Http\Controllers\Api\NewsletterController::class, 'index']);

    // Finance Settings
    Route::get('/finance/settings', [App\Http\Controllers\Api\AdminFinanceController::class, 'getSettings']);
    Route::put('/finance/settings', [App\Http\Controllers\Api\AdminFinanceController::class, 'updateSettings']);

    // Commission bank collection: IBAN account, payment notices / verification, ledger, audit log
    Route::get('/finance/bank-settings', [App\Http\Controllers\Api\AdminCommissionTopupController::class, 'bankSettings']);
    Route::put('/finance/bank-settings', [App\Http\Controllers\Api\AdminCommissionTopupController::class, 'updateBankSettings'])->middleware('throttle:20,1');
    Route::get('/finance/topups', [App\Http\Controllers\Api\AdminCommissionTopupController::class, 'index']);
    Route::post('/finance/topups', [App\Http\Controllers\Api\AdminCommissionTopupController::class, 'store'])->middleware('throttle:60,1');
    Route::post('/finance/topups/{id}/verify', [App\Http\Controllers\Api\AdminCommissionTopupController::class, 'verify'])->whereNumber('id')->middleware('throttle:60,1');
    Route::post('/finance/topups/{id}/reject', [App\Http\Controllers\Api\AdminCommissionTopupController::class, 'reject'])->whereNumber('id')->middleware('throttle:60,1');
    Route::get('/finance/ledger', [App\Http\Controllers\Api\AdminCommissionTopupController::class, 'ledger']);
    Route::get('/finance/audit-logs', [App\Http\Controllers\Api\AdminCommissionTopupController::class, 'auditLogs']);

    // Dispute Case Management
    Route::get('/disputes', [App\Http\Controllers\Api\AdminDisputeController::class, 'index']);
    Route::get('/disputes/{id}', [App\Http\Controllers\Api\AdminDisputeController::class, 'show']);
    Route::post('/disputes/{id}/start-review', [App\Http\Controllers\Api\AdminDisputeController::class, 'startReview']);
    Route::post('/disputes/{id}/resolve', [App\Http\Controllers\Api\AdminDisputeController::class, 'resolve']);

    // Marketplace Provider Payout Transfers
    Route::get('/payout-transfers', [\App\Http\Controllers\Api\AdminPayoutTransferController::class, 'index']);
    Route::post('/payout-transfers/{payment}/send', [\App\Http\Controllers\Api\AdminPayoutTransferController::class, 'send']);

    /*
    | Integration Center — external services, health & observability.
    | ADMIN-ONLY (inherits role:ADMIN from this group). Responses never
    | contain raw credentials; only masked values / configured flags.
    */
    Route::prefix('integrations')->group(function () {
        Route::get('/overview', [App\Http\Controllers\Api\AdminIntegrationController::class, 'overview']);
        Route::get('/health', [App\Http\Controllers\Api\AdminIntegrationController::class, 'health']);
        Route::get('/events', [App\Http\Controllers\Api\AdminIntegrationController::class, 'events']);

        // Failed jobs administration
        Route::get('/failed-jobs', [App\Http\Controllers\Api\AdminIntegrationController::class, 'failedJobs']);
        Route::post('/failed-jobs/{uuid}/retry', [App\Http\Controllers\Api\AdminIntegrationController::class, 'retryFailedJob']);
        Route::delete('/failed-jobs/{uuid}', [App\Http\Controllers\Api\AdminIntegrationController::class, 'deleteFailedJob']);

        // Test / validation actions (never start a real financial transaction)
        Route::post('/paytr/validate', [App\Http\Controllers\Api\AdminIntegrationController::class, 'validatePaytr'])->middleware('throttle:20,1');
        Route::post('/sms/test', [App\Http\Controllers\Api\AdminIntegrationController::class, 'testSms'])->middleware('throttle:10,1');
        Route::get('/sms/logs', [App\Http\Controllers\Api\AdminIntegrationController::class, 'smsLogs']);
        Route::post('/smtp/test', [App\Http\Controllers\Api\AdminIntegrationController::class, 'testEmail'])->middleware('throttle:10,1');
        Route::get('/firebase/devices', [App\Http\Controllers\Api\AdminIntegrationController::class, 'pushDevices']);
        Route::post('/firebase/test', [App\Http\Controllers\Api\AdminIntegrationController::class, 'testPush'])->middleware('throttle:10,1');
        Route::post('/reverb/test', [App\Http\Controllers\Api\AdminIntegrationController::class, 'testReverb'])->middleware('throttle:20,1');

        // Settings (empty secret preserves the stored credential)
        Route::put('/settings/{group}', [App\Http\Controllers\Api\AdminIntegrationController::class, 'updateSettings']);

        // Detail tab (kept last so it can't shadow the static routes above)
        Route::get('/{integration}', [App\Http\Controllers\Api\AdminIntegrationController::class, 'show'])
            ->where('integration', 'paytr|sms|smtp|firebase|reverb|queue|scheduler');
    });

    // PayTR Online Refunds & Admin Operations
    Route::get('/refunds', [\App\Http\Controllers\Api\AdminRefundController::class, 'index']);
    Route::get('/refunds/{id}', [\App\Http\Controllers\Api\AdminRefundController::class, 'show']);
    Route::post('/refunds/{id}/retry', [\App\Http\Controllers\Api\AdminRefundController::class, 'retry'])->middleware('throttle:15,1');
    Route::post('/service-payments/{payment}/refund', [\App\Http\Controllers\Api\AdminRefundController::class, 'triggerRefund']);

    // Reported user-generated content (chat messages, reviews)
    Route::get('/content-reports', [App\Http\Controllers\Api\AdminContentReportController::class, 'index']);
    Route::patch('/content-reports/{id}', [App\Http\Controllers\Api\AdminContentReportController::class, 'update'])->whereNumber('id');

    // Member management (customers / providers / admins)
    Route::get('/users', [App\Http\Controllers\Api\AdminUserController::class, 'index']);
    Route::get('/users/{id}', [App\Http\Controllers\Api\AdminUserController::class, 'show'])->whereNumber('id');
    Route::patch('/users/{id}', [App\Http\Controllers\Api\AdminUserController::class, 'update'])->whereNumber('id');
    Route::post('/users/{id}/password', [App\Http\Controllers\Api\AdminUserController::class, 'resetPassword'])->whereNumber('id')->middleware('throttle:20,1');
    Route::delete('/users/{id}/avatar', [App\Http\Controllers\Api\AdminUserController::class, 'destroyAvatar'])->whereNumber('id');
    Route::delete('/users/{id}', [App\Http\Controllers\Api\AdminUserController::class, 'destroy'])->whereNumber('id');
    Route::get('/users/{id}/reviews', [App\Http\Controllers\Api\AdminUserController::class, 'reviews'])->whereNumber('id');
    Route::delete('/reviews/{id}', [App\Http\Controllers\Api\AdminUserController::class, 'destroyReview'])->whereNumber('id');

    // "Öne çıkarma": admin-priced packages, who is featured, gift / stop a period
    Route::get('/featured/summary', [App\Http\Controllers\Api\AdminFeaturedController::class, 'summary']);
    Route::get('/featured/placements', [App\Http\Controllers\Api\AdminFeaturedController::class, 'placements']);
    Route::put('/featured/placements/{placement}', [App\Http\Controllers\Api\AdminFeaturedController::class, 'updatePlacement']);
    Route::get('/featured/packages', [App\Http\Controllers\Api\AdminFeaturedController::class, 'packages']);
    Route::post('/featured/packages', [App\Http\Controllers\Api\AdminFeaturedController::class, 'storePackage']);
    Route::put('/featured/packages/{id}', [App\Http\Controllers\Api\AdminFeaturedController::class, 'updatePackage'])->whereNumber('id');
    Route::delete('/featured/packages/{id}', [App\Http\Controllers\Api\AdminFeaturedController::class, 'destroyPackage'])->whereNumber('id');
    Route::get('/featured/promotions', [App\Http\Controllers\Api\AdminFeaturedController::class, 'promotions']);
    Route::post('/featured/promotions', [App\Http\Controllers\Api\AdminFeaturedController::class, 'grant'])->middleware('throttle:30,1');
    Route::post('/featured/promotions/{id}/cancel', [App\Http\Controllers\Api\AdminFeaturedController::class, 'cancel'])->whereNumber('id');

    // Premium Broadcast Center: ADMIN only, distinct from providers' paid notification ads.
    Route::get('/broadcasts', [App\Http\Controllers\Api\AdminBroadcastController::class, 'index']);
    Route::post('/broadcasts/estimate', [App\Http\Controllers\Api\AdminBroadcastController::class, 'estimate'])->middleware('throttle:60,1');
    Route::post('/broadcasts/test', [App\Http\Controllers\Api\AdminBroadcastController::class, 'test'])->middleware('throttle:6,1');
    Route::post('/broadcasts', [App\Http\Controllers\Api\AdminBroadcastController::class, 'store'])->middleware('throttle:20,1');
    Route::put('/broadcasts/{broadcast}', [App\Http\Controllers\Api\AdminBroadcastController::class, 'update'])->whereNumber('broadcast')->middleware('throttle:20,1');
    Route::post('/broadcasts/{broadcast}/send', [App\Http\Controllers\Api\AdminBroadcastController::class, 'send'])->whereNumber('broadcast')->middleware('throttle:6,1');
    Route::post('/broadcasts/{broadcast}/schedule', [App\Http\Controllers\Api\AdminBroadcastController::class, 'schedule'])->whereNumber('broadcast')->middleware('throttle:6,1');
    Route::post('/broadcasts/{broadcast}/pause', [App\Http\Controllers\Api\AdminBroadcastController::class, 'pause'])->whereNumber('broadcast')->middleware('throttle:6,1');
    Route::post('/broadcasts/{broadcast}/cancel', [App\Http\Controllers\Api\AdminBroadcastController::class, 'cancel'])->whereNumber('broadcast')->middleware('throttle:6,1');

    // "Bildirim reklamı": prices per audience, discount limits, anti-spam caps, what was sent
    Route::get('/notification-ads/settings', [App\Http\Controllers\Api\AdminNotificationAdController::class, 'settings']);
    Route::put('/notification-ads/settings', [App\Http\Controllers\Api\AdminNotificationAdController::class, 'updateSettings']);
    Route::get('/notification-ads', [App\Http\Controllers\Api\AdminNotificationAdController::class, 'index']);

    // Demo (pre-launch preview) data: list, generate, purge-all
    Route::get('/demo-data', [App\Http\Controllers\Api\AdminDemoDataController::class, 'index']);
    Route::get('/demo-data/users', [App\Http\Controllers\Api\AdminDemoDataController::class, 'users']);
    Route::post('/demo-data/generate', [App\Http\Controllers\Api\AdminDemoDataController::class, 'generate'])->middleware('throttle:6,1');
    Route::post('/demo-data/customers', [App\Http\Controllers\Api\AdminDemoDataController::class, 'addCustomers'])->middleware('throttle:6,1');
    Route::delete('/demo-data', [App\Http\Controllers\Api\AdminDemoDataController::class, 'purge'])->middleware('throttle:6,1');
});


Route::middleware(['auth:sanctum', 'role:PROVIDER'])->prefix('provider')->group(function () {
    Route::get('/ping', function () {
        return response()->json([
            'success' => true,
            'message' => 'Hizmet veren erişimi başarılı.',
            'role' => 'PROVIDER',
        ]);
    });

    // Provider Profile, Services & KYC Documents
    Route::get('/profile', [App\Http\Controllers\Api\ProviderProfileController::class, 'getProfile']);
    Route::put('/profile', [App\Http\Controllers\Api\ProviderProfileController::class, 'updateProfile']);
    Route::get('/services', [App\Http\Controllers\Api\ProviderProfileController::class, 'getServices']);
    Route::put('/services', [App\Http\Controllers\Api\ProviderProfileController::class, 'updateServices']);
    Route::patch('/services', [App\Http\Controllers\Api\ProviderProfileController::class, 'upsertService']);
    Route::get('/packages', [App\Http\Controllers\Api\ProviderPackageController::class, 'index']);
    Route::post('/packages', [App\Http\Controllers\Api\ProviderPackageController::class, 'store']);
    Route::put('/packages/{id}', [App\Http\Controllers\Api\ProviderPackageController::class, 'update'])->whereNumber('id');
    Route::delete('/packages/{id}', [App\Http\Controllers\Api\ProviderPackageController::class, 'destroy'])->whereNumber('id');
    Route::get('/documents', [App\Http\Controllers\Api\ProviderProfileController::class, 'getDocuments']);
    Route::post('/documents', [App\Http\Controllers\Api\ProviderProfileController::class, 'uploadDocument']);
    Route::delete('/documents/{id}', [App\Http\Controllers\Api\ProviderProfileController::class, 'destroyDocument']);

    // Business showcase media: cover + gallery (public disk; separate from private KYC documents above).
    Route::post('/profile/cover', [App\Http\Controllers\Api\ProviderProfileController::class, 'uploadCover'])->middleware('throttle:15,1');
    Route::delete('/profile/cover', [App\Http\Controllers\Api\ProviderProfileController::class, 'destroyCover']);
    Route::post('/profile/gallery', [App\Http\Controllers\Api\ProviderProfileController::class, 'uploadGalleryImage'])->middleware('throttle:15,1');
    Route::delete('/profile/gallery', [App\Http\Controllers\Api\ProviderProfileController::class, 'destroyGalleryImage']);

    // Instant Service Requests & Offers (Marketplace)
    Route::get('/service-requests', [App\Http\Controllers\Api\ProviderServiceRequestController::class, 'marketplace']);
    Route::get('/service-requests/{id}', [App\Http\Controllers\Api\ProviderServiceRequestController::class, 'show']);
    Route::post('/service-requests/{id}/offers', [App\Http\Controllers\Api\ProviderServiceRequestController::class, 'createOffer']);
    Route::post('/service-requests/{id}/accept-direct', [App\Http\Controllers\Api\ProviderServiceRequestController::class, 'acceptDirect'])->whereNumber('id');
    Route::post('/service-requests/{id}/decline-direct', [App\Http\Controllers\Api\ProviderServiceRequestController::class, 'declineDirect'])->whereNumber('id');
    Route::get('/offers', [App\Http\Controllers\Api\ProviderServiceRequestController::class, 'myOffers']);
    Route::get('/assigned-requests', [App\Http\Controllers\Api\ProviderServiceRequestController::class, 'assigned']);

    // Working Schedule & Closed Dates
    Route::get('/schedule', [App\Http\Controllers\ProviderScheduleController::class, 'getSchedule']);
    Route::put('/schedule', [App\Http\Controllers\ProviderScheduleController::class, 'updateSchedule']);
    Route::get('/closed-dates', [App\Http\Controllers\ProviderScheduleController::class, 'getClosedDates']);
    Route::post('/closed-dates', [App\Http\Controllers\ProviderScheduleController::class, 'storeClosedDate']);
    Route::delete('/closed-dates/{id}', [App\Http\Controllers\ProviderScheduleController::class, 'destroyClosedDate']);

    // Scheduled Appointments
    Route::get('/appointments', [App\Http\Controllers\ProviderAppointmentController::class, 'index']);
    Route::get('/appointments/{id}', [App\Http\Controllers\ProviderAppointmentController::class, 'show']);
    Route::post('/appointments/{id}/confirm', [App\Http\Controllers\ProviderAppointmentController::class, 'confirm']);
    Route::post('/appointments/{id}/reject', [App\Http\Controllers\ProviderAppointmentController::class, 'reject']);
    Route::post('/appointments/{id}/alternatives', [App\Http\Controllers\ProviderAppointmentController::class, 'proposeAlternatives']);

    // Location Share Grants (PROVIDER READ)
    Route::get('/service-requests/{id}/shared-location', [App\Http\Controllers\Api\ProviderLocationShareController::class, 'getInstantSharedLocation']);
    Route::get('/appointments/{id}/shared-location', [App\Http\Controllers\Api\ProviderLocationShareController::class, 'getAppointmentSharedLocation']);

    // Service Lifecycle & Start Code (PROVIDER)
    Route::post('/service-requests/{id}/verify-start-code', [App\Http\Controllers\Api\ProviderServiceLifecycleController::class, 'verifyInstantRequestStartCode'])->middleware('throttle:15,1');
    Route::post('/service-requests/{id}/finish', [App\Http\Controllers\Api\ProviderServiceLifecycleController::class, 'finishInstantRequest']);
    Route::post('/appointments/{id}/verify-start-code', [App\Http\Controllers\Api\ProviderServiceLifecycleController::class, 'verifyAppointmentStartCode'])->middleware('throttle:15,1');
    Route::post('/appointments/{id}/finish', [App\Http\Controllers\Api\ProviderServiceLifecycleController::class, 'finishAppointment']);

    // Reviews (provider's own rating summary + reviews)
    Route::get('/reviews', [App\Http\Controllers\Api\ReviewController::class, 'mine']);

    // "Öne çıkarma" (paid featured placement), paid from the wallet cash balance
    Route::get('/featured', [App\Http\Controllers\Api\ProviderFeaturedController::class, 'show']);
    Route::post('/featured/purchase', [App\Http\Controllers\Api\ProviderFeaturedController::class, 'purchase'])->middleware('throttle:10,1');
    Route::get('/featured/visibility', [App\Http\Controllers\Api\ProviderFeaturedController::class, 'visibility']);
    Route::get('/featured/orders/{id}', [App\Http\Controllers\Api\ProviderFeaturedController::class, 'orderStatus'])->whereNumber('id')->middleware('throttle:60,1');

    // "Bildirim reklamı": a paid discount notification to customers (the discount itself is real, see ProviderDiscountService)
    Route::get('/notification-ads', [App\Http\Controllers\Api\ProviderNotificationAdController::class, 'show']);
    Route::get('/notification-ads/districts', [App\Http\Controllers\Api\ProviderNotificationAdController::class, 'districts'])->middleware('throttle:60,1');
    Route::post('/notification-ads/estimate', [App\Http\Controllers\Api\ProviderNotificationAdController::class, 'estimate'])->middleware('throttle:60,1');
    Route::post('/notification-ads', [App\Http\Controllers\Api\ProviderNotificationAdController::class, 'store'])->middleware('throttle:10,1');
    Route::get('/notification-ads/{id}', [App\Http\Controllers\Api\ProviderNotificationAdController::class, 'status'])->whereNumber('id')->middleware('throttle:60,1');
    Route::delete('/notification-ads/discount', [App\Http\Controllers\Api\ProviderNotificationAdController::class, 'endDiscount']);

    // Wallet & Ledger Transactions
    Route::get('/wallet', [App\Http\Controllers\Api\ProviderWalletController::class, 'getWallet']);
    Route::get('/wallet/transactions', [App\Http\Controllers\Api\ProviderWalletController::class, 'getTransactions']);

    // İşletme Finans Merkezi: commission payment details (bank account + TRK code), payment notices, e-mail copy
    Route::get('/finance/payment-info', [App\Http\Controllers\Api\ProviderFinanceController::class, 'paymentInfo'])->middleware('throttle:60,1');
    Route::get('/finance/topups', [App\Http\Controllers\Api\ProviderFinanceController::class, 'topups']);
    Route::post('/finance/topups', [App\Http\Controllers\Api\ProviderFinanceController::class, 'submitTopup'])->middleware('throttle:10,1');
    Route::post('/finance/payment-info/email', [App\Http\Controllers\Api\ProviderFinanceController::class, 'emailPaymentInfo'])->middleware('throttle:6,1');

    // Provider Payout Bank Account & Payouts
    Route::get('/payout-account', [\App\Http\Controllers\Api\ProviderPayoutAccountController::class, 'show']);
    Route::put('/payout-account', [\App\Http\Controllers\Api\ProviderPayoutAccountController::class, 'update']);
    Route::get('/payouts', [\App\Http\Controllers\Api\ProviderPayoutAccountController::class, 'payouts']);

    // Conversations (PROVIDER)
    Route::get('/service-requests/{id}/conversation', [App\Http\Controllers\Api\ConversationController::class, 'forProviderServiceRequest']);
    Route::get('/appointments/{id}/conversation', [App\Http\Controllers\Api\ConversationController::class, 'forProviderAppointment']);
});

Route::middleware(['auth:sanctum', 'role:CUSTOMER'])->prefix('customer')->group(function () {
    Route::get('/ping', function () {
        return response()->json([
            'success' => true,
            'message' => 'Müşteri erişimi başarılı.',
            'role' => 'CUSTOMER',
        ]);
    });

    // Customer Profile & Saved Addresses
    Route::get('/profile', [App\Http\Controllers\Api\CustomerProfileController::class, 'getProfile']);
    Route::put('/profile', [App\Http\Controllers\Api\CustomerProfileController::class, 'updateProfile']);
    Route::get('/addresses', [App\Http\Controllers\Api\CustomerProfileController::class, 'getAddresses']);
    Route::post('/addresses', [App\Http\Controllers\Api\CustomerProfileController::class, 'storeAddress']);
    Route::put('/addresses/{id}', [App\Http\Controllers\Api\CustomerProfileController::class, 'updateAddress']);
    Route::delete('/addresses/{id}', [App\Http\Controllers\Api\CustomerProfileController::class, 'destroyAddress']);

    // Shared web/mobile "Size Yakın Berberler" query; saved default address is used by default.
    Route::get('/providers/nearby', [App\Http\Controllers\Api\PublicProviderController::class, 'nearby'])->middleware('throttle:60,1');

    // Instant Service Requests & Offers
    Route::get('/service-requests', [App\Http\Controllers\Api\CustomerServiceRequestController::class, 'index']);
    Route::post('/service-requests', [App\Http\Controllers\Api\CustomerServiceRequestController::class, 'store']);
    Route::get('/service-requests/{id}', [App\Http\Controllers\Api\CustomerServiceRequestController::class, 'show']);
    Route::post('/service-requests/{id}/cancel', [App\Http\Controllers\Api\CustomerServiceRequestController::class, 'cancel']);
    Route::get('/service-requests/{id}/offers', [App\Http\Controllers\Api\CustomerServiceRequestController::class, 'offers']);
    Route::post('/service-requests/{id}/offers/{offerId}/accept', [App\Http\Controllers\Api\CustomerServiceRequestController::class, 'acceptOffer']);

    // Scheduled Appointments & Provider Discovery
    Route::get('/providers', [App\Http\Controllers\CustomerAppointmentController::class, 'providers']);
    Route::get('/services/{service}/providers', [App\Http\Controllers\Api\CustomerOfferingController::class, 'providersForService'])->whereNumber('service');
    Route::get('/providers/{provider}/offerings', [App\Http\Controllers\Api\CustomerOfferingController::class, 'providerOfferings'])->whereNumber('provider');
    Route::get('/providers/{provider}/availability', [App\Http\Controllers\CustomerAppointmentController::class, 'availability'])
        ->withoutMiddleware('role:CUSTOMER')
        ->middleware('role:CUSTOMER,PROVIDER');
    Route::get('/appointments', [App\Http\Controllers\CustomerAppointmentController::class, 'index']);
    Route::post('/appointments', [App\Http\Controllers\CustomerAppointmentController::class, 'store']);
    Route::get('/appointments/{id}', [App\Http\Controllers\CustomerAppointmentController::class, 'show']);
    Route::post('/appointments/{id}/cancel', [App\Http\Controllers\CustomerAppointmentController::class, 'cancel']);
    Route::post('/appointments/{id}/alternatives/{slot}/accept', [App\Http\Controllers\CustomerAppointmentController::class, 'acceptAlternative']);
    Route::post('/appointments/{id}/alternatives/reject', [App\Http\Controllers\CustomerAppointmentController::class, 'rejectAlternative']);

    // Location Share Grants (CUSTOMER)
    Route::post('/service-requests/{id}/location-share', [App\Http\Controllers\Api\CustomerLocationShareController::class, 'shareInstantLocation']);
    Route::delete('/service-requests/{id}/location-share', [App\Http\Controllers\Api\CustomerLocationShareController::class, 'revokeInstantLocation']);
    Route::get('/service-requests/{id}/location-share', [App\Http\Controllers\Api\CustomerLocationShareController::class, 'getInstantLocationStatus']);

    Route::post('/appointments/{id}/location-share', [App\Http\Controllers\Api\CustomerLocationShareController::class, 'shareAppointmentLocation']);
    Route::delete('/appointments/{id}/location-share', [App\Http\Controllers\Api\CustomerLocationShareController::class, 'revokeAppointmentLocation']);
    Route::get('/appointments/{id}/location-share', [App\Http\Controllers\Api\CustomerLocationShareController::class, 'getAppointmentLocationStatus']);

    // Service Lifecycle & Start Code (CUSTOMER)
    Route::get('/service-requests/{id}/start-code', [App\Http\Controllers\Api\CustomerServiceLifecycleController::class, 'getInstantRequestStartCode']);
    Route::post('/service-requests/{id}/start-code/regenerate', [App\Http\Controllers\Api\CustomerServiceLifecycleController::class, 'regenerateInstantRequestStartCode']);
    Route::post('/service-requests/{id}/complete', [App\Http\Controllers\Api\CustomerServiceLifecycleController::class, 'completeInstantRequest']);
    Route::post('/service-requests/{id}/report-problem', [App\Http\Controllers\Api\CustomerServiceLifecycleController::class, 'reportProblemInstantRequest']);

    Route::get('/appointments/{id}/start-code', [App\Http\Controllers\Api\CustomerServiceLifecycleController::class, 'getAppointmentStartCode']);
    Route::post('/appointments/{id}/start-code/regenerate', [App\Http\Controllers\Api\CustomerServiceLifecycleController::class, 'regenerateAppointmentStartCode']);
    Route::post('/appointments/{id}/complete', [App\Http\Controllers\Api\CustomerServiceLifecycleController::class, 'completeAppointment']);
    Route::post('/appointments/{id}/report-problem', [App\Http\Controllers\Api\CustomerServiceLifecycleController::class, 'reportProblemAppointment']);

    // Reviews (create after a completed appointment/request)
    Route::post('/reviews', [App\Http\Controllers\Api\ReviewController::class, 'store']);
    // Customer's own written reviews (read-only — backend has no edit/delete)
    Route::get('/reviews', [App\Http\Controllers\Api\ReviewController::class, 'myGivenReviews']);

    // Favourite providers
    Route::get('/favorites', [App\Http\Controllers\Api\FavoriteController::class, 'index']);
    Route::post('/favorites', [App\Http\Controllers\Api\FavoriteController::class, 'store']);
    Route::delete('/favorites/{provider}', [App\Http\Controllers\Api\FavoriteController::class, 'destroy'])->whereNumber('provider');

    // Payment / transaction history (reuses ServicePayment records)
    Route::get('/payments', [App\Http\Controllers\Api\CustomerPaymentController::class, 'history']);

    // Online Payments & PayTR (CUSTOMER)
    // Capability probe so the UI can hide online payment when the gateway is
    // unconfigured (cash always stays available).
    Route::get('/payment-capabilities', [App\Http\Controllers\Api\CustomerPaymentController::class, 'capabilities']);
    Route::post('/service-payments/{payment}/paytr/token', [App\Http\Controllers\Api\CustomerPaymentController::class, 'createPaytrToken'])->middleware('throttle:15,1');
    Route::get('/service-payments/{payment}/status', [App\Http\Controllers\Api\CustomerPaymentController::class, 'getPaymentStatus']);
    Route::get('/service-payments/{payment}/refunds', [App\Http\Controllers\Api\CustomerPaymentController::class, 'getRefundSummary']);

    // Conversations (CUSTOMER)
    Route::get('/service-requests/{id}/conversation', [App\Http\Controllers\Api\ConversationController::class, 'forCustomerServiceRequest']);
    Route::get('/appointments/{id}/conversation', [App\Http\Controllers\Api\ConversationController::class, 'forCustomerAppointment']);
});

// PayTR Webhook Callbacks (Public Server-to-Server)
Route::post('/payments/paytr/callback', [App\Http\Controllers\Api\PaytrWebhookController::class, 'handleCallback']);
Route::post('/payments/paytr/platform-transfer/callback', [App\Http\Controllers\Api\PaytrWebhookController::class, 'handleTransferCallback']);

// In-App Notifications (Authenticated - all roles: CUSTOMER, PROVIDER, ADMIN)
Route::middleware(['auth:sanctum'])->prefix('notifications')->group(function () {
    Route::get('/', [App\Http\Controllers\Api\NotificationController::class, 'index']);
    Route::get('/unread-count', [App\Http\Controllers\Api\NotificationController::class, 'unreadCount']);
    Route::post('/read-all', [App\Http\Controllers\Api\NotificationController::class, 'markAllRead']);
    Route::post('/{id}/read', [App\Http\Controllers\Api\NotificationController::class, 'markOneRead']);
});

// Conversations & Realtime Messaging (Authenticated Participants)
Route::middleware(['auth:sanctum'])->prefix('conversations')->group(function () {
    Route::get('/', [App\Http\Controllers\Api\ConversationController::class, 'index']);
    Route::get('/unread-count', [App\Http\Controllers\Api\ConversationController::class, 'unreadCount']);
    Route::get('/{conversation}/messages', [App\Http\Controllers\Api\ConversationController::class, 'messages']);
    Route::post('/{conversation}/messages', [App\Http\Controllers\Api\ConversationController::class, 'sendMessage'])->middleware('throttle:60,1');
    Route::post('/{conversation}/read', [App\Http\Controllers\Api\ConversationController::class, 'markAsRead']);
});

// User-generated content safety: report messages/reviews, block users (all authenticated roles)
Route::middleware(['auth:sanctum'])->group(function () {
    Route::post('/reports', [App\Http\Controllers\Api\ContentReportController::class, 'store'])->middleware('throttle:20,1');
    Route::get('/blocks', [App\Http\Controllers\Api\UserBlockController::class, 'index']);
    Route::post('/blocks', [App\Http\Controllers\Api\UserBlockController::class, 'store'])->middleware('throttle:30,1');
    Route::delete('/blocks/{user}', [App\Http\Controllers\Api\UserBlockController::class, 'destroy'])->whereNumber('user');
});

// Mobile Push Notifications (Authenticated)
Route::middleware(['auth:sanctum'])->prefix('push')->group(function () {
    Route::post('/devices', [App\Http\Controllers\Api\PushNotificationController::class, 'registerDevice'])->middleware('throttle:30,1');
    Route::delete('/devices/{device}', [App\Http\Controllers\Api\PushNotificationController::class, 'unregisterDevice']);
    Route::get('/devices', [App\Http\Controllers\Api\PushNotificationController::class, 'listDevices']);
    Route::get('/preferences', [App\Http\Controllers\Api\PushNotificationController::class, 'getPreferences']);
    Route::put('/preferences', [App\Http\Controllers\Api\PushNotificationController::class, 'updatePreferences']);
});

// Broadcasting Channel Authentication (Sanctum)
Illuminate\Support\Facades\Broadcast::routes(['middleware' => ['auth:sanctum', 'throttle:60,1']]);



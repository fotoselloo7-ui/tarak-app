<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminLog;
use App\Models\ProviderProfile;
use App\Models\ProviderReview;
use App\Models\User;
use App\Services\DemoDataException;
use App\Services\DemoDataService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AdminDemoDataController extends Controller
{
    public const PURGE_CONFIRMATION = 'DEMO-SIL';

    public function __construct(protected DemoDataService $demo)
    {
    }

    /** GET /api/admin/demo-data */
    public function index(): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $this->demo->stats()]);
    }

    /** GET /api/admin/demo-data/users?type=customer|provider&q=&page= */
    public function users(Request $request): JsonResponse
    {
        $type = $request->query('type') === 'provider' ? User::ROLE_PROVIDER : User::ROLE_CUSTOMER;
        $perPage = min(50, max(5, (int) $request->query('per_page', 20)));
        $term = trim((string) $request->query('q', ''));

        $paginator = User::withTrashed()
            ->where('is_demo', true)
            ->where('role', $type)
            ->when($term !== '', fn ($q) => $q->where(fn ($w) => $w
                ->where('name', 'like', "%$term%")
                ->orWhere('email', 'like', "%$term%")
                ->orWhere('phone', 'like', "%$term%")))
            ->orderBy('id')
            ->paginate($perPage);

        $ids = $paginator->getCollection()->pluck('id');
        $profiles = $type === User::ROLE_PROVIDER
            ? ProviderProfile::whereIn('user_id', $ids)->get()->keyBy('user_id')
            : collect();
        $reviewStats = $type === User::ROLE_PROVIDER
            ? ProviderReview::query()->whereIn('provider_user_id', $ids)
                ->selectRaw('provider_user_id, COUNT(*) as c, AVG(rating) as a')->groupBy('provider_user_id')->get()->keyBy('provider_user_id')
            : collect();

        $rows = $paginator->getCollection()->map(function (User $user) use ($profiles, $reviewStats) {
            $row = [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'gender' => $user->gender,
                'status' => $user->status,
                'avatar_url' => $user->avatar_url,
                'created_at' => $user->created_at?->toIso8601String(),
            ];
            if ($profile = $profiles->get($user->id)) {
                $stat = $reviewStats->get($user->id);
                $row += [
                    'business_name' => $profile->business_name,
                    'provider_type' => $profile->provider_type,
                    'city' => $profile->city,
                    'district' => $profile->district,
                    'gallery_count' => count($profile->gallery ?? []),
                    'review_count' => (int) ($stat->c ?? 0),
                    'rating' => $stat ? round((float) $stat->a, 2) : null,
                ];
            }

            return $row;
        });

        return response()->json([
            'success' => true,
            'data' => $rows,
            'pagination' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    /** POST /api/admin/demo-data/generate */
    public function generate(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'customers' => ['nullable', 'integer', 'min:0', 'max:' . DemoDataService::MAX_PER_ROLE],
            'providers' => ['nullable', 'integer', 'min:0', 'max:' . DemoDataService::MAX_PER_ROLE],
        ]);

        try {
            $stats = $this->demo->generate((int) ($validated['customers'] ?? 100), (int) ($validated['providers'] ?? 100));
        } catch (DemoDataException $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 422);
        }

        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_DEMO_DATA_GENERATED, AdminLog::TARGET_SYSTEM, 0, [
            'customers' => $stats['customers'],
            'providers' => $stats['providers'],
            'reviews' => $stats['reviews'],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Demo veriler oluşturuldu.',
            'data' => $stats,
        ], 201);
    }

    /** POST /api/admin/demo-data/customers  { "count": 5000 }: more demo customers on top of the demo set (purged with it). */
    public function addCustomers(Request $request): JsonResponse
    {
        $validated = $request->validate(['count' => ['required', 'integer', 'min:1', 'max:' . DemoDataService::MAX_EXTRA_CUSTOMERS]]);

        try {
            $stats = $this->demo->addCustomers((int) $validated['count']);
        } catch (DemoDataException $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 422);
        }

        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_DEMO_DATA_GENERATED, AdminLog::TARGET_SYSTEM, 0, [
            'customers' => $stats['customers'],
            'providers' => $stats['providers'],
            'added_customers' => (int) $validated['count'],
        ]);

        return response()->json(['success' => true, 'message' => $validated['count'] . ' demo müşteri eklendi.', 'data' => $stats], 201);
    }

    /** DELETE /api/admin/demo-data  { "confirm": "DEMO-SIL" } */
    public function purge(Request $request): JsonResponse
    {
        $request->validate(['confirm' => ['required', 'string']]);
        if ($request->input('confirm') !== self::PURGE_CONFIRMATION) {
            return response()->json([
                'success' => false,
                'message' => 'Onay metni hatalı. Silmek için ' . self::PURGE_CONFIRMATION . ' yazın.',
            ], 422);
        }

        $removed = $this->demo->purge();

        AdminLog::logAction((int) $request->user()->id, AdminLog::ACTION_DEMO_DATA_PURGED, AdminLog::TARGET_SYSTEM, 0, [
            'customers' => $removed['customers'],
            'providers' => $removed['providers'],
            'reviews' => $removed['reviews'],
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Tüm demo veriler silindi.',
            'data' => $removed,
        ]);
    }
}

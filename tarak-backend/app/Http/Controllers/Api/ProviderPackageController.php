<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ProviderPackage;
use App\Models\ProviderProfile;
use App\Models\Service;
use App\Services\ProviderOfferingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProviderPackageController extends Controller
{
    private const MAX_PACKAGES = 30;

    public function __construct(protected ProviderOfferingService $offerings) {}

    public function index(Request $request): JsonResponse
    {
        $profile = $this->profile($request);

        return response()->json([
            'success' => true,
            'data' => $profile->packages()->with('services')->get()
                ->map(fn ($p) => $this->offerings->presentPackage($p))->values(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $profile = $this->profile($request);
        $validated = $this->validatePayload($request, true);

        if ($profile->packages()->count() >= self::MAX_PACKAGES) {
            return response()->json([
                'success' => false,
                'message' => 'En fazla ' . self::MAX_PACKAGES . ' paket oluşturabilirsiniz.',
            ], 422);
        }

        $package = DB::transaction(function () use ($profile, $validated) {
            $package = $profile->packages()->create([
                'title' => $validated['title'],
                'description' => $validated['description'] ?? null,
                'price' => $validated['price'],
                'duration_minutes' => $validated['duration_minutes'],
                'is_active' => $validated['is_active'] ?? true,
                'sort_order' => (int) $profile->packages()->max('sort_order') + 1,
            ]);
            $this->syncItems($package, $validated['service_ids']);

            return $package;
        });

        return response()->json([
            'success' => true,
            'message' => 'Paket oluşturuldu.',
            'data' => $this->offerings->presentPackage($package->load('services')),
        ], 201);
    }

    public function update(Request $request, int $id): JsonResponse
    {
        $package = $this->ownedPackage($request, $id);
        if (!$package) {
            return response()->json(['success' => false, 'message' => 'Paket bulunamadı.'], 404);
        }

        $validated = $this->validatePayload($request, false);

        DB::transaction(function () use ($package, $validated) {
            $package->fill(array_intersect_key($validated, array_flip(['title', 'description', 'price', 'duration_minutes', 'is_active'])));
            $package->save();

            if (array_key_exists('service_ids', $validated)) {
                $this->syncItems($package, $validated['service_ids']);
            }
        });

        return response()->json([
            'success' => true,
            'message' => 'Paket güncellendi.',
            'data' => $this->offerings->presentPackage($package->fresh('services')),
        ]);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $package = $this->ownedPackage($request, $id);
        if (!$package) {
            return response()->json(['success' => false, 'message' => 'Paket bulunamadı.'], 404);
        }

        // Existing requests/appointments keep their own snapshot; the FK is nulled on delete.
        $package->delete();

        return response()->json(['success' => true, 'message' => 'Paket silindi.']);
    }

    private function validatePayload(Request $request, bool $creating): array
    {
        $req = $creating ? 'required' : 'sometimes';

        return $request->validate([
            'title' => [$req, 'string', 'min:3', 'max:120'],
            'description' => ['nullable', 'string', 'max:1000'],
            'price' => [$req, 'numeric', 'min:1', 'max:50000'],
            'duration_minutes' => [$req, 'integer', 'min:15', 'max:480'],
            'is_active' => ['sometimes', 'boolean'],
            'service_ids' => [$req, 'array', 'min:1', 'max:10'],
            'service_ids.*' => ['integer', 'distinct', 'exists:services,id'],
        ], [
            'title.required' => 'Paket başlığı zorunludur.',
            'price.required' => 'Paket fiyatı zorunludur.',
            'price.min' => 'Paket fiyatı en az ₺1 olmalıdır.',
            'duration_minutes.required' => 'Paket süresi zorunludur.',
            'duration_minutes.min' => 'Paket süresi en az 15 dakika olmalıdır.',
            'service_ids.required' => 'Pakete en az bir hizmet ekleyin.',
            'service_ids.min' => 'Pakete en az bir hizmet ekleyin.',
            'service_ids.*.distinct' => 'Aynı hizmet pakete birden fazla kez eklenemez.',
            'service_ids.*.exists' => 'Seçilen hizmet katalogda bulunamadı.',
        ]);
    }

    private function syncItems(ProviderPackage $package, array $serviceIds): void
    {
        $inactive = Service::whereIn('id', $serviceIds)->where('is_active', false)->exists();
        if ($inactive) {
            abort(response()->json([
                'success' => false,
                'message' => 'Pakete yalnızca aktif katalog hizmetleri eklenebilir.',
            ], 422));
        }

        $sync = [];
        foreach (array_values($serviceIds) as $i => $serviceId) {
            $sync[(int) $serviceId] = ['sort_order' => $i];
        }
        $package->services()->sync($sync);
    }

    private function ownedPackage(Request $request, int $id): ?ProviderPackage
    {
        return $this->profile($request)->packages()->whereKey($id)->first();
    }

    private function profile(Request $request): ProviderProfile
    {
        $user = $request->user();

        return $user->providerProfile()->firstOrCreate(['user_id' => $user->id]);
    }
}

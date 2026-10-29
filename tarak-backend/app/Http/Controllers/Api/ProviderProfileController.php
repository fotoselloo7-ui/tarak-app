<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProviderDocumentResource;
use App\Http\Resources\ProviderProfileResource;
use App\Http\Resources\ProviderServiceResource;
use App\Http\Resources\UserResource;
use App\Models\ProviderDocument;
use App\Models\ProviderProfile;
use App\Models\ProviderService;
use App\Models\Service;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use App\Support\MediaUrl;

class ProviderProfileController extends Controller
{
    /**
     * Helper to re-evaluate and update provider profile_completed status.
     */
    private function checkAndUpdateProfileCompleted(ProviderProfile $profile): bool
    {
        $hasRequiredFields = !empty($profile->provider_type)
            && !empty($profile->work_mode)
            && $profile->service_radius_km > 0
            && $profile->experience_years !== null
            && (!empty($profile->city) || !empty($profile->address_detail));

        $hasAtLeastOneService = $profile->providerServices()->where('is_active', true)->exists();
        $hasAtLeastOneDocument = $profile->documents()->exists();

        $isComplete = $hasRequiredFields && $hasAtLeastOneService && $hasAtLeastOneDocument;

        if ($profile->profile_completed !== $isComplete) {
            $profile->update(['profile_completed' => $isComplete]);
        }

        return $isComplete;
    }

    /**
     * Get authenticated provider's full profile.
     */
    public function getProfile(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile()
            ->with(['providerServices.service', 'documents'])
            ->firstOrCreate(['user_id' => $user->id]);

        return response()->json([
            'success' => true,
            'data' => [
                'user' => new UserResource($user->load('providerProfile')),
                'profile' => new ProviderProfileResource($profile),
            ],
        ]);
    }

    /**
     * Update provider profile.
     * Security: is_approved, identity_status, commission_rate_override etc. CANNOT be altered by provider!
     */
    public function updateProfile(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile()->firstOrCreate(['user_id' => $user->id]);

        $validated = $request->validate([
            // User info
            'name' => ['nullable', 'string', 'max:100'],
            'first_name' => ['nullable', 'string', 'max:50'],
            'last_name' => ['nullable', 'string', 'max:50'],
            'email' => ['nullable', 'email:rfc', 'max:100', 'unique:users,email,' . $user->id],
            // Profile fields
            'provider_type' => ['nullable', 'string', 'in:barber,coiffeur'],
            'work_mode' => ['nullable', 'string', 'in:venue,mobile,both'],
            'business_name' => ['nullable', 'string', 'max:150'],
            'service_radius_km' => ['nullable', 'integer', 'min:1', 'max:100'],
            'experience_years' => ['nullable', 'integer', 'min:0', 'max:60'],
            'city' => ['nullable', 'string', 'max:100'],
            'district' => ['nullable', 'string', 'max:100'],
            'neighborhood' => ['nullable', 'string', 'max:150'],
            'street' => ['nullable', 'string', 'max:200'],
            'building_no' => ['nullable', 'string', 'max:30'],
            'address_detail' => ['nullable', 'string'],
            'latitude' => ['nullable', 'required_with:longitude', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'required_with:latitude', 'numeric', 'between:-180,180'],
            'bio' => ['nullable', 'string', 'max:1000'],
            'title' => ['nullable', 'string', 'max:150'],
            'cover_url' => ['nullable', 'string', 'max:500'],
            'cover_position_x' => ['nullable', 'integer', 'min:0', 'max:100'],
            'cover_position_y' => ['nullable', 'integer', 'min:0', 'max:100'],
            'gallery' => ['nullable', 'array'],
            'gallery.*' => ['string', 'max:500'],
            'is_online' => ['nullable', 'boolean'],
            'accepts_new_clients' => ['nullable', 'boolean'],
        ]);

        DB::transaction(function () use ($user, $profile, $validated) {
            // Update User fields if present
            $userUpdates = [];
            if (!empty($validated['name'])) {
                $userUpdates['name'] = $validated['name'];
            }
            if (!empty($validated['first_name'])) {
                $userUpdates['first_name'] = $validated['first_name'];
            }
            if (!empty($validated['last_name'])) {
                $userUpdates['last_name'] = $validated['last_name'];
            }
            if (!empty($validated['email'])) {
                $userUpdates['email'] = strtolower(trim($validated['email']));
            }
            if (!empty($userUpdates)) {
                $user->update($userUpdates);
            }

            // Strictly whitelist updatable provider fields
            // SECURITY: Never allow updating is_approved, identity_status, approved_at, reviewed_at, commission_rate_override
            $allowedProfileFields = [
                'provider_type',
                'work_mode',
                'business_name',
                'service_radius_km',
                'experience_years',
                'city',
                'district',
                'neighborhood',
                'street',
                'building_no',
                'address_detail',
                'latitude',
                'longitude',
                'bio',
                'title',
                'cover_url',
                'cover_position_x',
                'cover_position_y',
                'gallery',
                'is_online',
                'accepts_new_clients',
            ];

            $profileUpdates = array_intersect_key($validated, array_flip($allowedProfileFields));
            $profile->update($profileUpdates);

            $this->checkAndUpdateProfileCompleted($profile);
        });

        $profile->load(['providerServices.service', 'documents']);

        return response()->json([
            'success' => true,
            'message' => 'Profil bilgileri güncellendi.',
            'data' => [
                'user' => new UserResource($user->fresh()),
                'profile' => new ProviderProfileResource($profile->fresh(['providerServices.service', 'documents'])),
            ],
        ]);
    }

    /**
     * Get provider's assigned services.
     */
    public function getServices(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile()->firstOrCreate(['user_id' => $user->id]);
        $services = $profile->providerServices()->with('service')->get();

        return response()->json([
            'success' => true,
            'data' => ProviderServiceResource::collection($services),
        ]);
    }

    /**
     * Update/Sync provider services.
     * Prevents duplicate service assignments and enforces validity.
     */
    public function updateServices(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile()->firstOrCreate(['user_id' => $user->id]);

        $validated = $request->validate([
            'services' => ['required', 'array', 'min:1'],
            'services.*.service_id' => ['required', 'exists:services,id'],
            'services.*.custom_price' => ['nullable', 'numeric', 'min:0'],
            'services.*.custom_duration_minutes' => ['nullable', 'integer', 'min:5', 'max:480'],
            'services.*.description' => ['nullable', 'string', 'max:300'],
            'services.*.is_active' => ['nullable', 'boolean'],
        ], [
            'services.required' => 'En az bir hizmet seçilmelidir.',
            'services.min' => 'En az bir hizmet seçilmelidir.',
            'services.*.service_id.exists' => 'Seçilen hizmet geçerli değil.',
        ]);

        DB::transaction(function () use ($profile, $validated) {
            // Build sync payload ensuring unique service IDs
            $syncData = [];
            foreach ($validated['services'] as $item) {
                $serviceId = (int) $item['service_id'];
                $syncData[$serviceId] = [
                    'custom_price' => isset($item['custom_price']) ? (float) $item['custom_price'] : null,
                    'custom_duration_minutes' => isset($item['custom_duration_minutes']) ? (int) $item['custom_duration_minutes'] : null,
                    'description' => isset($item['description']) && trim($item['description']) !== '' ? trim($item['description']) : null,
                    'is_active' => array_key_exists('is_active', $item) ? (bool) $item['is_active'] : true,
                ];
            }

            // Sync will delete removed ones, insert new ones, and update existing ones without duplication
            $profile->services()->sync($syncData);

            $this->checkAndUpdateProfileCompleted($profile);
        });

        $services = $profile->providerServices()->with('service')->get();

        return response()->json([
            'success' => true,
            'message' => 'Hizmetleriniz başarıyla güncellendi.',
            'data' => ProviderServiceResource::collection($services),
        ]);
    }

    /**
     * Add a catalog service to the provider's offerings, or update price/duration/description/active state of one.
     */
    public function upsertService(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile()->firstOrCreate(['user_id' => $user->id]);

        $validated = $request->validate([
            'service_id' => ['required', 'integer', 'exists:services,id'],
            'custom_price' => ['nullable', 'numeric', 'min:0', 'max:50000'],
            'custom_duration_minutes' => ['nullable', 'integer', 'min:5', 'max:480'],
            'description' => ['nullable', 'string', 'max:300'],
            'is_active' => ['sometimes', 'boolean'],
        ], [
            'service_id.exists' => 'Seçilen hizmet katalogda bulunamadı.',
        ]);

        $catalog = \App\Models\Service::find($validated['service_id']);
        if (!$catalog->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Bu katalog hizmeti şu anda aktif değil.',
            ], 422);
        }

        $providerService = $profile->providerServices()->firstOrNew(['service_id' => $catalog->id]);
        foreach (['custom_price', 'custom_duration_minutes', 'description'] as $field) {
            if (array_key_exists($field, $validated)) {
                $value = $validated[$field];
                $providerService->{$field} = is_string($value) && trim($value) === '' ? null : $value;
            }
        }
        $providerService->is_active = array_key_exists('is_active', $validated)
            ? (bool) $validated['is_active']
            : ($providerService->exists ? $providerService->is_active : true);
        $providerService->save();

        $this->checkAndUpdateProfileCompleted($profile);

        return response()->json([
            'success' => true,
            'message' => 'Hizmet kaydedildi.',
            'data' => new ProviderServiceResource($providerService->load('service')),
        ]);
    }

    private const MEDIA_MAX_KB = 5120; // 5MB
    private const MAX_GALLERY_IMAGES = 12;

    /**
     * Upload/replace the provider's cover image. Reuses the same public-disk
     * media convention as ProfileMediaController; entirely separate from the
     * private KYC document storage.
     */
    public function uploadCover(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile()->firstOrCreate(['user_id' => $user->id]);

        $request->validate([
            'cover' => ['required', 'file', 'mimes:jpg,jpeg,png,webp', 'max:' . self::MEDIA_MAX_KB],
        ], [
            'cover.required' => 'Lütfen bir kapak görseli seçiniz.',
            'cover.mimes' => 'Yalnızca JPG, JPEG, PNG veya WEBP formatı kabul edilir.',
            'cover.max' => 'Görsel boyutu en fazla 5 MB olabilir.',
        ]);

        $file = $request->file('cover');
        $extension = strtolower($file->getClientOriginalExtension() ?: $file->extension());
        $filename = (string) Str::uuid() . '.' . $extension;
        $path = $file->storeAs('provider-media/' . $profile->id . '/cover', $filename, 'public');
        $url = MediaUrl::fromPublicPath($path);

        $oldPath = ProfileMediaController::managedPublicPath($profile->cover_url);
        $profile->update(['cover_url' => $url]);

        if ($oldPath && $oldPath !== $path) {
            Storage::disk('public')->delete($oldPath);
        }

        return response()->json([
            'success' => true,
            'message' => 'Kapak görseli güncellendi.',
            'data' => new ProviderProfileResource($profile->fresh()),
        ]);
    }

    public function destroyCover(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Profil bulunamadı.'], 404);
        }

        $oldPath = ProfileMediaController::managedPublicPath($profile->cover_url);
        $profile->update(['cover_url' => null]);

        if ($oldPath) {
            Storage::disk('public')->delete($oldPath);
        }

        return response()->json([
            'success' => true,
            'message' => 'Kapak görseli kaldırıldı.',
            'data' => new ProviderProfileResource($profile->fresh()),
        ]);
    }

    /**
     * Append an image to the provider's gallery (JSON array of public URLs).
     */
    public function uploadGalleryImage(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile()->firstOrCreate(['user_id' => $user->id]);

        $request->validate([
            'image' => ['required', 'file', 'mimes:jpg,jpeg,png,webp', 'max:' . self::MEDIA_MAX_KB],
        ], [
            'image.required' => 'Lütfen bir görsel seçiniz.',
            'image.mimes' => 'Yalnızca JPG, JPEG, PNG veya WEBP formatı kabul edilir.',
            'image.max' => 'Görsel boyutu en fazla 5 MB olabilir.',
        ]);

        $gallery = $profile->gallery ?? [];
        if (count($gallery) >= self::MAX_GALLERY_IMAGES) {
            return response()->json([
                'success' => false,
                'message' => 'En fazla ' . self::MAX_GALLERY_IMAGES . ' galeri görseli ekleyebilirsiniz.',
            ], 422);
        }

        $file = $request->file('image');
        $extension = strtolower($file->getClientOriginalExtension() ?: $file->extension());
        $filename = (string) Str::uuid() . '.' . $extension;
        $path = $file->storeAs('provider-media/' . $profile->id . '/gallery', $filename, 'public');
        $url = MediaUrl::fromPublicPath($path);

        $gallery[] = $url;
        $profile->update(['gallery' => array_values($gallery)]);

        return response()->json([
            'success' => true,
            'message' => 'Görsel galeriye eklendi.',
            'data' => new ProviderProfileResource($profile->fresh()),
        ], 201);
    }

    /**
     * Remove a single image from the provider's gallery by URL. Ownership is
     * implicit: only URLs present in the authenticated provider's own gallery
     * array can be removed.
     */
    public function destroyGalleryImage(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;
        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Profil bulunamadı.'], 404);
        }

        $validated = $request->validate([
            'url' => ['required', 'string'],
        ]);

        $gallery = $profile->gallery ?? [];
        $requested = MediaUrl::resolve($validated['url']);
        $storedUrl = collect($gallery)->first(fn ($url) => $url === $validated['url'] || MediaUrl::resolve($url) === $requested);
        if (!$storedUrl) {
            return response()->json(['success' => false, 'message' => 'Görsel bulunamadı.'], 404);
        }

        $gallery = array_values(array_filter($gallery, fn ($u) => $u !== $storedUrl));
        $profile->update(['gallery' => $gallery]);

        $path = ProfileMediaController::managedPublicPath($storedUrl);
        if ($path) {
            Storage::disk('public')->delete($path);
        }

        return response()->json([
            'success' => true,
            'message' => 'Görsel galeriden kaldırıldı.',
            'data' => new ProviderProfileResource($profile->fresh()),
        ]);
    }

    /**
     * List all documents uploaded by the authenticated provider.
     */
    public function getDocuments(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile()->firstOrCreate(['user_id' => $user->id]);
        $documents = $profile->documents()->latest()->get();

        return response()->json([
            'success' => true,
            'data' => ProviderDocumentResource::collection($documents),
        ]);
    }

    /**
     * Upload a new KYC qualification document.
     * Enforces private storage, random UUID filename, MIME validation & 5MB max.
     */
    public function uploadDocument(Request $request): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile()->firstOrCreate(['user_id' => $user->id]);

        $request->validate([
            'document_type' => ['required', 'string', 'in:DIPLOMA,MASTER_CERTIFICATE,JOURNEYMAN_CERTIFICATE,diploma,mastery,journeyman'],
            'document' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:5120'], // 5MB = 5120 KB
        ], [
            'document.required' => 'Lütfen bir belge dosyası seçiniz.',
            'document.file' => 'Geçerli bir dosya yükleyiniz.',
            'document.mimes' => 'Yalnızca PDF, JPG, JPEG veya PNG formatında belgeler kabul edilmektedir.',
            'document.max' => 'Belge boyutu en fazla 5 MB olabilir.',
            'document_type.required' => 'Belge türü seçimi zorunludur.',
            'document_type.in' => 'Geçersiz belge türü.',
        ]);

        $file = $request->file('document');
        $rawType = strtoupper(trim($request->input('document_type')));

        // Normalize document type
        $docType = match ($rawType) {
            'DIPLOMA' => ProviderDocument::TYPE_DIPLOMA,
            'MASTERY', 'MASTER_CERTIFICATE' => ProviderDocument::TYPE_MASTER_CERTIFICATE,
            'JOURNEYMAN', 'JOURNEYMAN_CERTIFICATE' => ProviderDocument::TYPE_JOURNEYMAN_CERTIFICATE,
            default => ProviderDocument::TYPE_MASTER_CERTIFICATE,
        };

        // Generate safe private path with UUID
        $extension = strtolower($file->getClientOriginalExtension());
        $safeFileName = (string) Str::uuid() . '.' . $extension;
        $relativeFolder = 'provider-documents/' . $profile->id;
        
        // Store in private storage (storage/app/private/provider-documents/...)
        $storagePath = $file->storeAs($relativeFolder, $safeFileName, 'local');

        $document = DB::transaction(function () use ($profile, $docType, $file, $storagePath) {
            $doc = $profile->documents()->create([
                'document_type' => $docType,
                'original_name' => $file->getClientOriginalName(),
                'storage_path' => $storagePath,
                'mime_type' => $file->getMimeType(),
                'file_size' => $file->getSize(),
                'status' => ProviderDocument::STATUS_PENDING,
                'uploaded_at' => now(),
            ]);

            // Reupload flow: if provider was awaiting reupload (or rejected), transition identity_status back to PENDING
            if (in_array($profile->identity_status, [ProviderDocument::STATUS_REUPLOAD_REQUIRED, ProviderDocument::STATUS_REJECTED], true)) {
                if (!$profile->is_approved || !$profile->hasApprovedDocument()) {
                    $profile->update([
                        'identity_status' => 'PENDING',
                    ]);
                }
            }

            $this->checkAndUpdateProfileCompleted($profile);
            return $doc;
        });

        return response()->json([
            'success' => true,
            'message' => 'Mesleki belgeniz başarıyla yüklendi ve incelemeye alındı.',
            'data' => new ProviderDocumentResource($document),
        ], 201);
    }

    /**
     * Delete an uploaded KYC document.
     * Ownership strictly verified; deletes private file from disk.
     */
    public function destroyDocument(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $profile = $user->providerProfile;

        if (!$profile) {
            return response()->json(['success' => false, 'message' => 'Profil bulunamadı.'], 404);
        }

        // Ownership check
        $document = $profile->documents()->where('id', $id)->first();
        if (!$document) {
            return response()->json([
                'success' => false,
                'message' => 'Belge bulunamadı veya erişim yetkiniz yok.',
            ], 404);
        }

        // Cannot delete APPROVED documents without admin intervention
        if ($document->status === ProviderDocument::STATUS_APPROVED) {
            return response()->json([
                'success' => false,
                'message' => 'Onaylanmış mesleki belgeler doğrudan silinemez. Destek ekibiyle iletişime geçiniz.',
            ], 403);
        }

        DB::transaction(function () use ($profile, $document) {
            // Delete file from private disk if exists
            if ($document->storage_path && Storage::disk('local')->exists($document->storage_path)) {
                Storage::disk('local')->delete($document->storage_path);
            }

            $document->delete();

            $this->checkAndUpdateProfileCompleted($profile);
        });

        return response()->json([
            'success' => true,
            'message' => 'Belge başarıyla silindi.',
        ]);
    }
}

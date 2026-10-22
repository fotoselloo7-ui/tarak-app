<?php

namespace App\Services;

use App\Models\CustomerAddress;
use App\Models\CustomerProfile;
use App\Models\FeaturedPackage;
use App\Models\FeaturedPromotion;
use App\Models\ProviderDocument;
use App\Models\ProviderPackage;
use App\Models\ProviderProfile;
use App\Models\ProviderReview;
use App\Models\ProviderService;
use App\Models\Service;
use App\Models\User;
use App\Support\DemoDataContent as C;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class DemoDataException extends \RuntimeException
{
}

/**
 * Generates / removes the demo (pre-launch preview) data set: fully filled
 * customer and provider accounts, services, packages, schedules, work galleries
 * and reviews. Every account carries users.is_demo = true; relations cascade,
 * so purge() removes the whole set in one transaction.
 *
 * Demo accounts get an unguessable random password (nobody can log in as them
 * unless an admin sets a password), distinct review counts per provider and a
 * deterministic seed so a regenerated set looks the same.
 */
class DemoDataService
{
    public const EMAIL_DOMAIN = 'demo.tarak.test';
    public const MAX_PER_ROLE = 300;
    public const MAX_EXTRA_CUSTOMERS = 10000;
    private const SEED = 20261020;
    private const DAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

    /** @var array<string, bool> */
    private array $usedNames = [];

    /** @var array<string, list<string>> wide work photos per gender, used as cover banners */
    private array $covers = ['female' => [], 'male' => []];

    public function __construct(private DemoImagePack $images)
    {
    }

    /** @return array<string, mixed> */
    public function stats(): array
    {
        $base = fn () => User::withTrashed()->where('is_demo', true);
        $providerIds = $base()->where('role', User::ROLE_PROVIDER)->pluck('id');

        return [
            'customers' => $base()->where('role', User::ROLE_CUSTOMER)->count(),
            'providers' => $providerIds->count(),
            'reviews' => $providerIds->isEmpty() ? 0 : ProviderReview::whereIn('provider_user_id', $providerIds)->count(),
            'gallery_images' => (int) ProviderProfile::whereIn('user_id', $providerIds)->get(['gallery'])
                ->sum(fn ($p) => count($p->gallery ?? [])),
            'featured' => $providerIds->isEmpty() ? 0 : FeaturedPromotion::active()->placement(FeaturedPromotion::PLACEMENT_HOME)->whereIn('provider_user_id', $providerIds)->distinct()->count('provider_user_id'),
            'pack' => $this->images->inventory(),
            'pack_path' => $this->images->packPath(),
        ];
    }

    public function exists(): bool
    {
        return User::withTrashed()->where('is_demo', true)->exists();
    }

    /** @return array<string, mixed> stats after generation */
    public function generate(int $customerCount = 100, int $providerCount = 100): array
    {
        if ($customerCount < 0 || $providerCount < 0 || $customerCount > self::MAX_PER_ROLE || $providerCount > self::MAX_PER_ROLE) {
            throw new DemoDataException('Adetler 0 ile ' . self::MAX_PER_ROLE . ' arasında olmalıdır.');
        }
        if ($customerCount + $providerCount === 0) {
            throw new DemoDataException('En az bir müşteri veya hizmet veren oluşturulmalıdır.');
        }
        if ($this->exists()) {
            throw new DemoDataException('Demo veriler zaten mevcut. Yeniden oluşturmak için önce silin.');
        }

        $catalog = Service::query()->where('is_active', true)->get()->groupBy('category_id');
        $men = $catalog->get('cat-1', collect());
        $women = $catalog->get('cat-2', collect());
        if ($providerCount > 0 && ($men->isEmpty() || $women->isEmpty())) {
            throw new DemoDataException('Hizmet kataloğu boş; önce hizmet kataloğunu yükleyin.');
        }

        @set_time_limit(300);
        mt_srand(self::SEED);
        $this->usedNames = [];
        $hash = Hash::make(Str::random(48));
        $portraits = [
            'female' => $this->images->portraitUrls('women'),
            'male' => $this->images->portraitUrls('men'),
        ];
        $works = [
            'female' => $this->images->workUrls('women'),
            'male' => $this->images->workUrls('men'),
        ];
        $this->covers = [
            'female' => $this->images->coverUrls('women'),
            'male' => $this->images->coverUrls('men'),
        ];
        foreach ($portraits as $g => $list) {
            shuffle($portraits[$g]);
        }

        DB::transaction(function () use ($customerCount, $providerCount, $hash, $portraits, $works, $men, $women) {
            $cursor = ['female' => 0, 'male' => 0];
            $customerIds = $this->createCustomers($customerCount, $hash, $portraits, $cursor);
            $providerIds = $this->createProviders($providerCount, $hash, $portraits, $cursor, $works, $men, $women);
            $this->createReviews($providerIds, $customerIds);
            $this->createPromotions($providerIds);
        });

        return $this->stats();
    }

    /**
     * Adds more demo customers on top of the existing demo set (e.g. 5000, so the customer count is not
     * the same as the provider count). They are ordinary demo accounts: `users.is_demo = true`, so the
     * admin "Demo Verileri Sil" / purge() removes them with everything else, and they are counted by
     * the home statistics like the rest of the demo set. Inserted in bulk (a few seconds for 5000).
     *
     * @return array<string, mixed> stats after the insert
     */
    public function addCustomers(int $count): array
    {
        if ($count < 1 || $count > self::MAX_EXTRA_CUSTOMERS) {
            throw new DemoDataException('Adet 1 ile ' . self::MAX_EXTRA_CUSTOMERS . ' arasında olmalıdır.');
        }

        @set_time_limit(600);
        $existing = User::withTrashed()->where('is_demo', true)->where('role', User::ROLE_CUSTOMER)->get(['name', 'email']);
        // Continue the numbering after the highest existing "musteriNNN" so e-mails / phones stay unique.
        $offset = max(
            $existing->count(),
            (int) $existing->map(fn ($u) => (int) preg_replace('/\D/', '', strstr((string) $u->email, '@', true)))->max()
        );
        mt_srand(self::SEED + $offset);
        $this->usedNames = $existing->pluck('name')->flip()->map(fn () => true)->all();
        $hash = Hash::make(Str::random(48));
        $portraits = ['female' => $this->images->portraitUrls('women'), 'male' => $this->images->portraitUrls('men')];
        foreach ($portraits as $g => $list) {
            shuffle($portraits[$g]);
        }
        $cursor = ['female' => $offset, 'male' => $offset];
        $now = now();

        foreach (array_chunk(range(0, $count - 1), 500) as $chunk) {
            DB::transaction(function () use ($chunk, $offset, $hash, $portraits, &$cursor, $now) {
                $users = [];
                foreach ($chunk as $n) {
                    $i = $offset + $n;
                    $gender = $i % 2 === 0 ? 'female' : 'male';
                    [$first, $last] = $this->identity($gender);
                    // Joined at different times over the last four months, like real sign-ups.
                    $joined = $now->copy()->subDays(mt_rand(0, 120))->subSeconds(mt_rand(0, 86399));
                    $users[] = [
                        'role' => User::ROLE_CUSTOMER,
                        'first_name' => $first,
                        'last_name' => $last,
                        'name' => "$first $last",
                        'email' => sprintf('musteri%03d@%s', $i + 1, self::EMAIL_DOMAIN),
                        'phone' => sprintf('0599%07d', 1000001 + $i),
                        'password' => $hash,
                        'gender' => $gender,
                        'status' => 'active',
                        'is_demo' => true,
                        'avatar_url' => $this->avatarFor($gender, $portraits, $cursor, 1000 + $i),
                        'email_verified_at' => $joined,
                        'phone_verified_at' => $joined,
                        'created_at' => $joined,
                        'updated_at' => $joined,
                    ];
                }
                DB::table('users')->insert($users);

                $userIds = DB::table('users')->whereIn('email', array_column($users, 'email'))->pluck('id', 'email');
                $profiles = [];
                foreach ($users as $user) {
                    $profiles[] = [
                        'user_id' => $userIds[$user['email']],
                        'profile_completed' => true,
                        'birth_date' => Carbon::create(mt_rand(1978, 2004), mt_rand(1, 12), mt_rand(1, 28))->toDateString(),
                        'created_at' => $user['created_at'],
                        'updated_at' => $user['created_at'],
                    ];
                }
                DB::table('customer_profiles')->insert($profiles);

                $profileIds = DB::table('customer_profiles')->whereIn('user_id', $userIds->values())->pluck('id', 'user_id');
                $addresses = [];
                foreach ($profiles as $profile) {
                    $titles = ['Ev', 'İş'];
                    for ($a = 0, $total = mt_rand(1, 2); $a < $total; $a++) {
                        [$city, $district, $lat, $lng] = $this->place();
                        $addresses[] = [
                            'customer_profile_id' => $profileIds[$profile['user_id']],
                            'title' => $titles[$a],
                            'province' => $city,
                            'district' => $district,
                            'neighborhood' => C::NEIGHBORHOODS[array_rand(C::NEIGHBORHOODS)],
                            'street' => C::STREETS[array_rand(C::STREETS)],
                            'building_no' => (string) mt_rand(1, 80),
                            'apartment_no' => (string) mt_rand(1, 24),
                            'directions' => $a === 0 ? 'Zili çalmanız yeterli.' : 'Danışmaya haber verin.',
                            'latitude' => $lat,
                            'longitude' => $lng,
                            'is_default' => $a === 0,
                            'created_at' => $profile['created_at'],
                            'updated_at' => $profile['created_at'],
                        ];
                    }
                }
                DB::table('customer_addresses')->insert($addresses);
            });
        }

        return $this->stats();
    }

    /** @return array<string, int> what was removed */
    public function purge(): array
    {
        $removed = $this->stats();
        unset($removed['pack'], $removed['pack_path']);

        DB::transaction(function () {
            User::withTrashed()->where('is_demo', true)->forceDelete();
        });
        $this->images->purgeFiles();

        return $removed;
    }

    // ── Customers ───────────────────────────────────────────────────────────

    /** @return list<int> */
    private function createCustomers(int $count, string $hash, array $portraits, array &$cursor): array
    {
        $ids = [];
        for ($i = 0; $i < $count; $i++) {
            $gender = $i % 2 === 0 ? 'female' : 'male';
            [$first, $last] = $this->identity($gender);
            $user = User::create([
                'role' => User::ROLE_CUSTOMER,
                'first_name' => $first,
                'last_name' => $last,
                'name' => "$first $last",
                'email' => sprintf('musteri%03d@%s', $i + 1, self::EMAIL_DOMAIN),
                'phone' => sprintf('0599%07d', 1000001 + $i),
                'password' => $hash,
                'gender' => $gender,
                'status' => 'active',
                'is_demo' => true,
                'avatar_url' => $this->avatarFor($gender, $portraits, $cursor, 1000 + $i),
                'email_verified_at' => now(),
                'phone_verified_at' => now(),
            ]);
            $profile = CustomerProfile::create([
                'user_id' => $user->id,
                'profile_completed' => true,
                'birth_date' => Carbon::create(mt_rand(1978, 2004), mt_rand(1, 12), mt_rand(1, 28)),
            ]);
            $this->createAddresses($profile);
            $ids[] = $user->id;
        }

        return $ids;
    }

    private function createAddresses(CustomerProfile $profile): void
    {
        $titles = ['Ev', 'İş'];
        $count = mt_rand(1, 2);
        for ($n = 0; $n < $count; $n++) {
            [$city, $district, $lat, $lng] = $this->place();
            CustomerAddress::create([
                'customer_profile_id' => $profile->id,
                'title' => $titles[$n],
                'province' => $city,
                'district' => $district,
                'neighborhood' => C::NEIGHBORHOODS[array_rand(C::NEIGHBORHOODS)],
                'street' => C::STREETS[array_rand(C::STREETS)],
                'building_no' => (string) mt_rand(1, 80),
                'apartment_no' => (string) mt_rand(1, 24),
                'directions' => $n === 0 ? 'Zili çalmanız yeterli.' : 'Danışmaya haber verin.',
                'latitude' => $lat,
                'longitude' => $lng,
                'is_default' => $n === 0,
            ]);
        }
    }

    // ── Providers ───────────────────────────────────────────────────────────

    /** @return list<int> */
    private function createProviders(int $count, string $hash, array $portraits, array &$cursor, array $works, $men, $women): array
    {
        $ids = [];
        $document = $count > 0 ? $this->images->documentPlaceholderPath() : null;
        for ($i = 0; $i < $count; $i++) {
            $female = $i % 2 === 0;
            $gender = $female ? 'female' : 'male';
            [$first, $last] = $this->identity($gender);
            $user = User::create([
                'role' => User::ROLE_PROVIDER,
                'first_name' => $first,
                'last_name' => $last,
                'name' => "$first $last",
                'email' => sprintf('hizmetveren%03d@%s', $i + 1, self::EMAIL_DOMAIN),
                'phone' => sprintf('0599%07d', 2000001 + $i),
                'password' => $hash,
                'gender' => $gender,
                'status' => 'active',
                'is_demo' => true,
                'avatar_url' => $this->avatarFor($gender, $portraits, $cursor, 2000 + $i),
                'email_verified_at' => now(),
                'phone_verified_at' => now(),
            ]);

            [$city, $district, $lat, $lng] = $this->place();
            $experience = mt_rand(2, 28);
            $specialties = $female ? C::SPECIALTIES_FEMALE : C::SPECIALTIES_MALE;
            $specialty = $specialties[array_rand($specialties)];
            $workMode = ['venue', 'venue', 'both', 'both', 'both', 'mobile'][mt_rand(0, 5)];
            $pool = $works[$gender];
            $gallery = $this->pickGallery($pool);
            $cover = $this->covers[$gender] ? $this->covers[$gender][array_rand($this->covers[$gender])] : ($gallery[0] ?? null);
            if ($cover && !in_array($cover, $gallery, true) && $gallery) {
                $gallery[0] = $cover; // the cover is also the first work photo
            }
            $approvedAt = now()->subDays(mt_rand(20, 500));

            $profile = ProviderProfile::create([
                'user_id' => $user->id,
                'provider_type' => $female ? 'coiffeur' : 'barber',
                'work_mode' => $workMode,
                'business_name' => $this->salonName($female, $first, $last),
                'is_approved' => true,
                'identity_status' => 'APPROVED',
                'is_online' => mt_rand(1, 100) <= 62,
                'accepts_new_clients' => mt_rand(1, 100) <= 92,
                'service_radius_km' => $workMode === 'venue' ? 10 : mt_rand(8, 30),
                'experience_years' => $experience,
                'profile_completed' => true,
                'city' => $city,
                'district' => $district,
                'address_detail' => sprintf('%s %s No:%d Kat:%d', C::NEIGHBORHOODS[array_rand(C::NEIGHBORHOODS)], C::STREETS[array_rand(C::STREETS)], mt_rand(1, 90), mt_rand(1, 6)),
                'latitude' => $lat,
                'longitude' => $lng,
                'bio' => $this->bio($experience, $city, $specialty),
                'title' => ($female ? C::TITLES_FEMALE : C::TITLES_MALE)[mt_rand(0, 5)],
                'cover_url' => $cover,
                'gallery' => $gallery,
                'approved_at' => $approvedAt,
                'reviewed_at' => $approvedAt,
            ]);

            DB::table('wallets')->insert([
                'user_id' => $user->id,
                'balance' => 0,
                'currency' => 'TRY',
                'is_frozen' => false,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            ProviderDocument::create([
                'provider_profile_id' => $profile->id,
                'document_type' => [ProviderDocument::TYPE_DIPLOMA, ProviderDocument::TYPE_MASTER_CERTIFICATE, ProviderDocument::TYPE_JOURNEYMAN_CERTIFICATE][mt_rand(0, 2)],
                'original_name' => 'demo-belge.png',
                'storage_path' => $document,
                'mime_type' => 'image/png',
                'file_size' => $this->images->documentPlaceholderSize(),
                'status' => ProviderDocument::STATUS_APPROVED,
                'uploaded_at' => $approvedAt,
                'reviewed_at' => $approvedAt,
            ]);

            $services = $this->attachServices($profile, $female ? $women : $men, $female);
            $this->createPackages($profile, $services, $female);
            $this->createSchedule($profile);

            $ids[] = $user->id;
        }

        return $ids;
    }

    /** @return list<array{service: Service, price: float, duration: int}> */
    private function attachServices(ProviderProfile $profile, $catalog, bool $female): array
    {
        $all = $catalog->values()->all();
        shuffle($all);
        $take = $female ? mt_rand(5, 9) : mt_rand(3, 6);
        $chosen = array_slice($all, 0, min($take, count($all)));
        // Core services every barber offers.
        if (!$female) {
            foreach ([1, 2, 3] as $coreId) {
                $core = $catalog->firstWhere('id', $coreId);
                if ($core && !collect($chosen)->contains(fn ($s) => $s->id === $coreId)) {
                    $chosen[] = $core;
                }
            }
        }

        $result = [];
        foreach ($chosen as $service) {
            $price = round(((float) $service->base_price * mt_rand(80, 150) / 100) / 10) * 10;
            $duration = max(15, (int) $service->duration_minutes + [-15, 0, 0, 15][mt_rand(0, 3)]);
            ProviderService::create([
                'provider_profile_id' => $profile->id,
                'service_id' => $service->id,
                'custom_price' => $price,
                'custom_duration_minutes' => $duration,
                'is_active' => true,
            ]);
            $result[] = ['service' => $service, 'price' => (float) $price, 'duration' => $duration];
        }

        return $result;
    }

    private function createPackages(ProviderProfile $profile, array $services, bool $female): void
    {
        if (count($services) < 3) {
            return;
        }
        $titles = $female ? ['Gelin Paketi', 'Bakım Paketi', 'Renk & Bakım Paketi'] : ['Tam Bakım Paketi', 'Damat Paketi', 'Baba-Oğul Paketi'];
        $packageCount = mt_rand(0, 2);
        for ($n = 0; $n < $packageCount; $n++) {
            $items = array_slice($services, $n, mt_rand(2, 3));
            if (count($items) < 2) {
                continue;
            }
            $price = round(array_sum(array_column($items, 'price')) * 0.9 / 10) * 10;
            $package = ProviderPackage::create([
                'provider_profile_id' => $profile->id,
                'title' => $titles[$n % count($titles)],
                'description' => 'Tek randevuda birden fazla hizmeti avantajlı fiyatla alın.',
                'price' => $price,
                'duration_minutes' => array_sum(array_column($items, 'duration')),
                'is_active' => true,
                'sort_order' => $n,
            ]);
            foreach ($items as $order => $item) {
                DB::table('provider_package_items')->insert([
                    'provider_package_id' => $package->id,
                    'service_id' => $item['service']->id,
                    'sort_order' => $order,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        }
    }

    private function createSchedule(ProviderProfile $profile): void
    {
        $start = ['09:00:00', '09:30:00', '10:00:00'][mt_rand(0, 2)];
        $end = ['19:00:00', '20:00:00', '21:00:00'][mt_rand(0, 2)];
        $sundayOpen = mt_rand(1, 100) <= 35;
        foreach (self::DAYS as $day) {
            $enabled = $day === 'sunday' ? $sundayOpen : true;
            DB::table('provider_weekly_schedules')->insert([
                'provider_profile_id' => $profile->id,
                'day_of_week' => $day,
                'is_enabled' => $enabled,
                'start_time' => $enabled ? $start : null,
                'end_time' => $enabled ? $end : null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
        // Distinct days only: (provider, date) is unique.
        $offsets = range(10, 90);
        shuffle($offsets);
        foreach (array_slice($offsets, 0, mt_rand(0, 2)) as $offset) {
            DB::table('provider_closed_dates')->insert([
                'provider_profile_id' => $profile->id,
                'date' => now()->addDays($offset)->toDateString(),
                'reason' => ['Tatil', 'İzin'][mt_rand(0, 1)],
                'note' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    // ── Reviews ─────────────────────────────────────────────────────────────

    private function createReviews(array $providerIds, array $customerIds): int
    {
        $customerTotal = count($customerIds);
        if ($customerTotal === 0 || empty($providerIds)) {
            return 0;
        }
        $profiles = ProviderProfile::whereIn('user_id', $providerIds)->get(['user_id', 'provider_type'])->keyBy('user_id');

        // Every provider gets a different review count (1..N, capped by the customer pool).
        $counts = range(1, count($providerIds));
        shuffle($counts);

        $rows = [];
        $total = 0;
        foreach ($providerIds as $index => $providerId) {
            $reviewCount = min($counts[$index], $customerTotal);
            $quality = 3.35 + mt_rand(0, 160) / 100; // different Tarak average per provider
            $group = $profiles[$providerId]->provider_type === 'coiffeur' ? 'female' : 'male';

            $reviewers = $customerIds;
            shuffle($reviewers);
            foreach (array_slice($reviewers, 0, $reviewCount) as $customerId) {
                $rating = (int) max(1, min(5, round($quality + mt_rand(-120, 90) / 100)));
                $when = now()->subDays(mt_rand(1, 540))->subMinutes(mt_rand(0, 1400));
                $rows[] = [
                    'provider_user_id' => $providerId,
                    'customer_user_id' => $customerId,
                    'rating' => $rating,
                    'comment' => mt_rand(1, 100) <= 68 ? $this->reviewComment($group, $rating) : null,
                    'created_at' => $when,
                    'updated_at' => $when,
                ];
                $total++;
                if (count($rows) >= 500) {
                    ProviderReview::insert($rows);
                    $rows = [];
                }
            }
        }
        if ($rows) {
            ProviderReview::insert($rows);
        }

        return $total;
    }

    // ── Öne çıkarma ─────────────────────────────────────────────────────────

    /**
     * About one provider in four is "öne çıkan" so the Öne Çıkan Profesyoneller
     * section is populated (running periods with different days left), plus a few
     * ended ones to show how a profile leaves the section. Rows are admin gifts:
     * no wallet movement, removed with the user (cascade).
     */
    private function createPromotions(array $providerIds): int
    {
        if (empty($providerIds)) {
            return 0;
        }
        $packages = FeaturedPackage::query()->placement(FeaturedPromotion::PLACEMENT_HOME)->where('is_active', true)->orderBy('duration_days')->get();
        if ($packages->isEmpty()) {
            return 0;
        }

        $ids = $providerIds;
        shuffle($ids);
        $featured = array_slice($ids, 0, max(1, (int) round(count($ids) / 4)));
        $rows = [];
        foreach ($featured as $position => $providerId) {
            $package = $packages[$position % $packages->count()];
            $expired = $position % 9 === 8; // a few already finished
            $elapsed = $expired
                ? $package->duration_days + mt_rand(1, 20) // ended in the past
                : mt_rand(0, max(0, $package->duration_days - 1)); // somewhere inside the period
            $start = now()->subDays($elapsed)->subMinutes(mt_rand(0, 600));
            $rows[] = [
                'provider_user_id' => $providerId,
                'featured_package_id' => $package->id,
                'package_name' => $package->name,
                'duration_days' => $package->duration_days,
                'price_paid' => 0,
                'source' => 'admin',
                'starts_at' => $start,
                'ends_at' => $start->copy()->addDays($package->duration_days),
                'note' => 'Demo',
                'created_at' => $start,
                'updated_at' => $start,
            ];
        }
        FeaturedPromotion::insert($rows);

        // A handful of running "Liste Reklamı" periods so the sponsored slots of the provider lists
        // are populated in demo environments (same admin-gift shape; removed with the user).
        $listingPackages = FeaturedPackage::query()->placement(FeaturedPromotion::PLACEMENT_LISTING)->where('is_active', true)->orderBy('duration_days')->get();
        if ($listingPackages->isNotEmpty()) {
            $sponsored = array_slice($ids, 0, max(1, (int) round(count($ids) / 6)));
            shuffle($sponsored);
            $listingRows = [];
            foreach ($sponsored as $position => $providerId) {
                $package = $listingPackages[$position % $listingPackages->count()];
                $start = now()->subDays(mt_rand(0, max(0, $package->duration_days - 1)))->subMinutes(mt_rand(0, 600));
                $listingRows[] = [
                    'provider_user_id' => $providerId,
                    'placement' => FeaturedPromotion::PLACEMENT_LISTING,
                    'featured_package_id' => $package->id,
                    'package_name' => $package->name,
                    'duration_days' => $package->duration_days,
                    'price_paid' => 0,
                    'source' => 'admin',
                    'starts_at' => $start,
                    'ends_at' => $start->copy()->addDays($package->duration_days),
                    'note' => 'Demo',
                    'created_at' => $start,
                    'updated_at' => $start,
                ];
            }
            FeaturedPromotion::insert($listingRows);
        }

        return count($rows);
    }

    private function reviewComment(string $group, int $rating): string
    {
        $details = $group === 'female' ? C::REVIEW_DETAILS_FEMALE : C::REVIEW_DETAILS_MALE;
        $detail = $details[array_rand($details)];

        if ($rating >= 5) {
            $parts = [];
            if (mt_rand(0, 1)) {
                $parts[] = C::REVIEW_OPENINGS_POSITIVE[array_rand(C::REVIEW_OPENINGS_POSITIVE)];
            }
            $parts[] = $detail;
            if (mt_rand(1, 100) <= 60) {
                $parts[] = C::REVIEW_CLOSINGS_POSITIVE[array_rand(C::REVIEW_CLOSINGS_POSITIVE)];
            }

            return implode(' ', $parts);
        }
        if ($rating === 4) {
            return $detail . (mt_rand(0, 1) ? ' ' . C::REVIEW_CLOSINGS_POSITIVE[array_rand(C::REVIEW_CLOSINGS_POSITIVE)] : '');
        }
        if ($rating === 3) {
            return C::REVIEW_MID[array_rand(C::REVIEW_MID)];
        }

        return C::REVIEW_LOW[array_rand(C::REVIEW_LOW)];
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /** @return array{0:string,1:string} */
    private function identity(string $gender): array
    {
        $names = $gender === 'female' ? C::FEMALE_NAMES : C::MALE_NAMES;
        for ($attempt = 0; $attempt < 200; $attempt++) {
            $first = $names[array_rand($names)];
            $last = C::SURNAMES[array_rand(C::SURNAMES)];
            $key = "$first $last";
            if (!isset($this->usedNames[$key])) {
                $this->usedNames[$key] = true;

                return [$first, $last];
            }
        }

        return [$names[array_rand($names)], C::SURNAMES[array_rand(C::SURNAMES)]];
    }

    /** @return array{0:string,1:string,2:float,3:float} city, district, lat, lng */
    private function place(): array
    {
        $total = array_sum(array_column(C::PLACES, 'weight'));
        $roll = mt_rand(1, $total);
        foreach (C::PLACES as $city => $info) {
            $roll -= $info['weight'];
            if ($roll <= 0) {
                break;
            }
        }
        $district = array_rand($info['districts']);
        [$lat, $lng] = $info['districts'][$district];

        return [$city, $district, round($lat + mt_rand(-120, 120) / 10000, 6), round($lng + mt_rand(-120, 120) / 10000, 6)];
    }

    private function salonName(bool $female, string $first, string $last): string
    {
        $patterns = $female ? C::SALON_PATTERNS_FEMALE : C::SALON_PATTERNS_MALE;

        return str_replace(['{n}', '{s}'], [$first, $last], $patterns[array_rand($patterns)]);
    }

    private function bio(int $experience, string $city, string $specialty): string
    {
        $intro = C::BIO_INTROS[array_rand(C::BIO_INTROS)];
        $intro = str_replace(['{exp}', '{city}', '{specialty}'], [(string) $experience, $city, $specialty], $intro);

        return $intro . ' ' . C::BIO_MIDDLES[array_rand(C::BIO_MIDDLES)] . ' ' . C::BIO_CLOSINGS[array_rand(C::BIO_CLOSINGS)];
    }

    /** @param list<string> $pool @return list<string> */
    private function pickGallery(array $pool): array
    {
        if (!$pool) {
            return [];
        }
        shuffle($pool);

        return array_slice($pool, 0, min(count($pool), mt_rand(6, 14)));
    }

    /** @param array<string, list<string>> $portraits @param array<string, int> $cursor */
    private function avatarFor(string $gender, array $portraits, array &$cursor, int $seed): string
    {
        $list = $portraits[$gender];
        if (!$list) {
            return $this->images->placeholderAvatarUrl($seed);
        }

        return $list[$cursor[$gender]++ % count($list)];
    }
}

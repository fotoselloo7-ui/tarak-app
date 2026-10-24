<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\ProcessAdminBroadcast;
use App\Models\AdminBroadcast;
use App\Services\AdminBroadcastAudience;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/** Admin-only, auditable platform announcement & sponsorship composer. */
class AdminBroadcastController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = AdminBroadcast::query()->orderByDesc('id');
        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }
        $page = $query->paginate(min(50, max(1, (int) $request->query('per_page', 12))));
        return response()->json([
            'success' => true,
            'data' => $page->items(),
            'meta' => [
                'total' => $page->total(),
                'page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'completed' => AdminBroadcast::where('status', AdminBroadcast::COMPLETED)->count(),
                'scheduled' => AdminBroadcast::where('status', AdminBroadcast::QUEUED)->count(),
                'notifications_created' => (int) AdminBroadcast::sum('notifications_created'),
                'fcm_ready' => (bool) (config('fcm.enabled') && config('fcm.project_id') && config('fcm.credentials_path') && is_file(config('fcm.credentials_path'))),
            ],
        ]);
    }

    public function estimate(Request $request, AdminBroadcastAudience $audience): JsonResponse
    {
        $data = $request->validate($this->audienceRules());
        return response()->json(['success' => true, 'data' => $audience->estimate($data)]);
    }

    public function store(Request $request, AdminBroadcastAudience $audience): JsonResponse
    {
        $data = $request->validate($this->rules());
        $data = $this->prepare($data);
        $estimate = $audience->estimate($data);
        $broadcast = AdminBroadcast::create($data + [
            'created_by' => $request->user()->id,
            'status' => AdminBroadcast::DRAFT,
            'estimated_recipients' => $estimate['eligible'],
        ]);
        return response()->json(['success' => true, 'data' => $broadcast, 'estimate' => $estimate], 201);
    }

    public function update(Request $request, AdminBroadcast $broadcast, AdminBroadcastAudience $audience): JsonResponse
    {
        if ($broadcast->status !== AdminBroadcast::DRAFT) {
            return response()->json(['success' => false, 'message' => 'Yalnızca taslak düzenlenebilir.'], 409);
        }
        $data = $this->prepare($request->validate($this->rules()));
        $broadcast->fill($data);
        $broadcast->estimated_recipients = $audience->estimate($data)['eligible'];
        $broadcast->save();
        return response()->json(['success' => true, 'data' => $broadcast]);
    }

    public function send(Request $request, AdminBroadcast $broadcast, AdminBroadcastAudience $audience): JsonResponse
    {
        $request->validate(['confirmation' => ['required', 'in:SEND']]);
        $dispatched = DB::transaction(function () use ($broadcast, $audience) {
            $broadcast = AdminBroadcast::whereKey($broadcast->id)->lockForUpdate()->firstOrFail();
            if (!in_array($broadcast->status, [AdminBroadcast::DRAFT, AdminBroadcast::PAUSED, AdminBroadcast::FAILED], true)) {
                return false;
            }
            $estimate = $audience->estimate($broadcast->toArray());
            if ($estimate['eligible'] === 0) {
                throw ValidationException::withMessages(['audience' => ['Seçili hedef kitlede izinli ve aktif alıcı bulunamadı.']]);
            }
            $broadcast->update([
                'status' => AdminBroadcast::QUEUED,
                'estimated_recipients' => $estimate['eligible'],
                'scheduled_at' => null,
                'failure_message' => null,
                'last_enqueued_at' => now(),
            ]);
            return true;
        });
        if (!$dispatched) {
            return response()->json(['success' => false, 'message' => 'Bu gönderim zaten devam ediyor veya tamamlandı.'], 409);
        }
        ProcessAdminBroadcast::dispatch($broadcast->id)->onQueue('push');
        return response()->json(['success' => true, 'message' => 'Bildirim kuyruğa alındı.', 'data' => $broadcast->fresh()]);
    }

    public function schedule(Request $request, AdminBroadcast $broadcast, AdminBroadcastAudience $audience): JsonResponse
    {
        $data = $request->validate([
            'scheduled_at' => ['required', 'date', 'after:now'],
        ]);
        $changed = DB::transaction(function () use ($broadcast, $audience, $data) {
            $current = AdminBroadcast::whereKey($broadcast->id)->lockForUpdate()->firstOrFail();
            if ($current->status !== AdminBroadcast::DRAFT) {
                return false;
            }
            $estimate = $audience->estimate($current->toArray());
            if (!$estimate['eligible']) {
                throw ValidationException::withMessages(['audience' => ['Seçili hedef kitlede alıcı bulunamadı.']]);
            }
            $current->update([
                'status' => AdminBroadcast::QUEUED,
                'scheduled_at' => $data['scheduled_at'],
                'estimated_recipients' => $estimate['eligible'],
                'last_enqueued_at' => now(),
            ]);
            return true;
        });
        if (!$changed) {
            return response()->json(['success' => false, 'message' => 'Yalnızca taslak planlanabilir.'], 409);
        }
        ProcessAdminBroadcast::dispatch($broadcast->id)->onQueue('push')->delay($data['scheduled_at']);
        return response()->json(['success' => true, 'data' => $broadcast->fresh()]);
    }

    public function pause(AdminBroadcast $broadcast): JsonResponse
    {
        $updated = AdminBroadcast::whereKey($broadcast->id)
            ->whereIn('status', [AdminBroadcast::QUEUED, AdminBroadcast::SENDING])
            ->update(['status' => AdminBroadcast::PAUSED]);
        return response()->json(['success' => (bool) $updated, 'data' => $broadcast->fresh()]);
    }

    public function cancel(AdminBroadcast $broadcast): JsonResponse
    {
        $updated = AdminBroadcast::whereKey($broadcast->id)
            ->whereIn('status', [AdminBroadcast::DRAFT, AdminBroadcast::QUEUED, AdminBroadcast::SENDING, AdminBroadcast::PAUSED, AdminBroadcast::FAILED])
            ->update(['status' => AdminBroadcast::CANCELLED, 'finished_at' => now()]);
        return response()->json(['success' => (bool) $updated, 'data' => $broadcast->fresh()]);
    }

    public function test(Request $request, NotificationService $notifications): JsonResponse
    {
        $data = $this->prepare($request->validate($this->rules()));
        $user = $request->user();
        $result = $notifications->notifyUser(
            $user->id,
            'ADMIN_ANNOUNCEMENT',
            '[TEST] ' . $data['title'],
            $data['body'],
            'ADMIN_BROADCAST',
            null,
            $data['action_url'] ?? null,
            ['test' => true, 'kind' => $data['kind']],
            'ADMIN_BROADCAST_TEST:' . Str::uuid()->toString()
        );
        return response()->json(['success' => true, 'message' => 'Test yalnızca yönetici hesabına gönderildi.', 'data' => ['notification_id' => $result?->id]]);
    }

    private function audienceRules(): array
    {
        return [
            'kind' => ['required', 'in:system,campaign,sponsored'],
            'audience' => ['required', 'in:all,customers,providers'],
            'province' => ['nullable', 'string', 'max:120'],
            'district' => ['nullable', 'string', 'max:120'],
        ];
    }

    private function rules(): array
    {
        return $this->audienceRules() + [
            'title' => ['required', 'string', 'min:3', 'max:100'],
            'body' => ['required', 'string', 'min:5', 'max:240'],
            'sponsor_name' => ['nullable', 'string', 'max:120'],
            'action_url' => ['nullable', 'string', 'max:255', 'regex:~^/(?!/)[a-zA-Z0-9_./?&=%#-]*$~'],
        ];
    }

    private function prepare(array $data): array
    {
        $data['province'] = trim((string) ($data['province'] ?? '')) ?: null;
        $data['district'] = $data['province'] ? (trim((string) ($data['district'] ?? '')) ?: null) : null;
        $data['title'] = trim($data['title']);
        $data['body'] = trim($data['body']);
        $data['sponsor_name'] = $data['kind'] === 'sponsored' ? (trim((string) ($data['sponsor_name'] ?? '')) ?: null) : null;
        $data['action_url'] = $data['action_url'] ?? null;
        if ($data['kind'] === 'sponsored' && !$data['sponsor_name']) {
            throw ValidationException::withMessages(['sponsor_name' => ['Sponsorlu bildirim için marka adı zorunludur.']]);
        }
        return $data;
    }
}

<?php

namespace App\Jobs;

use App\Models\AdminBroadcast;
use App\Models\UserNotification;
use App\Services\AdminBroadcastAudience;
use App\Services\NotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Small, repeatable batches so large audiences do not exceed PHP/cPanel
 * worker timeouts. NotificationService's deterministic key prevents duplicates.
 */
class ProcessAdminBroadcast implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $timeout = 120;
    public array $backoff = [15, 60, 180];

    public function __construct(public int $broadcastId)
    {
        $this->onQueue('push');
    }

    public function handle(AdminBroadcastAudience $audiences, NotificationService $notifications): void
    {
        $broadcast = AdminBroadcast::find($this->broadcastId);
        if (!$broadcast || !in_array($broadcast->status, [AdminBroadcast::QUEUED, AdminBroadcast::SENDING], true)) {
            return;
        }

        if ($broadcast->scheduled_at && $broadcast->scheduled_at->isFuture()) {
            self::dispatch($broadcast->id)->onQueue('push')->delay($broadcast->scheduled_at);
            return;
        }

        $broadcast->update([
            'status' => AdminBroadcast::SENDING,
            'started_at' => $broadcast->started_at ?: now(),
            'failure_message' => null,
        ]);

        $recipients = $audiences->query($broadcast)
            ->where('users.id', '>', $broadcast->last_user_id)
            ->orderBy('users.id')
            ->limit(80)
            ->get(['users.id']);

        if ($recipients->isEmpty()) {
            $broadcast->update(['status' => AdminBroadcast::COMPLETED, 'finished_at' => now()]);
            return;
        }

        $processed = 0;
        $created = 0;
        $cursor = (int) $broadcast->last_user_id;

        foreach ($recipients as $user) {
            // Pause/cancel requests take effect before the next recipient.
            $current = AdminBroadcast::find($broadcast->id);
            if (!$current || $current->status !== AdminBroadcast::SENDING) {
                break;
            }

            $key = "ADMIN_BROADCAST:{$broadcast->id}:{$user->id}";
            $already = UserNotification::where('idempotency_key', $key)->exists();
            $title = $broadcast->kind === 'sponsored' ? 'Sponsorlu · ' . $broadcast->title : $broadcast->title;
            $notification = $notifications->notifyUser(
                $user->id,
                $broadcast->kind === 'system' ? 'ADMIN_ANNOUNCEMENT' : 'ADMIN_CAMPAIGN',
                $title,
                $broadcast->body,
                'ADMIN_BROADCAST',
                $broadcast->id,
                $broadcast->action_url,
                ['kind' => $broadcast->kind, 'sponsor' => $broadcast->sponsor_name],
                $key
            );
            if ($notification && !$already) {
                $created++;
            }
            $processed++;
            $cursor = (int) $user->id;
        }

        // Never advance the cursor before all messages in the batch are safely stored.
        if ($processed > 0) {
            AdminBroadcast::whereKey($broadcast->id)->update([
                'last_user_id' => $cursor,
                'processed_recipients' => \Illuminate\Support\Facades\DB::raw('processed_recipients + ' . $processed),
                'notifications_created' => \Illuminate\Support\Facades\DB::raw('notifications_created + ' . $created),
                'last_enqueued_at' => now(),
            ]);
        }

        $broadcast->refresh();
        if ($broadcast->status === AdminBroadcast::SENDING) {
            self::dispatch($broadcast->id)->onQueue('push');
        }
    }

    public function failed(?\Throwable $exception): void
    {
        Log::error('Admin broadcast batch exhausted retries', [
            'broadcast_id' => $this->broadcastId,
            'error_type' => $exception ? get_class($exception) : null,
        ]);
        AdminBroadcast::whereKey($this->broadcastId)
            ->whereIn('status', [AdminBroadcast::QUEUED, AdminBroadcast::SENDING])
            ->update(['status' => AdminBroadcast::FAILED, 'failure_message' => 'Kuyruk işlemi başarısız oldu. Yönetici kontrolü gerekiyor.']);
    }
}

<?php

namespace App\Jobs;

use App\Services\PaytrRefundService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessPaytrRefund implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public array $backoff = [5, 15, 30];

    public int $refundId;

    /**
     * Create a new job instance.
     */
    public function __construct(int $refundId)
    {
        $this->refundId = $refundId;
        $this->onQueue('default');
    }

    /**
     * Execute the job.
     */
    public function handle(PaytrRefundService $refundService): void
    {
        $refundService->processRefund($this->refundId);
    }

    /**
     * Handle job permanent failure without leaking sensitive payment data.
     */
    public function failed(?\Throwable $exception): void
    {
        \Illuminate\Support\Facades\Log::error('ProcessPaytrRefund job permanently failed', [
            'refund_id' => $this->refundId,
            'error' => $exception?->getMessage(),
        ]);
    }
}

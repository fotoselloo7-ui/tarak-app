<?php

namespace App\Console\Commands;

use App\Services\BirthdayAssistantService;
use Illuminate\Console\Command;

class SendBirthdayGreetingsCommand extends Command
{
    protected $signature = 'birthdays:send-greetings';

    protected $description = 'Send scheduled opt-in birthday greetings from businesses to past customers';

    public function handle(BirthdayAssistantService $service): int
    {
        $result = $service->sendDueGreetings();
        $this->info("Birthday greetings processed: sent={$result['sent']} skipped={$result['skipped']}");

        return self::SUCCESS;
    }
}

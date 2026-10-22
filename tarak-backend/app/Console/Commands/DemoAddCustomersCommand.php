<?php

namespace App\Console\Commands;

use App\Services\DemoDataException;
use App\Services\DemoDataService;
use Illuminate\Console\Command;

class DemoAddCustomersCommand extends Command
{
    protected $signature = 'demo:add-customers {count=5000 : Number of extra demo customers}';
    protected $description = 'Add more demo customers on top of the demo set (flagged is_demo, removed by demo:purge / the admin "Demo Verileri Sil")';

    public function handle(DemoDataService $demo): int
    {
        try {
            $stats = $demo->addCustomers((int) $this->argument('count'));
        } catch (DemoDataException $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }

        $this->info(sprintf('Demo veri: toplam %d müşteri, %d hizmet veren.', $stats['customers'], $stats['providers']));

        return self::SUCCESS;
    }
}

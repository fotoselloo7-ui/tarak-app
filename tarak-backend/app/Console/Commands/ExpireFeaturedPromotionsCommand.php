<?php

namespace App\Console\Commands;

use App\Services\FeaturedPromotionService;
use Illuminate\Console\Command;

class ExpireFeaturedPromotionsCommand extends Command
{
    protected $signature = 'featured:expire';

    protected $description = 'Tell providers whose öne çıkarma period has ended (the public section already hides them by date)';

    public function handle(FeaturedPromotionService $featured): int
    {
        $count = $featured->expireDue();
        $this->info("Öne çıkarma süresi dolan {$count} hizmet veren bilgilendirildi.");

        return self::SUCCESS;
    }
}

<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProviderScheduleResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'day' => $this->day_of_week,
            'day_of_week' => $this->day_of_week,
            'enabled' => (bool) $this->is_enabled,
            'is_enabled' => (bool) $this->is_enabled,
            'start_time' => $this->start_time ? substr($this->start_time, 0, 5) : '09:00',
            'end_time' => $this->end_time ? substr($this->end_time, 0, 5) : '19:00',
            'breaks' => $this->breaks ? $this->breaks->map(function ($brk) {
                return [
                    'id' => (string) $brk->id,
                    'start_time' => substr($brk->start_time, 0, 5),
                    'end_time' => substr($brk->end_time, 0, 5),
                ];
            }) : [],
        ];
    }
}

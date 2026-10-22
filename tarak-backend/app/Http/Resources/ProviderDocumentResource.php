<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProviderDocumentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'document_type' => $this->document_type,
            'type' => strtolower($this->document_type), // Frontend compatibility alias
            'original_name' => $this->original_name,
            'name' => $this->original_name, // Alias
            'mime_type' => $this->mime_type,
            'file_size' => (int) $this->file_size,
            'status' => $this->status,
            'rejection_reason' => $this->rejection_reason,
            'uploaded_at' => $this->uploaded_at?->toISOString(),
            'reviewed_at' => $this->reviewed_at?->toISOString(),
        ];
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ServiceCategoryResource;
use App\Http\Resources\ServiceResource;
use App\Models\Service;
use App\Models\ServiceCategory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ServiceCatalogController extends Controller
{
    /**
     * List active service categories with active services.
     */
    public function categories(): JsonResponse
    {
        $categories = ServiceCategory::where('is_active', true)
            ->with(['services' => function ($q) {
                $q->where('is_active', true)->orderBy('sort_order');
            }])
            ->orderBy('sort_order')
            ->get();

        return response()->json([
            'success' => true,
            'data' => ServiceCategoryResource::collection($categories),
        ]);
    }

    /**
     * List active services with optional category filter.
     */
    public function services(Request $request): JsonResponse
    {
        $query = Service::where('is_active', true)->orderBy('sort_order');

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->input('category_id'));
        }

        $services = $query->get();

        return response()->json([
            'success' => true,
            'data' => ServiceResource::collection($services),
        ]);
    }
}

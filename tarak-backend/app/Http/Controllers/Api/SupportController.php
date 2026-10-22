<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SupportTicket;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SupportController extends Controller
{
    private const CATEGORIES = ['general', 'account', 'appointment', 'instant', 'payment', 'refund', 'dispute', 'provider', 'security'];

    /**
     * Public: create a support ticket (contact form). Works for guests and
     * authenticated users; if authenticated, the ticket is linked to the user.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:160'],
            'category' => ['nullable', 'string', 'in:' . implode(',', self::CATEGORIES)],
            'subject' => ['required', 'string', 'max:160'],
            'message' => ['required', 'string', 'max:4000'],
        ]);

        $ticket = SupportTicket::create([
            // Public route: link the user if a valid bearer token is present.
            'user_id' => auth('sanctum')->user()?->id,
            'name' => $validated['name'],
            'email' => $validated['email'],
            'category' => $validated['category'] ?? 'general',
            'subject' => $validated['subject'],
            'message' => $validated['message'],
            'status' => SupportTicket::STATUS_OPEN,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Destek talebiniz alındı. En kısa sürede dönüş yapacağız.',
            'data' => ['id' => $ticket->id, 'status' => $ticket->status],
        ], 201);
    }

    /**
     * Admin: list support tickets.
     */
    public function index(Request $request): JsonResponse
    {
        $tickets = SupportTicket::query()
            ->when($request->query('status'), fn ($q, $s) => $q->where('status', $s))
            ->latest()
            ->limit(200)
            ->get();

        return response()->json(['success' => true, 'data' => $tickets]);
    }

    /**
     * Admin: update ticket status / note.
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:OPEN,IN_PROGRESS,RESOLVED,CLOSED'],
            'admin_note' => ['nullable', 'string', 'max:2000'],
        ]);

        $ticket = SupportTicket::query()->find($id);
        if (! $ticket) {
            return response()->json(['success' => false, 'message' => 'Talep bulunamadı.'], 404);
        }

        $ticket->update([
            'status' => $validated['status'],
            'admin_note' => $validated['admin_note'] ?? $ticket->admin_note,
            'handled_by' => $request->user()->id,
        ]);

        return response()->json(['success' => true, 'message' => 'Talep güncellendi.', 'data' => $ticket]);
    }
}

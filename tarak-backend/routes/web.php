<?php

use App\Http\Controllers\Web\BusinessDirectoryWebController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/isletmeler', [BusinessDirectoryWebController::class, 'index']);
Route::get('/isletme/{slug}', [BusinessDirectoryWebController::class, 'show'])->where('slug', '[A-Za-z0-9\-]+');
Route::get('/sitemap.xml', [BusinessDirectoryWebController::class, 'sitemap']);

Route::any('/payment-result/success', function () {
    return response('Payment redirect received. Payment state is determined exclusively by PayTR server callback.', 200);
});

Route::any('/payment-result/fail', function () {
    return response('Payment redirect received. Payment state is determined exclusively by PayTR server callback.', 200);
});

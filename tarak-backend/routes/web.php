<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::any('/payment-result/success', function () {
    return response('Payment redirect received. Payment state is determined exclusively by PayTR server callback.', 200);
});

Route::any('/payment-result/fail', function () {
    return response('Payment redirect received. Payment state is determined exclusively by PayTR server callback.', 200);
});

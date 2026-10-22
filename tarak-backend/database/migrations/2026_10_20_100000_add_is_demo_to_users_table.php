<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Marks demo/preview accounts (generated from the admin panel or `demo:seed`).
        // Everything hanging off a user (profiles, services, reviews...) cascades, so
        // deleting the flagged users removes the whole demo data set in one go.
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_demo')->default(false)->after('status')->index();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['is_demo']);
            $table->dropColumn('is_demo');
        });
    }
};

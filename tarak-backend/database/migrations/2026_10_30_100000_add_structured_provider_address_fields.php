<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('provider_profiles', function (Blueprint $table) {
            $table->string('neighborhood', 150)->nullable()->after('district');
            $table->string('street', 200)->nullable()->after('neighborhood');
            $table->string('building_no', 30)->nullable()->after('street');
        });
    }

    public function down(): void
    {
        Schema::table('provider_profiles', function (Blueprint $table) {
            $table->dropColumn(['neighborhood', 'street', 'building_no']);
        });
    }
};

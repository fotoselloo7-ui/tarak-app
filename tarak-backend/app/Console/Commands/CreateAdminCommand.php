<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;

/**
 * Creates a real administrator account on a fresh production database (the production SQL contains no users and the
 * development seeder never runs in production). The password is asked with a hidden prompt, is never an argument or an
 * option (so it is not stored in the shell history) and is never printed.
 */
class CreateAdminCommand extends Command
{
    protected $signature = 'app:create-admin
                            {--email= : Yönetici e-posta adresi}
                            {--name= : Ad Soyad}
                            {--phone= : İsteğe bağlı telefon (+905XXXXXXXXX)}';

    protected $description = 'Canlıda ilk yönetici (ADMIN) hesabını oluşturur; şifre gizli istemle sorulur';

    public function handle(): int
    {
        $email = strtolower(trim((string) ($this->option('email') ?: $this->ask('E-posta'))));
        $name = trim((string) ($this->option('name') ?: $this->ask('Ad Soyad', 'Yönetici')));
        $rawPhone = trim((string) ($this->option('phone') ?: $this->ask('Telefon (+905XXXXXXXXX, boş bırakılabilir)', '')));
        $phone = $rawPhone === '' ? null : User::normalizePhone($rawPhone);

        $password = (string) $this->secret('Şifre (en az 12 karakter)');
        $confirmation = (string) $this->secret('Şifre (tekrar)');

        $validator = Validator::make(
            ['email' => $email, 'name' => $name, 'phone' => $phone, 'password' => $password, 'password_confirmation' => $confirmation],
            [
                'email' => ['required', 'email:rfc', 'max:100', 'unique:users,email'],
                'name' => ['required', 'string', 'min:2', 'max:100'],
                'phone' => ['nullable', 'regex:/^\+905\d{9}$/', 'unique:users,phone'],
                'password' => ['required', 'string', 'min:12', 'max:128', 'confirmed'],
            ],
            ['phone.regex' => 'Telefon +905XXXXXXXXX biçiminde olmalı.']
        );

        if ($rawPhone !== '' && $phone === null) {
            $this->error('Telefon biçimi geçersiz.');

            return self::FAILURE;
        }
        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $message) {
                $this->error($message);
            }

            return self::FAILURE;
        }

        $parts = preg_split('/\s+/', $name, 2) ?: [$name];
        $user = User::create([
            'role' => User::ROLE_ADMIN,
            'first_name' => $parts[0],
            'last_name' => $parts[1] ?? 'Yönetici',
            'name' => $name,
            'email' => $email,
            'phone' => $phone,
            'password' => $password, // hashed by the model cast
            'status' => 'active',
            'email_verified_at' => now(),
            'phone_verified_at' => $phone ? now() : null,
        ]);

        $this->info("Yönetici hesabı oluşturuldu (id {$user->id}, {$email}). Giriş: /admin");

        return self::SUCCESS;
    }
}

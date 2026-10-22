<?php

namespace App\Http\Requests;

class LoginRequest extends BaseFormRequest
{
    public function rules(): array
    {
        return [
            'login' => ['nullable', 'string'],
            'email' => ['nullable', 'string'],
            'phone' => ['nullable', 'string'],
            'password' => ['required', 'string'],
        ];
    }

    public function messages(): array
    {
        return [
            'password.required' => 'Şifre alanı zorunludur.',
        ];
    }
}

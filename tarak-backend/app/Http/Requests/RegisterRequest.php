<?php

namespace App\Http\Requests;

use App\Models\User;

class RegisterRequest extends BaseFormRequest
{
    protected function prepareForValidation(): void
    {
        $rawPhone = $this->input('phone');
        $normalizedPhone = null;
        if (!empty($rawPhone)) {
            $normalizedPhone = User::normalizePhone($rawPhone) ?? 'INVALID_PHONE_FORMAT';
        }

        $rawEmail = $this->input('email');
        $normalizedEmail = !empty($rawEmail) ? strtolower(trim($rawEmail)) : null;

        $this->merge([
            'phone' => $normalizedPhone,
            'email' => $normalizedEmail,
        ]);
    }

    public function rules(): array
    {
        return [
            'first_name' => ['required', 'string', 'max:50'],
            'last_name' => ['required', 'string', 'max:50'],
            'email' => ['nullable', 'required_without:phone', 'email:rfc', 'max:100', 'unique:users,email'],
            'phone' => ['nullable', 'required_without:email', 'regex:/^\+905\d{9}$/', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'role' => ['required', 'string', 'in:CUSTOMER,PROVIDER'],
            'gender' => ['nullable', 'string', 'in:male,female,other,unspecified'],
            'business_name' => ['nullable', 'string', 'max:100'],
            'provider_type' => ['nullable', 'string', 'max:50'],
            'email_verification_token' => ['nullable', 'string', 'size:64', 'regex:/^[a-f0-9]+$/'],
            'phone_verification_token' => ['nullable', 'string', 'size:64', 'regex:/^[a-f0-9]+$/'],
            'social_prefill_token' => ['nullable', 'string', 'size:64', 'regex:/^[a-f0-9]+$/'],
            'accept_terms' => ['required', 'accepted'],
            'accept_kvkk' => ['required', 'accepted'],
            'marketing_consent' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'first_name.required' => 'Ad alanı zorunludur.',
            'last_name.required' => 'Soyad alanı zorunludur.',
            'email.required_without' => 'E-posta veya telefon numarasından en az biri girilmelidir.',
            'email.email' => 'Geçerli bir e-posta adresi giriniz.',
            'email.unique' => 'Bu e-posta adresi zaten kullanımda.',
            'phone.required_without' => 'Telefon numarası veya e-posta adresinden en az biri girilmelidir.',
            'phone.regex' => 'Geçerli bir cep telefonu numarası giriniz (örn: 05XXXXXXXXX).',
            'phone.unique' => 'Bu telefon numarası zaten kullanımda.',
            'password.required' => 'Şifre alanı zorunludur.',
            'password.min' => 'Şifre en az 8 karakter olmalıdır.',
            'password.confirmed' => 'Şifre onayı eşleşmiyor.',
            'role.required' => 'Rol seçimi zorunludur.',
            'role.in' => 'Geçersiz rol seçimi. Yalnızca CUSTOMER veya PROVIDER olarak kayıt olunabilir.',
            'accept_terms.accepted' => 'Kullanım koşullarını kabul etmelisiniz.',
            'accept_kvkk.accepted' => 'KVKK aydınlatma metnini okuduğunuzu onaylamalısınız.',
        ];
    }
}

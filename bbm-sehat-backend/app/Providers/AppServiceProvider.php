<?php

namespace App\Providers;

use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Backend-only for now: no frontend reset-password page exists yet
        // for either client, so the email carries the raw token + email
        // instead of a clickable link. POST /api/reset-password takes both
        // directly. Once the React dashboard / Flutter deep link exist,
        // point this at that URL instead.
        ResetPassword::toMailUsing(function (object $notifiable, string $token) {
            return (new MailMessage)
                ->subject('Reset Password — BBM Sehat')
                ->line('Kami menerima permintaan reset password untuk akun Anda.')
                ->line('Kode reset: '.$token)
                ->line('Email akun: '.$notifiable->getEmailForPasswordReset())
                ->line('Gunakan kode ini di endpoint POST /api/reset-password beserta password baru Anda.')
                ->line('Kode ini berlaku selama 15 menit dan hanya bisa dipakai sekali.');
        });

        RateLimiter::for('login', function (Request $request) {
            $key = strtolower((string) $request->input('email', $request->input('employee_code', '')));

            return [
                Limit::perMinute(5)->by($key.'|'.$request->ip()),
                Limit::perMinute(20)->by($request->ip()),
            ];
        });
    }
}

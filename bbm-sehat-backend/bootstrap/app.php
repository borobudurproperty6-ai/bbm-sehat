<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Enables Sanctum's cookie/session-based SPA auth on api/* routes
        // (for the React dashboard) alongside plain bearer-token auth (for
        // the Flutter app) — both go through the same 'auth:sanctum' guard.
        $middleware->statefulApi();

        $middleware->alias([
            'role' => \App\Http\Middleware\EnsureEmployeeHasRole::class,
            // Scoped strictly to "Pengaturan Pengguna" — see the class
            // docblock. Never use this in place of `role` elsewhere.
            'user-settings-access' => \App\Http\Middleware\EnsureEmployeeIsWhitelistedForUserSettings::class,
        ]);

        // Guests hitting a session-guarded *web* route (e.g. GET
        // /dashboard/pengaturan-pengguna) are sent to the dashboard login
        // page — a plain redirect, so zero page data/markup is ever
        // returned. API requests never reach this: shouldRenderJsonWhen()
        // below makes them short-circuit to a JSON 401 first.
        //
        // Previously this called Authenticate::redirectUsing(fn () =>
        // null) directly, aiming to disable the redirect entirely (there
        // used to be no page to redirect to — this was a pure API
        // backend). That only cleared ONE of the three places Laravel's
        // own withMiddleware() pre-registers a route('login') fallback
        // (Authenticate, AuthenticateSession, AuthenticationException) —
        // AuthenticationException::redirectTo() still called the
        // untouched one, which crashed with a 500 (RouteNotFoundException,
        // no 'login'-named route exists) the moment a guest hit a non-JSON
        // web route. redirectGuestsTo() clears/sets all three consistently.
        $middleware->redirectGuestsTo(fn () => route('dashboard.login'));
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );
    })->create();

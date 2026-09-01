<?php

namespace App\Services;

use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\AndroidConfig;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;

class FirebaseNotificationService
{
    private ?Messaging $messaging = null;

    public function sendToDevice(string $token, string $title, string $body, array $data = []): void
    {
        $message = CloudMessage::new()
            ->withToken($token)
            ->withNotification(Notification::create($title, $body))
            ->withAndroidConfig(AndroidConfig::fromArray([
                'notification' => [
                    'channel_id' => 'bbm_sehat_channel',
                ],
            ]))
            ->withData($data);

        $this->messaging()->send($message);
    }

    /**
     * Built lazily so a missing service-account.json (e.g. before it's
     * downloaded and placed by hand, per FIREBASE_CREDENTIALS) only breaks
     * actual send attempts, not every place this service gets injected.
     */
    private function messaging(): Messaging
    {
        return $this->messaging ??= (new Factory)
            ->withServiceAccount(base_path(config('firebase.credentials')))
            ->createMessaging();
    }
}

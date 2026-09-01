<?php

return [
    // Path relative to the project root — resolved via base_path() in
    // FirebaseNotificationService.
    'credentials' => env('FIREBASE_CREDENTIALS', 'storage/app/firebase/service-account.json'),
];

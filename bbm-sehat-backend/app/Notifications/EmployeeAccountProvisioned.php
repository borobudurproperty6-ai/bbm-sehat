<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class EmployeeAccountProvisioned extends Notification
{
    use Queueable;

    public function __construct(private readonly string $temporaryPassword)
    {
    }

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Akun BBM Sehat Anda Sudah Dibuat')
            ->line('Akun aplikasi BBM Sehat untuk Anda sudah dibuat oleh admin.')
            ->line('Kode Karyawan: '.$notifiable->employee_code)
            ->line('Email: '.$notifiable->email)
            ->line('Password sementara: '.$this->temporaryPassword)
            ->line('Anda akan diminta mengganti password ini saat pertama kali masuk.');
    }
}

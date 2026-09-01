# Monitoring API

Endpoint agregat untuk dashboard monitoring perusahaan (dipakai role manajemen/admin
di aplikasi Flutter yang sama, role-based view — bukan aplikasi terpisah). Kelima
endpoint ini murni read-only dan mencakup **seluruh perusahaan**, bukan scoped per
divisi seperti `/api/admin/*`.

## Role yang diizinkan akses

| Role code | Diizinkan? |
|---|---|
| `MANAGEMENT` (Direktur/Komisaris) | ✅ |
| `SUPER_ADMIN` (Admin IT) | ✅ |
| `ADMIN_UMUM_SDM` (Admin Umum & SDM) | ✅ |
| `DIVISION_ADMIN` | ❌ (scope-nya satu divisi, bukan seluruh perusahaan) |
| `EMPLOYEE` | ❌ |

Request tanpa token → `401 Unauthenticated`. Token valid tapi role tidak diizinkan →
`403 Forbidden` dengan pesan `"Anda tidak memiliki akses untuk aksi ini."`.

Semua endpoint butuh header `Authorization: Bearer <token>` (login lewat
`POST /api/login` seperti biasa).

## Sanity-check data agregat

Konsisten dengan pola di Fase 1 (filter noise GPS) dan Fase 2 (batas langkah harian):
setiap query di sini **menyaring ulang** baris individual yang dianggap tidak masuk akal
sebelum ikut dihitung ke rata-rata/total/ranking — sebagai lapisan pertahanan kedua,
independen dari validasi saat data itu pertama kali disimpan.

- `daily_activity_logs.steps` di atas **50.000 langkah/hari** dikecualikan dari SUM/AVG.
- `walk_sessions.distance_meters` di atas **100.000 meter (100km) per sesi**
  dikecualikan (batas ini sengaja sangat longgar — cuma jaring pengaman terakhir,
  bukan re-implementasi filter kecepatan per-segmen yang sudah dilakukan
  `WalkSessionService` saat sesi disimpan).

---

## `GET /api/monitoring/overview`

Ringkasan seluruh perusahaan untuk **minggu berjalan** (Senin s.d. hari ini).

**Contoh response:**
```json
{
  "data": {
    "total_employees_active": 48,
    "participation_rate_this_week": 2.1,
    "total_steps_this_week": 0,
    "total_km_this_week": 0.84,
    "period": { "start": "2026-08-10", "end": "2026-08-12" }
  }
}
```

| Field | Arti |
|---|---|
| `total_employees_active` | Jumlah karyawan dengan `is_active=1` |
| `participation_rate_this_week` | % dari `total_employees_active` yang punya minimal 1 aktivitas (sync Health Connect ATAU sesi jalan kaki selesai) di minggu berjalan |
| `total_steps_this_week` | Total langkah gabungan seluruh perusahaan (dari `daily_activity_logs`) minggu ini |
| `total_km_this_week` | Total km gabungan — jarak dari `daily_activity_logs` **+** jarak dari sesi GPS `walk_sessions` yang `status=completed`, minggu ini |

---

## `GET /api/monitoring/per-divisi`

Breakdown per divisi, untuk minggu berjalan, diurutkan dari rata-rata poin tertinggi
(ranking antar divisi).

**Contoh response:**
```json
{
  "data": {
    "period": { "start": "2026-08-10", "end": "2026-08-12" },
    "divisions": [
      { "rank": 1, "division_id": 4, "division_name": "IT", "employee_count": 3, "avg_points": 1.7, "avg_steps": 0 },
      { "rank": 2, "division_id": 1, "division_name": "Direktur", "employee_count": 1, "avg_points": 0, "avg_steps": 0 }
    ]
  }
}
```

| Field | Arti |
|---|---|
| `employee_count` | Karyawan aktif di divisi itu |
| `avg_points` | Rata-rata poin (`point_transactions.points_awarded`) per karyawan, minggu ini |
| `avg_steps` | Rata-rata langkah per karyawan, minggu ini |
| `rank` | Posisi divisi berdasar `avg_points`, tertinggi = 1 |

---

## `GET /api/monitoring/tidak-aktif?days=7`

Daftar karyawan aktif yang **tidak punya aktivitas sama sekali** (baik sync Health
Connect maupun sesi jalan kaki selesai) dalam N hari terakhir.

**Parameter:** `days` (opsional, default `7`, harus antara 1–365; di luar itu → `422`).

**Contoh response:**
```json
{
  "data": {
    "days": 7,
    "employees": [
      {
        "id": 5,
        "full_name": "Irfan Saputra",
        "employee_code": "BBM-002",
        "division_name": "Admin / SDM",
        "last_activity_date": null
      }
    ]
  }
}
```

`last_activity_date` adalah `null` kalau karyawan itu memang belum pernah punya
aktivitas tercatat sama sekali (bukan cuma "belum aktif N hari terakhir").

---

## `GET /api/monitoring/employees`

Daftar semua karyawan aktif dengan data ringkas, dipaginasi (dijamin tidak pernah
mengirim seluruh baris sekaligus).

**Parameter (semua opsional):**

| Parameter | Arti | Default |
|---|---|---|
| `search` | Cari berdasar nama (substring, case-insensitive) | — |
| `sort_by` | `poin`, `langkah_minggu_ini`, `nama`, atau `divisi` — nilai lain → `422` | `poin` (descending) |
| `divisi` | Filter berdasar `division_id` | — |
| `page` | Halaman ke-berapa | `1` |
| `per_page` | Baris per halaman, dibatasi maksimal 100 | `20` |

**Contoh response:**
```json
{
  "data": [
    {
      "id": 9,
      "full_name": "Gofar",
      "employee_code": "BBM-006",
      "division_name": "IT",
      "total_points": 70,
      "steps_this_week": 0,
      "current_streak_days": 0,
      "is_active_recently": true
    }
  ],
  "meta": { "current_page": 1, "per_page": 3, "total": 48, "last_page": 16 }
}
```

| Field | Arti |
|---|---|
| `total_points` | Akumulasi poin (dari view `employee_total_points`) |
| `steps_this_week` | Total langkah minggu berjalan |
| `current_streak_days` | Hari kerja berturut-turut capai target (definisi sama dengan `PointService::currentStreakDays`) |
| `is_active_recently` | Ada aktivitas dalam 7 hari terakhir — definisi identik dengan `/monitoring/tidak-aktif` (di-invert) |

---

## `GET /api/monitoring/employees/{id}`

Detail progres lengkap satu karyawan — reuse logic yang sama dengan yang dilihat
karyawan itu sendiri di riwayat aktivitasnya (`ActivityHistoryService::weekly()`),
bukan re-implementasi terpisah. ID karyawan yang tidak ditemukan → `404`.

**Contoh response:**
```json
{
  "data": {
    "employee": {
      "id": 9, "full_name": "Gofar", "employee_code": "BBM-006",
      "division_name": "IT", "role_name": "Super Admin IT", "position_title": "Supervisor"
    },
    "total_points": 70,
    "current_streak_days": 0,
    "average_daily_steps": 0,
    "weekly_history": [
      { "label": "Sen", "date": "2026-08-10", "steps": 0, "target_met": false }
    ],
    "walk_sessions": [
      { "id": 23, "started_at": "...", "ended_at": "...", "duration_seconds": 480, "distance_meters": 745.01, "points_awarded": 5 }
    ],
    "point_breakdown": [
      { "rule_code": "DAILY_TARGET_MET", "rule_name": "Mencapai target langkah harian", "total_points": 50, "times_awarded": 5 }
    ],
    "badges": []
  }
}
```

> **Catatan:** `badges` selalu kosong untuk saat ini — sistem penetapan lencana
> (`employee_badges`) belum dibangun (lihat rencana "Badge system" di timeline
> proyek). Field ini sudah disiapkan di response supaya tidak perlu perubahan
> bentuk data lagi begitu badge system diimplementasikan.

---

## `POST /api/admin/send-walk-reminder`

Bukan endpoint monitoring (bukan read-only, dan bukan bagian dari prefix
`/monitoring/*` di atas) — didokumentasikan di sini karena masih berhubungan
erat dengan data step/target yang sama. Mengirim push notification "Ayo
Jalan Kaki!" ke setiap karyawan aktif yang **belum mencapai target langkah
hari ini** dan sudah punya device terdaftar (`device_tokens`). Karyawan yang
sudah capai target, atau belum pernah daftar device, dilewati (bukan
dihitung gagal) — lihat `WalkReminderService`.

Endpoint ini adalah trigger manual (tombol admin) dan **tidak** menerapkan
dedup slot harian — beda dengan pengiriman terjadwal di bawah, admin yang
menekan tombol ini sengaja diasumsikan memang ingin mengirim ulang.

**Role yang diizinkan** — berbeda dari tabel di atas, endpoint ini
khusus `SUPER_ADMIN` dan `ADMIN_UMUM_SDM` saja (`MANAGEMENT` **tidak**
diizinkan di sini):

| Role code | Diizinkan? |
|---|---|
| `SUPER_ADMIN` (Admin IT) | ✅ |
| `ADMIN_UMUM_SDM` (Admin Umum & SDM) | ✅ |
| `MANAGEMENT` (Direktur/Komisaris) | ❌ |
| `DIVISION_ADMIN` | ❌ |
| `EMPLOYEE` | ❌ |

**Contoh response:**
```json
{
  "data": {
    "sent_count": 12,
    "skipped_no_device_count": 3,
    "skipped_duplicate_count": 0,
    "failed_count": 1,
    "failed": [
      { "employee_id": 9, "full_name": "Gofar", "reason": "invalid registration token" }
    ]
  }
}
```

| Field | Arti |
|---|---|
| `sent_count` | Jumlah notifikasi yang berhasil terkirim |
| `skipped_no_device_count` | Dilewati karena belum ada device token terdaftar |
| `skipped_duplicate_count` | Dilewati karena duplikat (selalu `0` di sini — dedup hanya berlaku untuk pengiriman terjadwal, lihat di bawah) |
| `failed_count` | Jumlah percobaan kirim yang gagal (token tidak valid/expired, error transport, dll) |
| `failed` | Detail per kegagalan — `employee_id`, `full_name`, `reason` |

---

## Reminder terjadwal (`walk-reminders:send`)

Bukan endpoint HTTP — ini Artisan command yang dijalankan otomatis oleh
scheduler Laravel (`routes/console.php`), dua kali sehari:

| Slot | Jam | Timezone |
|---|---|---|
| `afternoon` | 15:00 | WITA (`Asia/Makassar`) |
| `evening` | 19:00 | WITA (`Asia/Makassar`) |

Memakai logic pengiriman yang persis sama dengan
`POST /api/admin/send-walk-reminder` di atas (`WalkReminderService`), dengan
satu tambahan: **dedup per slot per hari** — kalau karyawan yang sama sudah
menerima reminder untuk slot itu di hari yang sama (mis. akibat overlap run
atau retry scheduler), pengiriman kedua untuk slot yang sama otomatis
dilewati (`skipped_duplicate_count`). Slot `afternoon` dan `evening` di hari
yang sama **bukan** duplikat satu sama lain — keduanya tetap terkirim kalau
karyawan masih di bawah target.

`withoutOverlapping()` + `onOneServer()` mencegah command yang sama
berjalan dobel kalau proses scheduler sebelumnya belum selesai atau kalau
ada lebih dari satu server yang menjalankan scheduler.

Jalankan manual untuk testing:
```bash
php artisan walk-reminders:send afternoon
```

---

## Contoh curl

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"employee_code":"<User ID role manajemen/admin, format BBM-XXX>","password":"<password>"}' \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['token'])")

curl http://127.0.0.1:8000/api/monitoring/overview -H "Authorization: Bearer $TOKEN"
curl http://127.0.0.1:8000/api/monitoring/per-divisi -H "Authorization: Bearer $TOKEN"
curl "http://127.0.0.1:8000/api/monitoring/tidak-aktif?days=14" -H "Authorization: Bearer $TOKEN"
curl "http://127.0.0.1:8000/api/monitoring/employees?search=Far&sort_by=nama&per_page=10" -H "Authorization: Bearer $TOKEN"
curl http://127.0.0.1:8000/api/monitoring/employees/9 -H "Authorization: Bearer $TOKEN"
curl -X POST http://127.0.0.1:8000/api/admin/send-walk-reminder -H "Authorization: Bearer $TOKEN"
```

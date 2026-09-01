## Instruksi Wajib: Laporan Akhir Setiap Progres

Setiap kali menyelesaikan sebuah tugas backend (endpoint baru, migration baru, perbaikan
bug, dll), SELALU tutup laporan progres dengan hal-hal berikut — jangan diasumsikan saya
ingat dari sesi sebelumnya:

1. **Perintah menjalankan server** — command lengkap beserta folder yang benar, contoh:
   cd "/Users/ptborobudurbumimandiri/APP/bbm-sehat-backend" && php artisan serve

2. **Migration yang perlu dijalankan (kalau ada)** — kalau sesi ini menambah atau mengubah
   tabel/kolom, tulis eksplisit: "Jalankan `php artisan migrate` dulu sebelum testing —
   ada perubahan skema baru di sesi ini." Kalau tidak ada perubahan skema, tidak perlu
   disebut.

3. **Akun untuk testing yang masih valid saat ini** — minimal satu User ID (format BBM-XXX,
   dari kolom employee_code, BUKAN email — login mobile sejak Fase D memakai User ID, bukan
   email) + password yang BENAR-BENAR bisa dipakai sekarang untuk uji endpoint (bukan yang
   sudah pernah diganti/kadaluarsa). Kalau password sebuah akun berubah karena testing,
   sebutkan yang terbaru.

4. **Prasyarat servis** — ingatkan MAMP (MySQL) harus sudah menyala dulu sebelum
   `php artisan serve` atau migration dijalankan.

5. **Contoh perintah test cepat (curl)** — untuk setiap endpoint yang baru dibuat atau
   diubah di sesi ini, sertakan satu contoh perintah `curl` yang siap langsung dipakai
   (lengkap dengan header Authorization kalau endpoint itu butuh login), supaya saya bisa
   coba tanpa harus buka aplikasi Flutter dulu.

Format ini wajib muncul di akhir SETIAP laporan penyelesaian tugas backend, sesingkat
apa pun tugasnya.

## TODO Sebelum Rollout

- ✅ min_distance_meters untuk WALK_SESSION_LOGGED sudah dikembalikan ke 500m pada
  2026-08-26, sesuai rencana rollout. (Sebelumnya diturunkan sementara ke 100m pada
  2026-08-11 untuk keperluan testing — lihat Fase 8: Rencana distribusi & rollout di
  timeline.)

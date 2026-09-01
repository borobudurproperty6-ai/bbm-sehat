## Instruksi Wajib: Laporan Akhir Setiap Progres

Setiap kali menyelesaikan sebuah tugas (fitur baru, perbaikan bug, penyambungan ke backend, dll),
SELALU tutup laporan progres dengan empat hal berikut — jangan diasumsikan saya ingat dari sesi sebelumnya:

1. **Perintah menjalankan aplikasi** — command lengkap beserta folder yang benar, contoh:
   cd "/Users/ptborobudurbumimandiri/APP/BBM SEHAT" && flutter run -d chrome

2. **Akun untuk login yang masih valid saat ini** — minimal satu User ID (format BBM-XXX,
   dari kolom employee_code, BUKAN email — login sejak Fase D memakai User ID) + password
   yang BENAR-BENAR bisa dipakai sekarang (bukan yang sudah pernah diganti/kadaluarsa di
   sesi sebelumnya). Kalau password sebuah akun berubah karena testing, sebutkan password
   yang terbaru, bukan yang lama.

3. **Peringatan Hot Restart kalau perlu** — kalau perubahan kali ini mengubah struktur
   widget (StatelessWidget jadi StatefulWidget, provider baru, dependency injection baru,
   dsb), tulis eksplisit: "Setelah ini, tekan R BESAR (Hot Restart) di terminal — hot
   reload biasa (r kecil) kemungkinan tidak cukup untuk perubahan struktural ini."

4. **Prasyarat servis** — ingatkan kalau MAMP (MySQL) dan `php artisan serve` (backend
   Laravel di folder bbm-sehat-backend) harus sudah menyala sebelum testing dilakukan.

Format ini wajib muncul di akhir SETIAP laporan penyelesaian tugas, sesingkat apa pun
tugasnya, kecuali tugas itu murni dokumentasi/planning yang tidak menyentuh kode.

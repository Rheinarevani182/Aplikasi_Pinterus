# Pinterus Mobile

## Menjalankan aplikasi

Jalankan backend Laravel dari folder utama repository:

```powershell
php artisan migrate
php artisan storage:link
php artisan serve --host=0.0.0.0 --port=8000
```

Lalu dari folder `pinterus_mobile`:

```powershell
flutter pub get
flutter run -d chrome
```

Untuk Android Emulator, gunakan `flutter run -d emulator-5554`. Aplikasi otomatis
mengakses backend emulator melalui `http://10.0.2.2:8000/api`. Untuk perangkat
Android fisik, arahkan `API_BASE_URL` ke alamat IP komputer yang dapat dijangkau
perangkat tersebut:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
```

Ganti `192.168.1.10` dengan alamat IP komputer. Pastikan perangkat dan komputer
berada di jaringan yang sama. Jalankan backend dengan `--host=0.0.0.0` agar
perangkat dapat mengaksesnya.

## Fitur

- Daftar, masuk, dan keluar dengan sesi yang tersimpan di perangkat.
- Jelajahi pin, buka tautan tujuan, simpan, bagikan, laporkan, dan hapus pin
  milik sendiri.
- Buat pin dari gambar galeri, edit dan bagikan profil, serta ikuti profil lain.

Logo Pinterus tersedia di `assets/images/pinterus_logo.jpg`.

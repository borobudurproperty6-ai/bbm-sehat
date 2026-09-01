import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Shown before the system Health Connect permission prompt — explains
/// what data is read and why. Returns true if the user tapped "Izinkan",
/// false/null otherwise. Used by both Beranda's "Sinkron Sekarang" button
/// and Profil's Health Connect settings row.
Future<bool?> showHealthConnectRationale(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Sambungkan Health Connect', style: AppText.heading(size: 17)),
      content: Text(
        'BBM Sehat ingin membaca jumlah langkah harianmu dari Health Connect, '
        'untuk menghitung progres target harian dan poinmu secara otomatis. '
        'Data ini hanya dipakai di dalam aplikasi dan tidak dibagikan ke pihak lain.',
        style: AppText.body(size: 13, color: AppColors.mut),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Batal', style: AppText.body(size: 14, color: AppColors.mut)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Izinkan', style: AppText.body(size: 14, color: AppColors.accent)),
        ),
      ],
    ),
  );
}

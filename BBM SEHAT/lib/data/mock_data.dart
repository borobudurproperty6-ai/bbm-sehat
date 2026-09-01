import 'package:flutter/material.dart';
import '../models/models.dart';

/// Static mock data standing in for a real backend. Mirrors the content used
/// in the original design so the app demos with realistic Indonesian copy.
class MockData {
  MockData._();

  static final weekStrip = <WeekDayStatus>[
    WeekDayStatus('S', true),
    WeekDayStatus('S', true),
    WeekDayStatus('R', true),
    WeekDayStatus('K', false),
    WeekDayStatus('J', false),
    WeekDayStatus('S', false),
    WeekDayStatus('M', false),
  ];

  static const badges = <BadgeItem>[
    BadgeItem(id: 1, name: 'Langkah Pertama', icon: Icons.directions_walk, desc: 'Selesaikan sesi jalan kaki pertamamu.', req: '1 sesi terekam', earned: true, date: '12 Jul 2026'),
    BadgeItem(id: 2, name: '5.000 Langkah', icon: Icons.monitor_heart, desc: 'Capai 5.000 langkah dalam sehari.', req: '5.000 langkah/hari', earned: true, date: '14 Jul 2026'),
    BadgeItem(id: 3, name: 'Target Harian', icon: Icons.track_changes, desc: 'Penuhi target langkah harianmu.', req: '8.000 langkah/hari', earned: true, date: '18 Jul 2026'),
    BadgeItem(id: 4, name: 'Pejalan 10K', icon: Icons.bolt, desc: 'Tembus 10.000 langkah dalam sehari.', req: '10.000 langkah/hari', earned: true, date: '22 Jul 2026'),
    BadgeItem(id: 5, name: 'Penjelajah Rute', icon: Icons.route, desc: 'Rekam 10 sesi rute jalan kaki.', req: '10 sesi rute', earned: true, date: '28 Jul 2026'),
    BadgeItem(id: 6, name: 'Pendaki Kota', icon: Icons.terrain, desc: 'Tempuh 50 km akumulasi jarak.', req: '50 km total', earned: true, date: '1 Agu 2026'),
    BadgeItem(id: 7, name: 'Konsisten Sepekan', icon: Icons.local_fire_department, desc: 'Capai target 5 hari beruntun.', req: '5 hari beruntun', earned: false),
    BadgeItem(id: 8, name: 'Bintang Divisi', icon: Icons.workspace_premium, desc: 'Peringkat 1 di divisimu dalam sebulan.', req: 'Juara 1 divisi/bulan', earned: false),
    BadgeItem(id: 9, name: 'Maraton Bulanan', icon: Icons.military_tech, desc: 'Tempuh 200 km dalam satu bulan.', req: '200 km/bulan', earned: false),
  ];
}

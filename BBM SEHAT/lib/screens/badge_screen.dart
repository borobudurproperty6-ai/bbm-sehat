import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class BadgeScreen extends StatelessWidget {
  const BadgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            GestureDetector(
              onTap: () => state.go(AppScreen.profil),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.card, border: Border.all(color: AppColors.line), shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_left, size: 18, color: AppColors.text),
              ),
            ),
            const SizedBox(width: 10),
            Text('Pencapaian', style: AppText.heading(size: 20)),
          ]),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.amberTint,
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.28)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(
                child: Text('Menuju lencana berikutnya',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.amberSoft)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.card2,
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('3 / 5 hari', style: AppText.body(size: 11, color: AppColors.amberSoft)),
              ),
            ]),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: 0.6,
                minHeight: 9,
                backgroundColor: AppColors.card2,
                valueColor: const AlwaysStoppedAnimation(AppColors.amber),
              ),
            ),
            const SizedBox(height: 8),
            Text('2 hari beruntun lagi untuk meraih "Konsisten Sepekan".',
                style: AppText.body(size: 11.5, color: AppColors.mut)),
          ]),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: MockData.badges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, i) {
            final b = MockData.badges[i];
            return GestureDetector(
              onTap: () => showBadgeDetail(context, b),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 52, height: 52, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: b.earned ? AppColors.amberTint : AppColors.card2,
                      border: Border.all(
                          color: b.earned ? AppColors.amber.withValues(alpha: 0.4) : AppColors.line,
                          width: 1.5),
                    ),
                    child: Icon(b.icon, size: 24, color: b.earned ? AppColors.amber : AppColors.dim),
                  ),
                  const SizedBox(height: 7),
                  Text(b.name, textAlign: TextAlign.center, maxLines: 2,
                      style: AppText.body(size: 10.5, color: b.earned ? AppColors.text : AppColors.mut)),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }
}

void showBadgeDetail(BuildContext context, BadgeItem b) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          Container(
            width: 78, height: 78, alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: b.earned ? AppColors.amberTint : AppColors.card2,
              border: Border.all(
                  color: b.earned ? AppColors.amber.withValues(alpha: 0.4) : AppColors.line, width: 2),
            ),
            child: Icon(b.icon, size: 36, color: b.earned ? AppColors.amber : AppColors.dim),
          ),
          const SizedBox(height: 14),
          Text(b.name, style: AppText.heading(size: 22)),
          const SizedBox(height: 6),
          Text(b.desc, textAlign: TextAlign.center, style: AppText.body(size: 13.5, color: AppColors.mut)),
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Syarat', style: AppText.body(size: 12.5, color: AppColors.mut)),
                Flexible(child: Text(b.req, textAlign: TextAlign.right, style: AppText.body(size: 12.5))),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Status', style: AppText.body(size: 12.5, color: AppColors.mut)),
                Text(b.earned ? 'Diraih ${b.date}' : 'Belum diraih',
                    style: AppText.body(size: 12.5, color: b.earned ? AppColors.accent : AppColors.mut)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.route,
                foregroundColor: const Color(0xFF06231A),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Tutup', style: AppText.heading(size: 16, color: const Color(0xFF06231A))),
            ),
          ),
        ]),
      ),
    ),
  );
}

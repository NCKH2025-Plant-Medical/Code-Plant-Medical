// lib/screens/garden/garden_widgets.dart
//
// Widget dùng chung cho Vườn Dược Liệu: chip mùa vụ, chip giai đoạn,
// badge trạng thái, thẻ việc, thẻ cây, ô thời tiết, banner cảnh báo.

import 'package:flutter/material.dart';
import 'package:thunghiem1/models/herbal_garden.dart';
import 'package:thunghiem1/screens/garden/garden_constants.dart';

/// Chip nhỏ — dùng cho mùa vụ, giai đoạn, loại đất.
class GardenChip extends StatelessWidget {
  const GardenChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon != null ? 9 : 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: filled ? Colors.white : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip mùa vụ — đọc `season.display` + `season.in_season` từ server.
class SeasonChip extends StatelessWidget {
  const SeasonChip({super.key, this.season});

  final SeasonInfo? season;

  @override
  Widget build(BuildContext context) {
    if (season == null) return const SizedBox.shrink();
    final s = season!;
    final label = s.coMuaVu
        ? '${s.chipLabel}${s.display != null ? ' · ${s.display}' : ''}'
        : s.chipLabel;
    return GardenChip(label: label, color: s.chipColor);
  }
}

/// Chip giai đoạn sinh trưởng.
class StageChip extends StatelessWidget {
  const StageChip({super.key, required this.stage, required this.label});

  final String stage;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GardenChip(
      label: label,
      color: stageColor(stage),
      icon: stageIcon(stage),
    );
  }
}

/// Badge trạng thái chăm sóc trên card cây — Mục 6.2.
class CareBadgesRow extends StatelessWidget {
  const CareBadgesRow({super.key, required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: codes.map((code) {
        final badge = kCareBadges[code];
        if (badge == null) return const SizedBox.shrink();
        return Tooltip(
          message: taskShortLabel(code),
          child: Text(
            badge.$1,
            style: const TextStyle(fontSize: 13, height: 1.1),
          ),
        );
      }).toList(),
    );
  }
}

/// Banner cảnh báo — hiển thị nguyên văn `canh_bao[]` (Mục 7.1).
class GardenBanner extends StatelessWidget {
  const GardenBanner({
    super.key,
    required this.text,
    this.kind = GardenBannerKind.info,
    this.icon,
  });

  final String text;
  final GardenBannerKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = bannerColor(kind);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bannerBg(kind),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? bannerIcon(kind), color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô thời tiết + gợi ý tưới — Mục 3.2.
class WeatherWidget extends StatelessWidget {
  const WeatherWidget({super.key, required this.weather});

  final GardenWeather? weather;

  @override
  Widget build(BuildContext context) {
    final w = weather;
    if (w == null || !w.ok) {
      return GardenBanner(
        text: 'Không lấy được thời tiết. Các chức năng khác vẫn dùng được.',
        kind: GardenBannerKind.neutral,
        icon: Icons.cloud_off_rounded,
      );
    }

    final canTuoi = w.canTuoi;
    final (bannerKind, bannerText) = switch (canTuoi) {
      true => (GardenBannerKind.warning, 'Nên tưới hôm nay'),
      false => (GardenBannerKind.info, 'Tạm hoãn lịch tưới'),
      null => (GardenBannerKind.neutral, 'Giữ chu kỳ tưới chuẩn'),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14563F), Color(0xFF2D6A4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(weatherIcon(w.weatherCode), color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.weatherText ?? '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (w.temperature != null) '${w.temperature!.toStringAsFixed(1)}°C',
                        if (w.humidity != null) 'ẩm ${w.humidity}%',
                        if (w.rainMm != null) 'mưa ${w.rainMm!.toStringAsFixed(1)}mm',
                      ].join(' · '),
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Text(
                w.sourceLabel,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          if (w.daily.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: w.daily.take(3).map((d) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _shortDay(d.date),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${d.tempMax?.toStringAsFixed(0) ?? '—'}° / ${d.tempMin?.toStringAsFixed(0) ?? '—'}°',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '💧${d.rainMm?.toStringAsFixed(1) ?? '0'}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  canTuoi == true
                      ? Icons.local_drink_rounded
                      : canTuoi == false
                          ? Icons.pause_circle_outline_rounded
                          : Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    w.lyDo ?? bannerText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDay(String date) {
    try {
      final d = DateTime.parse(date);
      const names = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
      return names[d.weekday - 1];
    } catch (_) {
      return date;
    }
  }
}

/// Thẻ cây trong vườn — có viền đỏ khi `can_cham_soc_hom_nay == true`.
class GardenPlantCard extends StatelessWidget {
  const GardenPlantCard({
    super.key,
    required this.plant,
    required this.onTap,
  });

  final GardenPlantItem plant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final needsCare = plant.canChamSocHomNay;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: needsCare ? const Color(0xFFDC2626) : Colors.transparent,
            width: needsCare ? 2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: AspectRatio(
                aspectRatio: 1,
                child: plant.imageUrl != null && plant.imageUrl!.isNotEmpty
                    ? Image.network(
                        plant.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE8F4EF),
                          child: const Icon(
                            Icons.eco_rounded,
                            size: 34,
                            color: Color(0xFF2D6A4F),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFE8F4EF),
                        child: const Icon(
                          Icons.eco_rounded,
                          size: 34,
                          color: Color(0xFF2D6A4F),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.tenCay ?? plant.tenLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plant.stageLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: stageColor(plant.stage),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CareBadgesRow(codes: plant.trangThaiChamSoc),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('📸${plant.soAnhTimeline}', style: _tinyStyle),
                      const SizedBox(width: 8),
                      Text('📖${plant.soLanThuHoach}', style: _tinyStyle),
                      if (plant.soil?.soilLabel != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            plant.soil!.soilLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _tinyStyle,
                          ),
                        ),
                      ] else
                        const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _tinyStyle = TextStyle(fontSize: 10.5, color: Color(0xFF6C757D));
}

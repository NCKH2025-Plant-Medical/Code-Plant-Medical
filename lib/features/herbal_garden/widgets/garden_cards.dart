// lib/features/herbal_garden/widgets/garden_cards.dart
//
// Các card hiển thị trong màn hình "Vườn của tôi":
//  • GardenWeatherCard — thời tiết + gợi ý tưới (GET /weather)
//  • GardenCareTaskCard — thẻ việc hôm nay (GET /care-today)
//  • GardenPlantCard — thẻ cây trong vườn (GET /api/v1/herbal-garden)
//  • GardenStatStrip — dải số liệu tổng quan
//  • GardenEmptyState — trạng thái rỗng

import 'package:flutter/material.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_style.dart';
import 'package:thunghiem1/theme/app_colors.dart';

// ── Thời tiết ─────────────────────────────────────────────────────────────

class GardenWeatherCard extends StatelessWidget {
  final GardenWeather? weather;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  const GardenWeatherCard({
    super.key,
    this.weather,
    this.loading = false,
    this.error,
    this.onRetry,
  });

  static const List<String> _icons = <String>[
    '🌫️',
    '☀️',
    '🌤️',
    '⛅',
    '☁️',
    '🌫️',
    '🌦️',
    '🌧️',
    '❄️',
    '🌦️',
    '⛈️',
  ];

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const GardenCard(
        child: SizedBox(
          height: 78,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      );
    }

    if (error != null) {
      return GardenCard(
        child: GardenErrorBanner(message: error!, onRetry: onRetry),
      );
    }

    final w = weather;
    if (w == null || !w.ok) {
      return const GardenCard(
        child: GardenInfoBanner(
          message:
              'Không lấy được thời tiết. Các chức năng khác vẫn dùng được.',
          icon: Icons.cloud_off_rounded,
        ),
      );
    }

    final iconIndex = GardenWeather.weatherIcon(w.weatherCode);
    final icon =
        _icons[iconIndex < 0
            ? 0
            : (iconIndex >= _icons.length ? _icons.length - 1 : iconIndex)];

    return GardenCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          w.temperature != null
                              ? '${w.temperature!.toStringAsFixed(1)}°'
                              : '--°',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            w.weatherText ?? '—',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withValues(alpha: 0.75),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      <String>[
                        if (w.humidity != null) 'Ẩm ${w.humidity}%',
                        if (w.rainMm != null)
                          'Mưa ${w.rainMm!.toStringAsFixed(1)}mm',
                        w.sourceLabel,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (w.canTuoi != null) ...<Widget>[
            const SizedBox(height: 12),
            _WateringAdvice(weather: w),
          ],
          if (w.lyDo != null && w.lyDo!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              w.lyDo!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
          if (w.daily.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: w.daily.take(3).map((d) {
                return Column(
                  children: <Widget>[
                    Text(
                      d.date.length >= 10 ? d.date.substring(8, 10) : d.date,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.tempMax != null
                          ? '${d.tempMax!.round()}°/${d.tempMin != null ? d.tempMin!.round() : '--'}°'
                          : '--',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.water_drop_rounded,
                          size: 11,
                          color: Color(0xFF4A90D9),
                        ),
                        Text(
                          d.rainMm != null ? d.rainMm!.toStringAsFixed(1) : '0',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _WateringAdvice extends StatelessWidget {
  final GardenWeather weather;

  const _WateringAdvice({required this.weather});

  @override
  Widget build(BuildContext context) {
    final canTuoi = weather.canTuoi == true;
    final color = canTuoi ? const Color(0xFFE2703A) : AppColors.success;
    final label = canTuoi
        ? 'Nên tưới hôm nay'
        : 'Tạm hoãn lịch tưới — giữ chu kỳ chuẩn';
    final icon = canTuoi
        ? Icons.water_drop_rounded
        : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dải số liệu ───────────────────────────────────────────────────────────

class GardenStatStrip extends StatelessWidget {
  final int totalPlants;
  final int tasksToday;
  final double totalHarvestKg;

  const GardenStatStrip({
    super.key,
    required this.totalPlants,
    required this.tasksToday,
    required this.totalHarvestKg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatBox(
            icon: Icons.local_florist_rounded,
            value: '$totalPlants',
            label: 'cây trong vườn',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.task_alt_rounded,
            value: '$tasksToday',
            label: 'việc hôm nay',
            color: tasksToday > 0 ? const Color(0xFFD64545) : AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.scale_rounded,
            value: totalHarvestKg.toStringAsFixed(2),
            label: 'kg đã thu',
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thẻ việc hôm nay ─────────────────────────────────────────────────────

class GardenCareTaskCard extends StatelessWidget {
  final CareTask task;
  final bool busy;
  final VoidCallback? onOpenPlant;
  final VoidCallback? onWater;
  final VoidCallback? onHarvest;
  final VoidCallback? onDismiss;
  final ValueChanged<TaskChoice>? onChoose;

  const GardenCareTaskCard({
    super.key,
    required this.task,
    this.busy = false,
    this.onOpenPlant,
    this.onWater,
    this.onHarvest,
    this.onDismiss,
    this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final accent = GardenTaskStyle.color(task.taskType);
    final priorityColor = GardenPriority.color(task.priority);

    return GardenCard(
      padding: EdgeInsets.zero,
      // ⚠️ Viền card dùng màu theo LOẠI việc (xanh lá cho thu hoạch, cam cho
      // ngoài mùa...). Đỏ chỉ nằm ở vạch 4px bên trái = "độ ưu tiên gấp",
      // không phải báo lỗi. Trước đây viền đỏ khiến thẻ "Đến kỳ thu hoạch"
      // trông như báo lỗi, dù đây là tin vui.
      borderColor: accent.withValues(alpha: 0.4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Vạch màu bên trái theo mức độ ưu tiên.
            Container(width: 4, color: priorityColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            GardenTaskStyle.icon(task.taskType),
                            size: 18,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                task.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${GardenTaskStyle.label(task.taskType)} · '
                                '${GardenPriority.label(task.priority)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onOpenPlant != null)
                          IconButton(
                            onPressed: onOpenPlant,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.black38,
                            ),
                            tooltip: 'Xem cây',
                          ),
                      ],
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 9),
                      Text(
                        task.description!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Colors.black.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                    if (task.huongDan.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      ...task.huongDan.map(
                        (step) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  step,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Colors.black.withValues(alpha: 0.62),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (task.luaChon.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 11),
                      ...task.luaChon.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ChoiceButton(
                            choice: c,
                            busy: busy,
                            onTap: onChoose == null ? null : () => onChoose!(c),
                          ),
                        ),
                      ),
                    ],
                    if (_hasActionButton) ...<Widget>[
                      const SizedBox(height: 11),
                      Row(
                        children: <Widget>[
                          if (onWater != null)
                            _TaskActionButton(
                              label: 'Tưới xong',
                              icon: Icons.water_drop_rounded,
                              color: const Color(0xFF3B82C4),
                              busy: busy,
                              onTap: onWater,
                            ),
                          if (onWater != null && onHarvest != null)
                            const SizedBox(width: 8),
                          if (onHarvest != null)
                            _TaskActionButton(
                              label: 'Thu hoạch',
                              icon: Icons.grass_rounded,
                              color: AppColors.accent,
                              busy: busy,
                              onTap: onHarvest,
                            ),
                          if (onDismiss != null &&
                              task.coTheDismiss) ...<Widget>[
                            const SizedBox(width: 8),
                            _TaskActionButton(
                              label: 'Đã xong',
                              icon: Icons.check_rounded,
                              color: Colors.black54,
                              busy: busy,
                              onTap: onDismiss,
                              expand: false,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasActionButton =>
      onWater != null || onHarvest != null || onDismiss != null;
}

class _ChoiceButton extends StatelessWidget {
  final TaskChoice choice;
  final bool busy;
  final VoidCallback? onTap;

  const _ChoiceButton({required this.choice, required this.busy, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    choice.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  if (choice.moTa != null &&
                      choice.moTa!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      choice.moTa!,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  if (choice.canhBao != null &&
                      choice.canhBao!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      '⚠️ ${choice.canhBao!}',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: Color(0xFFB0621A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback? onTap;
  final bool expand;

  const _TaskActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
    this.onTap,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: busy ? null : onTap,
      icon: busy
          ? const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 15),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
    return expand ? Expanded(child: button) : button;
  }
}

// ── Thẻ cây trong vườn ───────────────────────────────────────────────────

class GardenPlantCard extends StatelessWidget {
  final GardenPlantItem plant;
  final VoidCallback? onTap;

  const GardenPlantCard({super.key, required this.plant, this.onTap});

  @override
  Widget build(BuildContext context) {
    final needsCare = plant.canChamSocHomNay;

    return GardenCard(
      padding: EdgeInsets.zero,
      borderColor: needsCare ? const Color(0xFFD64545) : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              GardenNetworkImage(
                url: plant.imageUrl,
                width: double.infinity,
                height: 104,
                fallbackIcon: GardenStageStyle.icon(plant.stage),
                fallbackColor: GardenStageStyle.color(plant.stage),
              ),
              // Badge giai đoạn.
              Positioned(
                left: 9,
                bottom: 9,
                child: GardenChip(
                  label: plant.stageLabel,
                  icon: GardenStageStyle.icon(plant.stage),
                  color: GardenStageStyle.color(plant.stage),
                  filled: true,
                ),
              ),
              // Badge trạng thái chăm sóc.
              if (plant.trangThaiChamSoc.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          GardenStatusBadge.icon(plant.trangThaiChamSoc.first),
                          size: 13,
                          color: GardenStatusBadge.color(
                            plant.trangThaiChamSoc.first,
                          ),
                        ),
                        if (plant.trangThaiChamSoc.length > 1) ...<Widget>[
                          const SizedBox(width: 3),
                          Text(
                            '${plant.trangThaiChamSoc.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  plant.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  plant.daysSincePlanted != null
                      ? 'Đã trồng ${plant.daysSincePlanted} ngày'
                      : 'Chưa có ngày gieo',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: <Widget>[
                    GardenSeasonChip(season: plant.season),
                    if (plant.soil?.soilLabel != null)
                      GardenChip(
                        label: plant.soil!.soilLabel!,
                        icon: Icons.landscape_rounded,
                        color: const Color(0xFF8A6D3B),
                      ),
                  ],
                ),
                // Khoảng thời gian mùa vụ — dòng riêng để không làm chip tràn.
                if (plant.season?.display != null) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(
                    'Mùa: ${plant.season!.display}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _MiniStat(
                      icon: Icons.photo_camera_rounded,
                      value: '${plant.soAnhTimeline}',
                    ),
                    const SizedBox(width: 10),
                    _MiniStat(
                      icon: Icons.menu_book_rounded,
                      value: '${plant.soLanThuHoach}',
                    ),
                    const Spacer(),
                    if (plant.tongKhoiLuongThuHoachKg > 0)
                      Text(
                        '${plant.tongKhoiLuongThuHoachKg.toStringAsFixed(2)} kg',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MiniStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: Colors.black.withValues(alpha: 0.42)),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ── Trạng thái rỗng ───────────────────────────────────────────────────────

class GardenEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const GardenEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

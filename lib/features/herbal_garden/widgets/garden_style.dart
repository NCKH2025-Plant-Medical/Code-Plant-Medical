// lib/features/herbal_garden/widgets/garden_style.dart
//
// Bảng màu & helper hiển thị dùng chung cho chức năng Vườn Dược Liệu.
//
// Màu bám theo hệ thống: AppColors.primary (#1B4332) · accent (#40916C) ·
// success (#52B788) — đồng bộ với Home / Account / Map của app.

import 'package:flutter/material.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/theme/app_colors.dart';

/// Màu theo mức độ ưu tiên của thẻ việc.
class GardenPriority {
  static Color color(String priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFD64545);
      case 'normal':
        return const Color(0xFFE8A33D);
      default:
        return const Color(0xFF8A9BA8);
    }
  }

  static String label(String priority) {
    switch (priority) {
      case 'high':
        return 'Cần làm gấp';
      case 'normal':
        return 'Nên làm hôm nay';
      default:
        return 'Tham khảo';
    }
  }
}

/// Icon + màu theo `task_type` (8 loại việc).
class GardenTaskStyle {
  static IconData icon(String taskType) {
    switch (taskType) {
      case 'tuoi':
        return Icons.water_drop_rounded;
      case 'cat_tia':
        return Icons.content_cut_rounded;
      case 'ngoai_mua':
        return Icons.event_rounded;
      case 'thu_hoach':
        return Icons.grass_rounded;
      case 'bo_roi':
        return Icons.bedtime_rounded;
      case 'co_the_chet':
        return Icons.warning_amber_rounded;
      case 'chup_anh':
        return Icons.photo_camera_rounded;
      case 'nay_mam':
        return Icons.eco_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  /// Màu theo LOẠI việc — phải khớp với dải chip tóm tắt trong
  /// `garden_screen.dart` (`_buildCareSummary`).
  ///
  /// ⚠️ KHÔNG dùng đỏ cho việc "tốt" (đến kỳ thu hoạch). Đỏ = cảnh báo /
  /// cần xử lý gấp. Người dùng thấy thẻ "Đến kỳ thu hoạch" viền đỏ thì
  /// tưởng app báo lỗi, trong khi thực ra đây là tin vui.
  static Color color(String taskType) {
    switch (taskType) {
      // Việc cần can thiệp gấp → đỏ.
      case 'bo_roi':
      case 'co_the_chet':
        return const Color(0xFFD64545);
      // Đến kỳ thu hoạch → xanh lá (tín hiệu tốt, sẵn sàng thu hoạch).
      case 'thu_hoach':
        return AppColors.success;
      // Cần tưới → xanh dương (giống chip "💧 Cần tưới").
      case 'tuoi':
        return const Color(0xFF3B82C4);
      // Ngoài mùa thu hoạch → cam (cảnh báo nhẹ, giống chip "📅 Ngoài mùa").
      case 'ngoai_mua':
        return const Color(0xFFE2703A);
      // Cắt tỉa / nảy mầm → vàng.
      case 'cat_tia':
      case 'nay_mam':
        return const Color(0xFFE8A33D);
      default:
        return const Color(0xFF8A9BA8);
    }
  }

  static String label(String taskType) {
    switch (taskType) {
      case 'tuoi':
        return 'Cần tưới';
      case 'cat_tia':
        return 'Đến kỳ cắt tỉa';
      case 'ngoai_mua':
        return 'Ngoài mùa thu hoạch';
      case 'thu_hoach':
        return 'Đến kỳ thu hoạch';
      case 'bo_roi':
        return 'Đang bị bỏ rơi';
      case 'co_the_chet':
        return 'Có thể đã chết';
      case 'chup_anh':
        return 'Nhắc chụp ảnh';
      case 'nay_mam':
        return 'Có thể chưa nảy mầm';
      default:
        return 'Việc cần làm';
    }
  }
}

/// Icon + màu của badge trạng thái chăm sóc (`trang_thai_cham_soc`).
class GardenStatusBadge {
  static IconData icon(String code) {
    switch (code) {
      case 'tuoi':
        return Icons.water_drop_rounded;
      case 'cat_tia':
        return Icons.content_cut_rounded;
      case 'ngoai_mua':
        return Icons.event_rounded;
      case 'thu_hoach':
        return Icons.grass_rounded;
      case 'bo_roi':
        return Icons.bedtime_rounded;
      case 'co_the_chet':
        return Icons.warning_amber_rounded;
      case 'chup_anh':
        return Icons.photo_camera_rounded;
      case 'nay_mam':
        return Icons.eco_rounded;
      default:
        return Icons.circle;
    }
  }

  /// ⚠️ Khớp với [GardenTaskStyle.color] — cùng một ngữ nghĩa màu:
  /// đỏ = cảnh báo, xanh lá = đến kỳ thu hoạch (tốt), cam = ngoài mùa.
  static Color color(String code) {
    switch (code) {
      case 'bo_roi':
      case 'co_the_chet':
        return const Color(0xFFD64545);
      case 'thu_hoach':
        return AppColors.success;
      case 'tuoi':
        return const Color(0xFF3B82C4);
      case 'ngoai_mua':
        return const Color(0xFFE2703A);
      case 'cat_tia':
      case 'nay_mam':
        return const Color(0xFFE8A33D);
      default:
        return const Color(0xFF8A9BA8);
    }
  }

  static String tooltip(String code) => GardenTaskStyle.label(code);
}

/// Màu + icon của giai đoạn sinh trưởng.
class GardenStageStyle {
  static Color color(String stage) {
    switch (stage) {
      case 'gieo_trong':
        return AppColors.success;
      case 'dang_lon':
        return const Color(0xFFE8A33D);
      case 'ra_hoa':
        return const Color(0xFFD16BA5);
      case 'san_sang_thu_hoach':
        return const Color(0xFFE2703A);
      default:
        return const Color(0xFF8A9BA8);
    }
  }

  static IconData icon(String stage) {
    switch (stage) {
      case 'gieo_trong':
        return Icons.eco_rounded;
      case 'dang_lon':
        return Icons.spa_rounded;
      case 'ra_hoa':
        return Icons.local_florist_rounded;
      case 'san_sang_thu_hoach':
        return Icons.grass_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  static String label(String stage) => kGardenStageLabels[stage] ?? 'Mới gieo';
}

/// Chip nhỏ dùng chung (mùa vụ, giai đoạn, số liệu…).
class GardenChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;

  const GardenChip({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Chip có thể nằm trong Wrap/Grid (bề rộng hữu hạn) hoặc trong
          // Stack/Positioned (bề rộng vô hạn). Ta tự giới hạn bề rộng để nhãn
          // dài luôn được cắt bằng "…" thay vì tràn ra ngoài.
          final maxWidth = c.maxWidth.isFinite ? c.maxWidth : 220.0;
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 12, color: color),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Chip **lựa chọn** — dùng khi người dùng phải chọn 1 trong nhiều tuỳ chọn
/// (giai đoạn sinh trưởng, loại đất, nơi trồng…).
///
/// ⚠️ Vì sao không dùng [GardenChip] cho việc này?
/// [GardenChip] khi `filled = true` chỉ đổi nền sang màu nhạt (alpha 0.14)
/// → nhìn "đã chọn" và "chưa chọn" gần như giống nhau, người dùng không biết
/// mình đã bấm chưa. [GardenSelectChip] khi được chọn sẽ:
///   • nền ĐẬM MÀU (solid) thay vì nền nhạt
///   • chữ TRẮNG + in đậm (w800)
///   • có dấu TICK ✓ ở trước nhãn
///   • viền đậm + shadow nhẹ → nổi bật hẳn so với các chip chưa chọn.
class GardenSelectChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const GardenSelectChip({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : color;
    final bg = selected ? color : color.withValues(alpha: 0.07);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      elevation: selected ? 1.5 : 0,
      shadowColor: color.withValues(alpha: 0.45),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.28),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final maxWidth = c.maxWidth.isFinite ? c.maxWidth : 220.0;
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Dấu tick chỉ hiện khi đã chọn → nhìn là biết ngay.
                    if (selected) ...<Widget>[
                      Icon(Icons.check_rounded, size: 15, color: fg),
                      const SizedBox(width: 4),
                    ] else if (icon != null) ...<Widget>[
                      Icon(icon, size: 14, color: fg),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Chip mùa vụ — dùng `season.in_season` do server tính sẵn.
///
/// ⚠️ Nhãn được cố tình GIỮ NGẮN ("Đúng mùa" / "Ngoài mùa"). Khoảng thời gian
/// mùa vụ ("Tháng 3 - Tháng 10") hiển thị ở dòng riêng bên dưới, tránh làm
/// chip tràn ra ngoài thẻ cây trên màn hình hẹp.
class GardenSeasonChip extends StatelessWidget {
  final SeasonInfo? season;

  const GardenSeasonChip({super.key, this.season});

  @override
  Widget build(BuildContext context) {
    final s = season;
    if (s == null) {
      return const GardenChip(
        label: 'Chưa có lịch mùa vụ',
        color: Color(0xFF8A9BA8),
      );
    }
    if (!s.coMuaVu) {
      return const GardenChip(
        label: 'Chưa có lịch mùa vụ',
        color: Color(0xFF8A9BA8),
      );
    }
    if (s.inSeason) {
      return const GardenChip(
        label: 'Đúng mùa',
        icon: Icons.eco_rounded,
        color: AppColors.success,
        filled: true,
      );
    }
    return const GardenChip(
      label: 'Ngoài mùa',
      icon: Icons.schedule_rounded,
      color: Color(0xFFE2703A),
      filled: true,
    );
  }
}

/// Thẻ giấy bo góc dùng chung cho các card trong vườn.
class GardenCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GardenCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurfaceVariant : Colors.white;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.4)
                : null,
            boxShadow: isDark
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Hình ảnh mạng có fallback icon (không crash khi ảnh lỗi).
class GardenNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  const GardenNetworkImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.eco_rounded,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.primary.withValues(alpha: 0.07),
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: 28,
        color: fallbackColor ?? AppColors.primary.withValues(alpha: 0.5),
      ),
    );

    if (url == null || url!.trim().isEmpty) return placeholder;

    return Image.network(
      url!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return placeholder;
      },
    );
  }
}

/// Nút chính theo màu hệ thống (xanh lá #1B4332).
class GardenPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? background;
  final bool expand;

  const GardenPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.background,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ?? AppColors.primary;
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );

    final button = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        disabledBackgroundColor: bg.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // ⚠️ Dùng `ElevatedButton.icon` khi có icon: bản `.icon` của Material
      // tự bọc nhãn trong `Flexible` → nhãn dài được cắt bằng "…" thay vì
      // tràn ra ngoài khung (lỗi RenderFlex overflow trên màn hình hẹp).
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : (icon != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Flexible(child: labelWidget),
                    ],
                  )
                : labelWidget),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Nút phụ (outline) theo màu hệ thống.
class GardenOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool expand;

  const GardenOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.primary,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 17),
      // Nhãn dài được cắt bằng "…" để không tràn ra ngoài khung nút.
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Hiển thị lỗi dạng banner (không crash, có nút thử lại).
class GardenErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const GardenErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3C4C4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFD64545),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8A2B2B),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD64545),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Thử lại',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// Banner cảnh báo màu cam (mùa vụ, ngoài mùa, cần hành động).
class GardenWarningBanner extends StatelessWidget {
  final String message;
  final IconData icon;

  const GardenWarningBanner({
    super.key,
    required this.message,
    this.icon = Icons.warning_amber_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF7D9AE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFE2703A),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8A4B12),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner cảnh báo đỏ — CHỈ dùng cho nguy hiểm thật sự (cây chết, loài độc).
///
/// ⚠️ KHÔNG dùng đỏ cho mọi cảnh báo y tế / mùa vụ — đỏ khiến người dùng
/// hoảng và tưởng app báo lỗi. Cảnh báo thường → [GardenWarningBanner] (cam).
class GardenDangerBanner extends StatelessWidget {
  final String message;

  const GardenDangerBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3C4C4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.report_gmailerrorred_rounded,
            color: Color(0xFFD64545),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8A2B2B),
                fontSize: 12.5,
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

/// Nút xác nhận **TO** — dùng cho hành động kết thúc 1 luồng (VD: "Xác nhận
/// thêm cây vào vườn").
///
/// Khác [GardenPrimaryButton]: nút này CAO hơn (58px), chữ lớn hơn (16px),
/// bo góc lớn (18px) và có shadow → nổi bật như 1 CTA chính trên màn hình.
class GardenBigConfirmButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? background;
  final String? hint;

  const GardenBigConfirmButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.background,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ?? AppColors.primary;
    final enabled = onPressed != null && !loading;

    final button = ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        disabledBackgroundColor: bg.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white70,
        elevation: enabled ? 4 : 0,
        shadowColor: bg.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 22, color: Colors.white),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        button,
        if (hint != null && hint!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}

/// Banner thông tin (màu xanh nhạt).
class GardenInfoBanner extends StatelessWidget {
  final String message;
  final IconData icon;

  const GardenInfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.primary, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.92),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Định dạng ngày kiểu Việt Nam (dd/MM/yyyy).
String gardenFormatDate(DateTime? date) {
  if (date == null) return '—';
  final d = date.toLocal();
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

/// Định dạng ngày giờ ngắn (dd/MM · HH:mm).
String gardenFormatDateTime(DateTime? date) {
  if (date == null) return '—';
  final d = date.toLocal();
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '$dd/$mm · $hh:$mi';
}

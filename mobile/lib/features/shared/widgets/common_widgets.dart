import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/verified_tick.dart';

/// Strong ease-out used for UI motion (matches the web `--ease-out`).
const Curve kEaseOut = Cubic(0.23, 1, 0.32, 1);

/// Tactile press feedback for custom tappable surfaces (CTA cards, tiles).
/// The child shrinks very slightly while pressed and eases back on release.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.98,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? widget.pressedScale : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 180),
        curve: kEaseOut,
        child: widget.child,
      ),
    );
  }
}

/// One-shot entrance: fades in while rising a few pixels. Use it for the
/// first screenful of a page; stagger siblings with [delay] (30-80ms steps).
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 14,
  });

  static const _duration = Duration(milliseconds: 340);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    final total = _duration + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;
    final curve = Interval(start, 1, curve: kEaseOut);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: curve,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * offsetY), child: child),
      ),
    );
  }
}

/// Uniform AppCard with 18px radius, subtle border and light shadow.
/// Tappable cards give a short press-scale so they feel responsive.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (value) {
          if (_pressed != value && mounted) setState(() => _pressed = value);
        },
        borderRadius: AppTheme.radiusCard,
        child: content,
      );
    }

    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedScale(
      scale: _pressed && !reduceMotion ? 0.985 : 1,
      duration: Duration(milliseconds: _pressed ? 90 : 180),
      curve: kEaseOut,
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Colors.white,
          borderRadius: AppTheme.radiusCard,
          border: Border.all(
            color: widget.borderColor ?? AppTheme.slate200,
            width: 1,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppTheme.radiusCard,
          child: content,
        ),
      ),
    );
  }
}

/// Turkish-aware upper case for short labels (i -> İ, ı -> I).
String _trUpperLabel(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Section header with title, subtitle, and optional trailing action.
class SectionHeader extends StatelessWidget {
  /// Small quiet label above the title (web homepage "eyebrow").
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    _trUpperLabel(eyebrow!),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionText != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText!,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            )
          else
            ?trailing,
        ],
      ),
    );
  }
}

/// Centralized status badge supporting all domain statuses
class StatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;
  final bool isSmall;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _resolveStatus(status);
    final label = customLabel ?? config.label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 10,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: config.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isSmall ? 5 : 6,
            height: isSmall ? 5 : 6,
            decoration: BoxDecoration(
              color: config.textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  static _BadgeConfig _resolveStatus(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
      case 'PENDING':
      case 'REQUESTED':
        return const _BadgeConfig(
          label: 'Beklemede',
          textColor: AppTheme.info,
          backgroundColor: AppTheme.infoLight,
          borderColor: Color(0xFFBFDBFE),
        );
      case 'ASSIGNED':
      case 'ACCEPTED':
        return const _BadgeConfig(
          label: 'Atandı',
          textColor: Color(0xFFD97706),
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFFDE68A),
        );
      case 'CONFIRMED':
        return const _BadgeConfig(
          label: 'Onaylandı',
          textColor: AppTheme.success,
          backgroundColor: AppTheme.successLight,
          borderColor: Color(0xFFBBF7D0),
        );
      case 'ALTERNATIVE_PROPOSED':
        return const _BadgeConfig(
          label: 'Alternatif Önerildi',
          textColor: Color(0xFF7C3AED),
          backgroundColor: Color(0xFFEDE9FE),
          borderColor: Color(0xFFDDD6FE),
        );
      case 'IN_PROGRESS':
        return const _BadgeConfig(
          label: 'Devam Ediyor',
          textColor: AppTheme.primary,
          backgroundColor: AppTheme.primaryLight,
          borderColor: Color(0xFFFFCCBC),
        );
      case 'AWAITING_CUSTOMER_CONFIRMATION':
      case 'AWAITING_CONFIRMATION':
        return const _BadgeConfig(
          label: 'Onay Bekliyor',
          textColor: Color(0xFF9333EA),
          backgroundColor: Color(0xFFF3E8FF),
          borderColor: Color(0xFFE9D5FF),
        );
      case 'PAID':
        return const _BadgeConfig(
          label: 'Ödeme Alındı',
          textColor: AppTheme.success,
          backgroundColor: AppTheme.successLight,
          borderColor: Color(0xFFBBF7D0),
        );
      case 'PAYMENT_PENDING':
      case 'AWAITING_PAYMENT':
        return const _BadgeConfig(
          label: 'Ödeme Bekleniyor',
          textColor: Color(0xFFD97706),
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFFDE68A),
        );
      case 'AUTHORIZED':
        return const _BadgeConfig(
          label: 'Ön Onaylı',
          textColor: AppTheme.info,
          backgroundColor: AppTheme.infoLight,
          borderColor: Color(0xFFBFDBFE),
        );
      case 'REFUND_PENDING':
      case 'REFUND_PROCESSING':
      case 'REFUND_REQUESTED':
        return const _BadgeConfig(
          label: 'İade İşleniyor',
          textColor: AppTheme.info,
          backgroundColor: AppTheme.infoLight,
          borderColor: Color(0xFFBFDBFE),
        );
      case 'REFUNDED':
        return const _BadgeConfig(
          label: 'İade Edildi',
          textColor: AppTheme.success,
          backgroundColor: AppTheme.successLight,
          borderColor: Color(0xFFBBF7D0),
        );
      case 'PARTIALLY_REFUNDED':
        return const _BadgeConfig(
          label: 'Kısmi İade',
          textColor: Color(0xFFD97706),
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFFDE68A),
        );
      case 'SUBMITTED':
      case 'UNDER_REVIEW':
      case 'IN_REVIEW':
        return const _BadgeConfig(
          label: 'İnceleniyor',
          textColor: Color(0xFFD97706),
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFFDE68A),
        );
      case 'APPROVED':
        return const _BadgeConfig(
          label: 'Onaylandı',
          textColor: AppTheme.success,
          backgroundColor: AppTheme.successLight,
          borderColor: Color(0xFFBBF7D0),
        );
      case 'REUPLOAD_REQUIRED':
        return const _BadgeConfig(
          label: 'Belge Yenileme Gerekli',
          textColor: AppTheme.error,
          backgroundColor: AppTheme.errorLight,
          borderColor: Color(0xFFFECACA),
        );
      case 'RESOLVED':
        return const _BadgeConfig(
          label: 'Çözüldü',
          textColor: AppTheme.success,
          backgroundColor: AppTheme.successLight,
          borderColor: Color(0xFFBBF7D0),
        );
      case 'COMPLETED':
      case 'SETTLED':
        return const _BadgeConfig(
          label: 'Tamamlandı',
          textColor: AppTheme.success,
          backgroundColor: AppTheme.successLight,
          borderColor: Color(0xFFBBF7D0),
        );
      case 'DISPUTED':
      case 'MANUAL_REVIEW':
        return const _BadgeConfig(
          label: 'Uyuşmazlık',
          textColor: AppTheme.error,
          backgroundColor: AppTheme.errorLight,
          borderColor: Color(0xFFFECACA),
        );
      case 'CANCELLED':
      case 'REJECTED':
      case 'EXPIRED':
      case 'FAILED':
        return const _BadgeConfig(
          label: 'İptal / Reddedildi',
          textColor: AppTheme.slate600,
          backgroundColor: AppTheme.slate100,
          borderColor: AppTheme.slate200,
        );
      default:
        return _BadgeConfig(
          label: status,
          textColor: AppTheme.slate600,
          backgroundColor: AppTheme.slate100,
          borderColor: AppTheme.slate200,
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  const _BadgeConfig({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}

/// Empty state widget with icon, title, message, and optional CTA button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onAction;
  final Key? actionKey;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionText,
    this.onAction,
    this.actionKey,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.slate100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppTheme.slate400,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                key: actionKey,
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.radiusButton,
                  ),
                ),
                child: Text(
                  actionText!,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state widget with clean error presentation and retry action.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryText;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryText = 'Tekrar Dene',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bir Hata Oluştu',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18, color: AppTheme.textPrimary),
                label: Text(
                  retryText,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.slate200),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.radiusButton,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading state / Shimmer-style placeholder.
class LoadingState extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius? borderRadius;

  const LoadingState({
    super.key,
    this.height = 80,
    this.width = double.infinity,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: borderRadius ?? AppTheme.radiusCard,
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
      ),
    );
  }
}

/// Avatar with initials or photo and optional verified badge.
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final bool isVerified;
  final Color? backgroundColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 24,
    this.isVerified = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'B';
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? AppTheme.primaryLight,
          backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
          child: !hasImage
              ? Text(
                  initial,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: radius * 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                )
              : null,
        ),
        if (isVerified)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const VerifiedTick(size: 16),
            ),
          ),
      ],
    );
  }
}

/// Formatted Price Text (e.g. ₺350 or 350.00 TL)
class PriceText extends StatelessWidget {
  final num amount;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;

  const PriceText({
    super.key,
    required this.amount,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
    return Text(
      '₺$formatted',
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppTheme.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Reusable info key-value row with optional icon.
class InfoRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const InfoRow({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppTheme.slate500),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable bottom sheet helper with rounded top corners and drag handle.
class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: AppTheme.radiusSheet,
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    );
  }
}

/// Confirmation Dialog with clean buttons and title.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Onayla',
    this.cancelText = 'Vazgeç',
    this.isDestructive = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Onayla',
    String cancelText = 'Vazgeç',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppTheme.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelText,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppTheme.error : AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child: Text(
            confirmText,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Legacy button kept for complete backwards compatibility.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final Widget? icon;
  final double? height;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppTheme.primary;
    final fg = textColor ?? Colors.white;

    return SizedBox(
      height: height ?? 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusButton,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Primary action button (Brand Orange)
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final double? height;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      height: height,
      backgroundColor: AppTheme.primary,
      textColor: Colors.white,
    );
  }
}

/// Secondary action button (Dark Navy or Slate)
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final double? height;

  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      height: height,
      backgroundColor: AppTheme.darkNavy,
      textColor: Colors.white,
    );
  }
}

/// Outline button (White/Transparent with subtle border)
class OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final double? height;
  final Color? borderColor;
  final Color? textColor;

  const OutlineButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? AppTheme.slate200;
    final fg = textColor ?? AppTheme.textPrimary;

    return SizedBox(
      height: height ?? 50,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusButton,
          ),
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Danger/Destructive button (Accessible Red)
class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Widget? icon;
  final double? height;

  const DangerButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlineButton(
        text: text,
        onPressed: onPressed,
        isLoading: isLoading,
        icon: icon,
        height: height,
        borderColor: AppTheme.error,
        textColor: AppTheme.error,
      );
    }

    return CustomButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      height: height,
      backgroundColor: AppTheme.error,
      textColor: Colors.white,
    );
  }
}

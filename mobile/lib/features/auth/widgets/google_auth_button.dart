import 'package:flutter/material.dart';

class GoogleAuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleAuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Use the app's OutlinedButton theme so Google matches the Apple button
    // exactly: same height, border, radius, typography and disabled state.
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4285F4),
              ),
            )
          else
            Image.asset(
              'assets/brand/google-g.png',
              width: 20,
              height: 20,
              excludeFromSemantics: true,
            ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../utils/custom_color.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double radius;
  final double size;
  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.radius = 0,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(

      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: CustomColor.tabColor,
          minimumSize: Size(double.infinity, size),
          maximumSize: Size(double.infinity, size),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),

          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: CustomColor.white,
          ),
        ),
      ),
    );
  }
}

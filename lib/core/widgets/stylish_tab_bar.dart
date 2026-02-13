import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StylishTabBar extends StatelessWidget {
  final TabController controller;
  final List<Tab> tabs;

  const StylishTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple1.withValues(alpha: 0.1),
            AppColors.orange1.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: controller,
        tabs: tabs,
        indicator: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple1.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.darkGrey,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(25),
      ),
    );
  }
}

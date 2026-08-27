import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/calendar_day.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/xp_pill.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  NoriUser? _user;
  CalendarMonthStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AppData.user.getCurrentUser();
    final stats = await AppData.calendar.getCurrentMonth();
    if (!mounted) return;
    setState(() {
      _user = user;
      _stats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final stats = _stats;

    return Scaffold(
      body: SafeArea(
        child: user == null || stats == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  final horizontalPadding = isWide
                      ? AppSpacing.containerPaddingDesktop
                      : AppSpacing.containerPaddingMobile;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.gutter,
                      horizontalPadding,
                      AppSpacing.stackLg,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CalendarHeader(user: user),
                            const SizedBox(height: AppSpacing.stackLg),
                            Text(
                              stats.monthLabel,
                              textAlign: TextAlign.center,
                              style: isWide
                                  ? AppTextStyles.headlineLg
                                  : AppTextStyles.headlineLgMobile,
                            ),
                            const SizedBox(height: AppSpacing.unit),
                            Text(
                              'Stay consistent to level up your Nori!',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: isWide ? 4 : 2,
                              crossAxisSpacing: AppSpacing.gutter,
                              mainAxisSpacing: AppSpacing.gutter,
                              childAspectRatio: isWide ? 1.35 : 1.15,
                              children: [
                                _CalendarStatCard(
                                  icon: Icons.local_fire_department,
                                  iconColor: AppColors.primary,
                                  value: '${stats.currentStreak}',
                                  label: 'Current Streak',
                                ),
                                _CalendarStatCard(
                                  icon: Icons.star,
                                  iconColor: AppColors.tertiaryFixedDim,
                                  value: '${stats.perfectDays}',
                                  label: 'Perfect Days',
                                ),
                                _CalendarStatCard(
                                  icon: Icons.check_circle,
                                  iconColor: AppColors.secondary,
                                  value: '${stats.habitsDone}',
                                  label: 'Habits Done',
                                ),
                                _CalendarStatCard(
                                  icon: Icons.sentiment_dissatisfied,
                                  iconColor: AppColors.outline,
                                  value: '${stats.missedDays}',
                                  label: 'Missed Days',
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                            _CalendarCard(days: stats.days),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({required this.user});

  final NoriUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NoriAvatar(imageUrl: user.avatarUrl),
        const SizedBox(width: AppSpacing.stackSm),
        Expanded(
          child: Text(
            'Nori',
            style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary),
          ),
        ),
        XpPill(xp: user.totalXp),
      ],
    );
  }
}

class _CalendarStatCard extends StatelessWidget {
  const _CalendarStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: iconColor),
          const SizedBox(height: AppSpacing.unit),
          Text(value, style: AppTextStyles.headlineMd),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSm,
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.days});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final List<CalendarDay> days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final weekday in _weekdays)
                Expanded(
                  child: Text(
                    weekday,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSm,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 1,
            crossAxisSpacing: AppSpacing.unit,
            mainAxisSpacing: AppSpacing.unit,
            children: [for (final day in days) _CalendarDayCell(day: day)],
          ),
          const SizedBox(height: AppSpacing.stackMd),
          Divider(color: AppColors.surfaceVariant, height: 1),
          const SizedBox(height: AppSpacing.gutter),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.gutter,
            runSpacing: AppSpacing.unit,
            children: [
              _LegendItem(
                color: AppColors.tertiaryFixed,
                borderColor: AppColors.tertiaryFixedDim,
                label: 'Perfect',
              ),
              _LegendItem(
                color: AppColors.secondaryContainer,
                borderColor: AppColors.secondaryFixedDim,
                label: 'Done',
              ),
              _LegendItem(
                color: AppColors.surfaceVariant,
                borderColor: AppColors.outlineVariant,
                label: 'Missed',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context) {
    if (day.status == CalendarDayStatus.empty) {
      return const SizedBox.shrink();
    }

    final (
      backgroundColor,
      borderColor,
      borderWidth,
      textColor,
    ) = switch (day.status) {
      CalendarDayStatus.perfect => (
        AppColors.tertiaryFixed,
        AppColors.tertiaryFixedDim,
        2.0,
        AppColors.onTertiaryFixed,
      ),
      CalendarDayStatus.done => (
        AppColors.secondaryContainer,
        AppColors.secondaryFixedDim,
        1.0,
        AppColors.onSecondaryContainer,
      ),
      CalendarDayStatus.missed => (
        AppColors.surfaceVariant,
        AppColors.outlineVariant,
        1.0,
        AppColors.onSurfaceVariant,
      ),
      CalendarDayStatus.today => (
        AppColors.primary,
        AppColors.primaryFixedDim,
        3.0,
        AppColors.onPrimary,
      ),
      CalendarDayStatus.future => (
        AppColors.surface,
        AppColors.outlineVariant.withValues(alpha: 0.45),
        1.0,
        AppColors.outlineVariant,
      ),
      CalendarDayStatus.empty => throw StateError('Empty days return early'),
    };

    final isPerfect = day.status == CalendarDayStatus.perfect;
    final isToday = day.status == CalendarDayStatus.today;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm * 0.55),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.24),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isPerfect)
            Positioned(
              top: 3,
              right: 3,
              child: Icon(
                Icons.star,
                size: 13,
                color: AppColors.tertiaryFixedDim,
              ),
            ),
          Text(
            '${day.day}',
            style: AppTextStyles.bodyMd.copyWith(
              color: textColor,
              fontWeight: isPerfect || isToday
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.borderColor,
    required this.label,
  });

  final Color color;
  final Color borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor),
          ),
        ),
        const SizedBox(width: AppSpacing.unit),
        Text(label, style: AppTextStyles.labelSm),
      ],
    );
  }
}

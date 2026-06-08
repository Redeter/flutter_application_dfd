import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../theme/app_colors.dart';

class ConditionDetailsScreen extends StatelessWidget {
  const ConditionDetailsScreen({
    super.key,
    required this.condition,
  });

  final MentalCondition condition;

  static const Map<MentalCondition, String> _details = {
    MentalCondition.bipolar:
        'Биполярное расстройство — это состояние с эпизодами подъема и спада настроения. '
            'Важно поддерживать регулярный сон, отслеживать ранние признаки смены фаз и работать с врачом по плану терапии.',
    MentalCondition.depression:
        'Депрессия может проявляться снижением настроения, энергии, мотивации и нарушениями сна. '
            'Полезны регулярные записи состояния, постепенная поведенческая активация и наблюдение у специалиста.',
    MentalCondition.anxiety:
        'Тревожные расстройства сопровождаются постоянным напряжением, беспокойством и соматическими симптомами. '
            'Помогают техники дыхания, работа с триггерами и структурирование дня.',
    MentalCondition.bpd:
        'Пограничное расстройство связано с выраженной эмоциональной нестабильностью и импульсивностью. '
            'Полезны навыки эмоциональной регуляции, пауза перед реакцией и стабильный режим.',
    MentalCondition.ed:
        'Расстройства пищевого поведения затрагивают отношение к еде, телу и эмоциональной регуляции. '
            'Нужен комплексный подход с участием профильных специалистов.',
    MentalCondition.ptsd:
        'ПТСР может включать флешбеки, избегание, тревожность и гипервозбуждение после травмы. '
            'Важно мягко снижать перегрузку, использовать заземление и план безопасности.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(condition.label),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _details[condition] ?? 'Описание пока недоступно.',
            style: GoogleFonts.alegreyaSans(
              fontSize: 16,
              height: 1.45,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

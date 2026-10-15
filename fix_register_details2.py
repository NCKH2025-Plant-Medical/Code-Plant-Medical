import re
with open('D:/NCKH2026/PlantVision/lib/screens/auth/register_details_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('AppColors.primary.withOpacity(0.5)', 'AppColors.primary.withValues(alpha: 0.5)')

with open('D:/NCKH2026/PlantVision/lib/screens/auth/register_details_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

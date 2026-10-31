import re

with open('D:/NCKH2026/PlantVision/lib/screens/account_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace(
    'Widget _buildLogoutButton(bool isLoggingOut, AuthNotifier authNotifier) {',
    'Widget _buildLogoutButton(BuildContext context, bool isLoggingOut, AuthNotifier authNotifier) {'
)

text = text.replace(
    '_buildLogoutButton(isLoggingOut, authNotifier),',
    '_buildLogoutButton(context, isLoggingOut, authNotifier),'
)

with open('D:/NCKH2026/PlantVision/lib/screens/account_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)

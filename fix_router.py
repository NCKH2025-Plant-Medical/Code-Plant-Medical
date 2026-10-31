import re

with open('D:/NCKH2026/NCKH/API/auth/router.py', 'r', encoding='utf-8') as f:
    text = f.read()

new_endpoint = '''@router.get(
    "/check-username",
    summary="Check if a username is already taken",
)
async def check_username(username: str):
    \"\"\"
    Check if a username is already registered.
    Returns {"available": True} if it is free, False otherwise.
    \"\"\"
    collection = get_user_collection()
    existing = await collection.find_one({"username": username})
    
    return {"available": existing is None}

@router.post(
    "/register",'''

text = text.replace('@router.post(\n    "/register",', new_endpoint)

with open('D:/NCKH2026/NCKH/API/auth/router.py', 'w', encoding='utf-8') as f:
    f.write(text)

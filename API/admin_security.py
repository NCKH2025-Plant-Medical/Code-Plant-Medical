"""Server-side permission definitions for the admin API."""
from fastapi import APIRouter, Depends, HTTPException
from API.auth.utils import get_current_user

ROLE_PERMISSIONS = {
    "super_admin": frozenset({"users.read", "members.manage", "audit.read", "content.edit", "content.submit", "analytics.read"}),
    "botanist": frozenset({"content.edit", "content.submit", "content.approve", "dataset.label", "dataset.export", "audit.read", "analytics.read"}),
    "editor": frozenset({"content.edit", "content.submit", "analytics.read"}),
}

router = APIRouter(prefix="/api/admin", tags=["Admin"])


@router.get("/me")
async def admin_me(user=Depends(get_current_user)):
    from API.database import _DB_POOL
    if _DB_POOL is None:
        raise HTTPException(status_code=503, detail="Admin authorization unavailable")
    conn = _DB_POOL.get_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute("SELECT role, active FROM admin_membership WHERE user_id = %s", (str(user['_id']),))
            membership = cursor.fetchone()
        finally:
            cursor.close()
    finally:
        conn.close()
    if not membership or not membership['active'] or membership['role'] not in ROLE_PERMISSIONS:
        raise HTTPException(status_code=403, detail="Insufficient admin permission")
    return {"user_id": str(user['_id']), "role": membership['role'], "permissions": sorted(ROLE_PERMISSIONS[membership['role']])}


def require_permission(permission):
    async def dependency(user=Depends(get_current_user)):
        # Membership is read on every request so revocation takes effect immediately.
        from API.database import _DB_POOL
        if _DB_POOL is None:
            raise HTTPException(status_code=503, detail="Admin authorization unavailable")
        conn = _DB_POOL.get_connection()
        try:
            cursor = conn.cursor(dictionary=True)
            try:
                cursor.execute("SELECT role, active FROM admin_membership WHERE user_id = %s", (str(user['_id']),))
                membership = cursor.fetchone()
            finally:
                cursor.close()
        finally:
            conn.close()
        if not membership or not membership['active'] or permission not in ROLE_PERMISSIONS.get(membership['role'], ()):
            raise HTTPException(status_code=403, detail="Insufficient admin permission")
        return user
    return dependency

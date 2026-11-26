# Hybrid navigation and sessions

Local routing uses the FOSSGIS pedestrian OSRM demo by default. For production configure WALKING_OSRM_URL with a pedestrian OSRM URL template containing {lng1},{lat1};{lng2},{lat2}. Public demo service: https://routing.openstreetmap.de/about.html. Do not use a driving profile as walking ETA.

A successful road route has route_kind=walking, points, duration_minutes, snapped_end_point and off_trail_points. Reference-only responses have no ETA. Protected trees remain non-navigable; other targets use public approximate coordinates.

Restart/rebuild the app after updates. Emulator sensors may be absent. Test physical-device heading and permissions in the field. Cached route retention is in-memory; this is not an offline map package.

Authentication remains on AUTH_URL (cloud by default). Deploy the updated auth backend there for rotation; changing only the local map server does not update cloud auth. Local and cloud APIs must accept the same issuer/signing configuration and user identifiers. Existing refresh tokens issued before session tracking require one new login. Logout revokes all refresh sessions for the account. Access tokens last 15–30 minutes, refresh tokens 30–90 days. MongoDB stores refresh-token hashes with TTL expiry, never raw refresh tokens.

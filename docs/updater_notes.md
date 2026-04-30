# Updater Notes

The updater is intentionally separate so the running launcher never has to replace itself.

## Current model

- launcher exits
- updater stages new version
- updater updates the current pointer file
- updater relaunches the app

## Production hardening still recommended

- signed update manifest
- rollback on failed startup
- download resume
- version pinning
- anti-downgrade logic

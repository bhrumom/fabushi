# Runbooks

## Download incident/recovery

1. Stop the batch on CAPTCHA, login challenge, redirect outside approved HTTPS hosts, unexpected content type, size bound, or disk-write error.
2. Preserve the redacted manifest and partial files; never publish Cookie headers.
3. Reauthenticate manually in Douyin if needed, reduce request rate, and retry failed items only.
4. Do not delete or overwrite prior downloads automatically.

## Marketplace rollback

Yank the affected release, restore the previous immutable catalog/package pointer, rerun browse/install E2E, and publish a strictly newer fixed version after protected-main acceptance.

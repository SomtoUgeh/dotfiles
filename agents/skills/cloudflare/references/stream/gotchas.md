# Stream Gotchas

## Common Errors

### "ERR_NON_VIDEO"

**Cause:** Uploaded file is not a valid video format
**Solution:** Ensure file is in supported format (MP4, MKV, MOV, AVI, FLV, MPEG-2 TS/PS, MXF, LXF, GXF, 3GP, WebM, MPG, QuickTime)

### "ERR_DURATION_EXCEED_CONSTRAINT"

**Cause:** Video duration exceeds `maxDurationSeconds` constraint
**Solution:** Increase `maxDurationSeconds` in direct upload config or trim video before upload

### "ERR_FETCH_ORIGIN_ERROR"

**Cause:** Failed to download video from URL (upload from URL)
**Solution:** Ensure URL is publicly accessible, uses HTTPS, and video file is available

### "ERR_MALFORMED_VIDEO"

**Cause:** Video file is corrupted or improperly encoded
**Solution:** Re-encode video using FFmpeg or check source file integrity

### "ERR_DURATION_TOO_SHORT"

**Cause:** Video must be at least 0.1 seconds long
**Solution:** Ensure video has valid duration (not a single frame)

## Troubleshooting

### Video stuck in "inprogress" state
- **Cause**: Processing large/complex video
- **Solution**: Processing time varies; use webhooks and surface prolonged processing without promising a fixed deadline

### Signed URL returns 403
- **Cause**: Token expired or invalid signature
- **Solution**: Check expiration timestamp, verify JWK is correct, ensure clock sync

### Live stream not connecting
- **Cause**: Invalid RTMPS URL or stream key
- **Solution**: Use exact URL/key from API, ensure firewall allows outbound 443

### Webhook signature verification fails
- **Cause**: Incorrect secret or timestamp window
- **Solution**: Use exact secret from webhook setup, apply an application-chosen replay window (for example 5 minutes); verify the exact timestamp string and raw body

### Video uploads but isn't visible
- **Cause**: `requireSignedURLs` enabled without providing token
- **Solution**: Generate signed token or set `requireSignedURLs: false` for public videos

### Player shows infinite loading
- **Cause**: Origin restrictions or playback access configuration
- **Solution**: Add your domain to `allowedOrigins` array

## Limits

Basic POST direct creator uploads are limited to 200 MB; larger files require TUS (also preferable for unreliable connections). Stream's maximum file size is 30 GB. `maxDurationSeconds` reserves storage until upload completion/expiry, so enforce user quotas before provisioning URLs.

Use the current [upload guide](https://developers.cloudflare.com/stream/uploading-videos/direct-creator-uploads/) and [Stream FAQ](https://developers.cloudflare.com/stream/faq/) for plan/format limits. Do not infer a hard API token quota from guidance to self-sign at higher volume, or invent webhook retry counts, unlimited metadata, and fixed processing times.

## Performance Issues

### Upload is slow
- **Cause**: Large file size or network constraints
- **Solution**: Use TUS resumable upload, compress video before upload, check bandwidth

### Playback buffering
- **Cause**: Network congestion or low bandwidth
- **Solution**: Use ABR (adaptive bitrate) with HLS/DASH, reduce max bitrate

### High processing time
- **Cause**: Complex video codec, high resolution
- **Solution**: Pre-encode with H.264 (most efficient), reduce resolution

## Upload Response Handling

Check HTTP status before considering the upload successful. A successful basic direct upload need not return JSON. For SDK/API responses, validate the actual envelope and check `success`; do not apply that envelope assumption to every upload endpoint. Store the UID issued during provisioning and track processing separately.

## Security Gotchas

1. **Never expose API token in frontend** - Use direct creator uploads
2. **Always verify webhook signatures** - Prevent spoofed notifications
3. **Set appropriate token expiration** - Short-lived for security
4. **Use requireSignedURLs for private content** - Prevent unauthorized access
5. **Whitelist allowedOrigins** - Prevent hotlinking/embedding on unauthorized sites

## In This Reference

- [README.md](./README.md) - Overview and quick start
- [configuration.md](./configuration.md) - Setup and config
- [api.md](./api.md) - On-demand video APIs
- [api-live.md](./api-live.md) - Live streaming APIs
- [patterns.md](./patterns.md) - Full-stack flows, best practices

## See Also

- [workers](../workers/) - Deploy Stream APIs securely

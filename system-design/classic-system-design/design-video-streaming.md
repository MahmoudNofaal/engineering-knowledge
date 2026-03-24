# Video Streaming

> A system that encodes uploaded videos into multiple quality levels and delivers them to users with adaptive bitrate streaming via a CDN.

---

## When To Use It

Design a video streaming system when you need on-demand video playback at scale — think YouTube, Netflix, or TikTok. Don't build this infrastructure if you're embedding a few videos in a product; use a managed service (Cloudflare Stream, Mux, or S3 + CloudFront). The design challenge is the pipeline: raw uploads must be transcoded into multiple resolutions before they can be played, and delivery must be handled by a CDN — not your origin servers.

---

## Core Concept

Video streaming has two distinct phases. Phase 1 (upload + processing): user uploads a raw video file, a transcoding pipeline converts it into multiple bitrates/resolutions (360p, 720p, 1080p, 4K) and segments each into small chunks (2–10 seconds). Phase 2 (playback): the player downloads a manifest file (HLS `.m3u8` or DASH `.mpd`) that describes all available quality levels and their chunk URLs, then fetches chunks from the CDN. The player monitors bandwidth and automatically switches quality levels (Adaptive Bitrate Streaming, ABR). Your origin servers are only involved in upload and metadata — all video bytes flow through the CDN.

---

## The Code

```python
# Upload pipeline trigger — async transcoding on upload complete
import boto3
import json

sqs = boto3.client('sqs', region_name='us-east-1')
TRANSCODE_QUEUE = "https://sqs.us-east-1.amazonaws.com/123/transcode-jobs"

def on_video_uploaded(video_id: int, raw_s3_key: str, db):
    """Called after raw video is confirmed uploaded to S3."""
    # Update DB to 'processing' state
    db.execute(
        "UPDATE videos SET status = 'processing' WHERE id = %s", video_id
    )

    # Enqueue transcoding job
    job = {
        "video_id": video_id,
        "input_key": raw_s3_key,
        "output_prefix": f"videos/{video_id}/",
        "renditions": [
            {"resolution": "360p",  "bitrate": "800k"},
            {"resolution": "720p",  "bitrate": "2500k"},
            {"resolution": "1080p", "bitrate": "5000k"},
        ]
    }
    sqs.send_message(QueueUrl=TRANSCODE_QUEUE, MessageBody=json.dumps(job))
```

```python
# Transcoding worker (conceptual — uses ffmpeg under the hood)
import subprocess
import boto3
import json

s3 = boto3.client('s3')
BUCKET = "my-video-storage"

def transcode_video(job: dict):
    video_id = job["video_id"]
    input_key = job["input_key"]
    output_prefix = job["output_prefix"]

    # Download raw video locally
    local_input = f"/tmp/{video_id}_raw.mp4"
    s3.download_file(BUCKET, input_key, local_input)

    for rendition in job["renditions"]:
        res = rendition["resolution"]
        bitrate = rendition["bitrate"]
        output_dir = f"/tmp/{video_id}/{res}"

        # Use ffmpeg to segment into HLS chunks
        # -hls_time 6: each chunk is 6 seconds
        subprocess.run([
            "ffmpeg", "-i", local_input,
            "-vf", f"scale=-2:{res[:-1]}",  # e.g. scale=-2:720
            "-b:v", bitrate,
            "-hls_time", "6",
            "-hls_playlist_type", "vod",
            "-hls_segment_filename", f"{output_dir}/%03d.ts",
            f"{output_dir}/index.m3u8"
        ], check=True)

        # Upload chunks and manifest to S3
        for file in os.listdir(output_dir):
            s3.upload_file(
                f"{output_dir}/{file}",
                BUCKET,
                f"{output_prefix}{res}/{file}",
                ExtraArgs={"ContentType": "application/x-mpegURL" if file.endswith(".m3u8") else "video/MP2T"}
            )
```

```python
# Generate master HLS manifest listing all quality levels
def generate_master_manifest(video_id: int, renditions: list[dict]) -> str:
    """
    Creates the top-level .m3u8 that players use to discover quality options.
    Players automatically switch between renditions based on bandwidth.
    """
    lines = ["#EXTM3U", "#EXT-X-VERSION:3"]

    bandwidth_map = {"360p": 800000, "720p": 2500000, "1080p": 5000000}
    resolution_map = {"360p": "640x360", "720p": "1280x720", "1080p": "1920x1080"}

    for r in renditions:
        res = r["resolution"]
        lines.append(
            f'#EXT-X-STREAM-INF:BANDWIDTH={bandwidth_map[res]},'
            f'RESOLUTION={resolution_map[res]}'
        )
        lines.append(f"https://cdn.example.com/videos/{video_id}/{res}/index.m3u8")

    return "\n".join(lines)
```

```sql
-- Video metadata schema
CREATE TABLE videos (
    id              BIGINT PRIMARY KEY AUTO_INCREMENT,
    uploader_id     BIGINT NOT NULL,
    title           VARCHAR(255),
    status          ENUM('uploading', 'processing', 'ready', 'failed') DEFAULT 'uploading',
    raw_s3_key      VARCHAR(512),        -- Original upload location
    duration_sec    INT,
    thumbnail_key   VARCHAR(512),
    view_count      BIGINT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_uploader (uploader_id),
    INDEX idx_status (status)
);

CREATE TABLE video_renditions (
    id          BIGINT PRIMARY KEY AUTO_INCREMENT,
    video_id    BIGINT NOT NULL,
    resolution  VARCHAR(10),            -- e.g. '720p'
    manifest_key VARCHAR(512),          -- S3 key of the HLS manifest
    size_bytes  BIGINT,
    INDEX idx_video_id (video_id)
);
```

---

## Gotchas

- **Transcoding is CPU-intensive and slow**: A 1-hour video at 1080p can take 10–30 minutes to transcode. Run this on dedicated worker instances (GPU-accelerated if possible), never on your API servers. Use a job queue and show the user a "processing" state.
- **CDN cache invalidation for video edits**: If a creator replaces a video, the CDN may serve the old chunks until cache TTL expires. Either use versioned S3 keys (new upload = new prefix) or issue a CDN cache purge — don't reuse the same key for updated content.
- **Thumbnail generation**: Generate thumbnails as part of the transcoding pipeline, not at request time. Extract a frame at the 10% mark with ffmpeg and store it in S3. Generating on the fly for every request is a performance disaster.
- **Seeking in long videos**: HLS works by requesting specific `.ts` chunks. For a user seeking to the 45-minute mark, the player calculates which chunk number contains that timestamp from the manifest and fetches directly — no seek latency. This is a feature of the segmentation approach, not something you build.
- **Storage costs compound fast**: A 1-hour 1080p video is ~4GB raw. Storing 4 quality levels means ~8GB per video. At 1M videos, that's 8 petabytes. Use S3 Intelligent Tiering or Glacier for videos with low view counts.

---

## Interview Angle

**What they're really testing:** Async processing pipelines, CDN architecture, and the upload vs delivery path separation.

**Common question form:** "Design a video streaming service like YouTube. Handle uploads, processing, and playback."

**The depth signal:** A junior answer describes storing video files in S3 and serving them directly. A senior answer separates the write path (upload → transcode pipeline → S3) from the read path (CDN-only, origin never involved in playback), explains HLS segmentation and why the player can seek without server involvement, discusses adaptive bitrate streaming and where the bandwidth decision lives (the player, not the server), estimates storage costs per video and proposes tiered storage for cold content, and mentions that the transcoding pipeline must be idempotent — retrying a failed job shouldn't create duplicate renditions.

---

## Related Topics

- [[system-design/design-file-storage]] — Video storage is file storage with a transcoding pipeline added
- [[system-design/design-distributed-cache]] — Video metadata (not video bytes) is cached; bytes live in CDN
- [[system-design/design-rate-limiter]] — Upload endpoints need rate limits; streaming endpoints need bandwidth throttling

---

## Source

[HLS (HTTP Live Streaming) — Apple Developer Documentation](https://developer.apple.com/documentation/http-live-streaming)

---

*Last updated: 2026-03-24*
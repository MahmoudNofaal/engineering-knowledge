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

```csharp
// Upload pipeline trigger — async transcoding on upload complete
using Amazon.SQS;
using Amazon.SQS.Model;
using System.Text.Json;

public class VideoUploadService
{
    private readonly AmazonSQSClient _sqs;
    private const string TranscodeQueue = "https://sqs.us-east-1.amazonaws.com/123/transcode-jobs";

    public VideoUploadService()
    {
        _sqs = new AmazonSQSClient();
    }

    public async Task OnVideoUploadedAsync(int videoId, string rawS3Key, object db)
    {
        // Update DB to 'processing' state
        // db.Execute("UPDATE videos SET status = 'processing' WHERE id = @id", new { id = videoId });

        // Enqueue transcoding job
        var job = new
        {
            video_id = videoId,
            input_key = rawS3Key,
            output_prefix = $"videos/{videoId}/",
            renditions = new[]
            {
                new { resolution = "360p", bitrate = "800k" },
                new { resolution = "720p", bitrate = "2500k" },
                new { resolution = "1080p", bitrate = "5000k" },
            }
        };

        var request = new SendMessageRequest
        {
            QueueUrl = TranscodeQueue,
            MessageBody = JsonSerializer.Serialize(job)
        };
        await _sqs.SendMessageAsync(request);
    }
}
```

```csharp
// Transcoding worker (conceptual — FFmpeg is called via System.Diagnostics)
using Amazon.S3;
using System.Diagnostics;
using System.Text.Json;

public class TranscodingWorker
{
    private readonly AmazonS3Client _s3;
    private const string Bucket = "my-video-storage";

    public TranscodingWorker()
    {
        _s3 = new AmazonS3Client();
    }

    public async Task TranscodeVideoAsync(string jobJson)
    {
        var job = JsonSerializer.Deserialize<Dictionary<string, object>>(jobJson);
        var videoId = job["video_id"].ToString();
        var inputKey = job["input_key"].ToString();
        var outputPrefix = job["output_prefix"].ToString();

        // Download raw video locally
        var localInput = $"/tmp/{videoId}_raw.mp4";
        await _s3.GetObjectAsync(Bucket, inputKey, localInput);

        // Iterate over renditions
        var renditions = job["renditions"] as List<Dictionary<string, string>>;
        foreach (var rendition in renditions)
        {
            var res = rendition["resolution"];
            var bitrate = rendition["bitrate"];
            var outputDir = $"/tmp/{videoId}/{res}";
            Directory.CreateDirectory(outputDir);

            // Call ffmpeg to segment into HLS chunks
            var process = new ProcessStartInfo
            {
                FileName = "ffmpeg",
                Arguments = $" -i {localInput} -vf scale=-2:{res[..^1]} -b:v {bitrate} " +
                           $"-hls_time 6 -hls_playlist_type vod " +
                           $"-hls_segment_filename \"{outputDir}/%03d.ts\" \"{outputDir}/index.m3u8\"",
                RedirectStandardOutput = true,
                UseShellExecute = false
            };
            using var p = Process.Start(process);
            p.WaitForExit();

            // Upload chunks and manifest to S3
            foreach (var file in Directory.GetFiles(outputDir))
            {
                var contentType = file.EndsWith(".m3u8") ? "application/x-mpegURL" : "video/MP2T";
                await _s3.PutObjectAsync(new Amazon.S3.Model.PutObjectRequest
                {
                    BucketName = Bucket,
                    Key = $"{outputPrefix}{res}/{Path.GetFileName(file)}",
                    FilePath = file,
                    ContentType = contentType
                });
            }
        }
    }
}
```

```csharp
// Generate master HLS manifest listing all quality levels
public string GenerateMasterManifest(int videoId, List<(string Resolution, int Bitrate)> renditions)
{
    /*
    Creates the top-level .m3u8 that players use to discover quality options.
    Players automatically switch between renditions based on bandwidth.
    */
    var lines = new List<string> { "#EXTM3U", "#EXT-X-VERSION:3" };

    var resolutionMap = new Dictionary<string, string>
    {
        { "360p", "640x360" },
        { "720p", "1280x720" },
        { "1080p", "1920x1080" }
    };

    foreach (var (res, bandwidth) in renditions)
    {
        lines.Add($"#EXT-X-STREAM-INF:BANDWIDTH={bandwidth * 1000}," +
                 $"RESOLUTION={resolutionMap[res]}");
        lines.Add($"https://cdn.example.com/videos/{videoId}/{res}/index.m3u8");
    }

    return string.Join("\n", lines);
}
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
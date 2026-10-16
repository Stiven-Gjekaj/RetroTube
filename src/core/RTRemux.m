#import "RTRemux.h"
#import "RTTS.h"

const int64_t RTRemuxTimeOffset = 90000;

// The number of AAC frames in one audio PES packet.
static const NSUInteger RTAudioFramesPerPES = 8;

static int64_t RTTo90k(int64_t time, uint32_t timescale) {
    // Split the multiplication, so that a long video does not overflow.
    return (time / timescale) * 90000 + ((time % timescale) * 90000) / timescale;
}

static NSError *RTRemuxError(NSString *text) {
    return [NSError errorWithDomain:RTMP4ErrorDomain code:2 userInfo:@{ NSLocalizedDescriptionKey: text }];
}

NSData *RTRemuxSegment(RTMP4Track *video, NSData *videoData, RTMP4Track *audio, NSData *audioData,
                       double startSeconds, double endSeconds, NSError **error) {
    NSData *videoSamples = RTMP4ReadSamples(videoData, video, error);
    if (!videoSamples) return nil;
    NSData *audioSamples = audioData ? RTMP4ReadSamples(audioData, audio, error) : nil;
    if (audioData && !audioSamples) return nil;

    const RTMP4Sample *vs = videoSamples.bytes;
    NSUInteger videoCount = videoSamples.length / sizeof(RTMP4Sample);
    const RTMP4Sample *as = audioSamples.bytes;
    NSUInteger audioCount = audioSamples.length / sizeof(RTMP4Sample);
    const uint8_t *videoBytes = videoData.bytes, *audioBytes = audioData.bytes;
    int64_t edit = RTTo90k(video.editMediaTime, video.timescale);

    // Keep the audio frames that start in the time range.
    int64_t start90 = (int64_t)(startSeconds * 90000), end90 = (int64_t)(endSeconds * 90000);
    NSUInteger audioFirst = 0, audioEnd = 0;
    for (NSUInteger i = 0; i < audioCount; i++) {
        int64_t time = RTTo90k((int64_t)as[i].decodeTime, audio.timescale);
        if (time < start90) audioFirst = i + 1;
        if (time < end90) audioEnd = i + 1;
    }

    RTTSWriter *writer = [RTTSWriter new];
    writer.hasAudio = audio != nil;
    [writer writeTables];

    NSUInteger v = 0, a = audioFirst;
    while (v < videoCount || a < audioEnd) {
        int64_t videoDts = v < videoCount ? RTTo90k((int64_t)vs[v].decodeTime, video.timescale) - edit : INT64_MAX;
        int64_t audioPts = a < audioEnd ? RTTo90k((int64_t)as[a].decodeTime, audio.timescale) : INT64_MAX;
        if (videoDts <= audioPts) {
            const RTMP4Sample *s = &vs[v];
            NSData *annexB = RTTSAnnexB(videoBytes + s->dataOffset, s->size, video.nalLengthSize, video.sps, video.pps,
                                        s->isSync);
            if (!annexB) {
                if (error) *error = RTRemuxError(@"A video sample has a wrong NAL length.");
                return nil;
            }
            int64_t pts = videoDts + RTTo90k(s->compositionOffset, video.timescale);
            [writer writeVideo:annexB pts:pts + RTRemuxTimeOffset dts:videoDts + RTRemuxTimeOffset isSync:s->isSync];
            v++;
        } else {
            NSMutableData *frames = [NSMutableData data];
            NSUInteger last = MIN(a + RTAudioFramesPerPES, audioEnd);
            for (NSUInteger i = a; i < last; i++) {
                uint8_t header[7];
                RTTSWriteADTSHeader(header, audio.audioObjectType, audio.sampleRateIndex, audio.channelConfig, as[i].size);
                [frames appendBytes:header length:7];
                [frames appendBytes:audioBytes + as[i].dataOffset length:as[i].size];
            }
            [writer writeAudio:frames pts:audioPts + RTRemuxTimeOffset];
            a = last;
        }
    }
    return writer.output;
}

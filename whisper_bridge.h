#ifndef WHISPER_BRIDGE_H
#define WHISPER_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

struct whisper_context;

// v1.0.8 ENHANCEMENT: Timestamp-aware transcription result
typedef struct {
    char* text;
    float start_time;
    float end_time;
    int segment_count;
    float* segment_starts;
    float* segment_ends;
} whisper_timestamped_result;

// Simple C interface for Swift to use - renamed to avoid conflicts
struct whisper_context* whisper_bridge_init_context(const char* model_path);
void whisper_bridge_free_context(struct whisper_context* ctx);
char* whisper_bridge_transcribe(struct whisper_context* ctx, const float* samples, int n_samples);
char* whisper_bridge_transcribe_with_language(struct whisper_context* ctx, const float* samples, int n_samples, const char* language);

// v1.0.8 ENHANCEMENT: Timestamp-aware transcription for temporal filtering
whisper_timestamped_result* whisper_bridge_transcribe_with_timestamps(struct whisper_context* ctx, const float* samples, int n_samples, const char* language);
void whisper_bridge_free_timestamped_result(whisper_timestamped_result* result);
char* whisper_bridge_get_segment_text(struct whisper_context* ctx, int segment_index);

#ifdef __cplusplus
}
#endif

#endif // WHISPER_BRIDGE_H
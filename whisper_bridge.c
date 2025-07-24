#include "whisper_bridge.h"
#include "Vendor/whisper.cpp/include/whisper.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct whisper_context* whisper_bridge_init_context(const char* model_path) {
    printf("🎤 Real Whisper: Initializing with model: %s\n", model_path);
    
    struct whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = false; // Use CPU for compatibility
    
    struct whisper_context* ctx = whisper_init_from_file_with_params(model_path, cparams);
    
    if (ctx == NULL) {
        printf("❌ Real Whisper: Failed to initialize context from %s\n", model_path);
        return NULL;
    }
    
    printf("✅ Real Whisper: Context initialized successfully\n");
    return ctx;
}

void whisper_bridge_free_context(struct whisper_context* ctx) {
    if (ctx) {
        printf("🎤 Real Whisper: Freeing context\n");
        whisper_free(ctx);
    }
}

// Legacy function for backward compatibility
char* whisper_bridge_transcribe(struct whisper_context* ctx, const float* samples, int n_samples) {
    return whisper_bridge_transcribe_with_language(ctx, samples, n_samples, "en");
}

char* whisper_bridge_transcribe_with_language(struct whisper_context* ctx, const float* samples, int n_samples, const char* language) {
    // Allocate result string first
    char* result = (char*)malloc(512);
    if (!result) {
        printf("❌ Real Whisper: Memory allocation failed\n");
        return NULL;
    }
    result[0] = '\0'; // Initialize as empty string
    
    if (!ctx || !samples || n_samples <= 0) {
        printf("❌ Real Whisper: Invalid parameters\n");
        strcpy(result, "");
        return result;
    }
    
    printf("🔊 Real Whisper: Processing %d samples for language: %s...\n", n_samples, language ? language : "en");
    
    // Set up parameters for transcription with safer defaults
    struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.language = language ? language : "en"; // Use specified language
    wparams.translate = false;
    wparams.print_realtime = false;
    wparams.print_progress = false;
    wparams.print_timestamps = false;
    wparams.print_special = false;
    wparams.no_context = true;
    wparams.single_segment = true;
    wparams.suppress_blank = true;
    wparams.n_threads = 4; // Use more threads for medium model
    
    // Run transcription with error handling
    int transcription_result = whisper_full(ctx, wparams, samples, n_samples);
    
    if (transcription_result != 0) {
        printf("❌ Real Whisper: Transcription failed with code %d\n", transcription_result);
        strcpy(result, "");
        return result;
    }
    
    // Get the number of segments safely
    int n_segments = whisper_full_n_segments(ctx);
    if (n_segments <= 0) {
        printf("📝 Real Whisper: No speech detected\n");
        strcpy(result, "");
        return result;
    }
    
    printf("📝 Real Whisper: Found %d segments\n", n_segments);
    
    // Extract text from segments with bounds checking
    for (int i = 0; i < n_segments && i < 10; ++i) { // Limit to 10 segments max
        const char* text = whisper_full_get_segment_text(ctx, i);
        if (text && strlen(text) > 0) {
            // Check if we have space left (leave room for null terminator)
            size_t current_len = strlen(result);
            size_t text_len = strlen(text);
            if (current_len + text_len < 510) { // Leave space for null terminator
                strcat(result, text);
            } else {
                printf("⚠️ Real Whisper: Result truncated to prevent overflow\n");
                break;
            }
        }
    }
    
    // Simple trim - remove leading/trailing spaces
    char* start = result;
    while (*start == ' ') start++;
    
    if (start != result) {
        memmove(result, start, strlen(start) + 1);
    }
    
    // Remove trailing spaces
    char* end = result + strlen(result) - 1;
    while (end >= result && *end == ' ') {
        *end = '\0';
        end--;
    }
    
    if (strlen(result) > 0) {
        printf("📝 Real Whisper: Transcribed: '%s'\n", result);
    } else {
        printf("📝 Real Whisper: Empty transcription result\n");
    }
    
    return result;
}

// v1.0.8 ENHANCEMENT: Timestamp-aware transcription for temporal filtering
whisper_timestamped_result* whisper_bridge_transcribe_with_timestamps(struct whisper_context* ctx, const float* samples, int n_samples, const char* language) {
    // Allocate result structure
    whisper_timestamped_result* result = (whisper_timestamped_result*)malloc(sizeof(whisper_timestamped_result));
    if (!result) {
        printf("❌ Real Whisper: Memory allocation failed for timestamped result\n");
        return NULL;
    }
    
    // Initialize result structure
    result->text = (char*)malloc(512);
    if (!result->text) {
        free(result);
        printf("❌ Real Whisper: Memory allocation failed for text\n");
        return NULL;
    }
    result->text[0] = '\0';
    result->start_time = 0.0f;
    result->end_time = 0.0f;
    result->segment_count = 0;
    result->segment_starts = NULL;
    result->segment_ends = NULL;
    
    if (!ctx || !samples || n_samples <= 0) {
        printf("❌ Real Whisper: Invalid parameters for timestamp transcription\n");
        return result;
    }
    
    printf("🔊 Real Whisper: Processing %d samples with timestamps for language: %s...\n", n_samples, language ? language : "en");
    
    // Set up parameters for transcription with timestamps enabled
    struct whisper_full_params wparams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    wparams.language = language ? language : "en";
    wparams.translate = false;
    wparams.print_realtime = false;
    wparams.print_progress = false;
    wparams.print_timestamps = true; // Enable timestamps
    wparams.print_special = false;
    wparams.no_context = false; // Enable context for better accuracy
    wparams.single_segment = false; // Allow multiple segments for timestamp accuracy
    wparams.suppress_blank = true;
    wparams.n_threads = 4;
    
    // Run transcription with error handling
    int transcription_result = whisper_full(ctx, wparams, samples, n_samples);
    
    if (transcription_result != 0) {
        printf("❌ Real Whisper: Timestamped transcription failed with code %d\n", transcription_result);
        return result;
    }
    
    // Get the number of segments
    int n_segments = whisper_full_n_segments(ctx);
    if (n_segments <= 0) {
        printf("📝 Real Whisper: No speech detected in timestamp transcription\n");
        return result;
    }
    
    printf("📝 Real Whisper: Found %d segments with timestamps\n", n_segments);
    
    // Allocate arrays for segment timestamps
    result->segment_count = n_segments;
    result->segment_starts = (float*)malloc(n_segments * sizeof(float));
    result->segment_ends = (float*)malloc(n_segments * sizeof(float));
    
    if (!result->segment_starts || !result->segment_ends) {
        printf("❌ Real Whisper: Memory allocation failed for segment timestamps\n");
        return result;
    }
    
    // Extract text and timestamps from segments
    for (int i = 0; i < n_segments && i < 10; ++i) {
        const char* text = whisper_full_get_segment_text(ctx, i);
        int64_t start_time = whisper_full_get_segment_t0(ctx, i);
        int64_t end_time = whisper_full_get_segment_t1(ctx, i);
        
        // Convert timestamps from centiseconds to seconds
        float start_seconds = (float)start_time / 100.0f;
        float end_seconds = (float)end_time / 100.0f;
        
        result->segment_starts[i] = start_seconds;
        result->segment_ends[i] = end_seconds;
        
        // Set overall start and end times
        if (i == 0) {
            result->start_time = start_seconds;
        }
        if (i == n_segments - 1) {
            result->end_time = end_seconds;
        }
        
        if (text && strlen(text) > 0) {
            // Check if we have space left
            size_t current_len = strlen(result->text);
            size_t text_len = strlen(text);
            if (current_len + text_len < 510) {
                strcat(result->text, text);
                printf("📝 Segment %d: %.2fs-%.2fs: '%s'\n", i, start_seconds, end_seconds, text);
            } else {
                printf("⚠️ Real Whisper: Timestamped result truncated to prevent overflow\n");
                break;
            }
        }
    }
    
    // Simple trim - remove leading/trailing spaces
    char* start = result->text;
    while (*start == ' ') start++;
    
    if (start != result->text) {
        memmove(result->text, start, strlen(start) + 1);
    }
    
    // Remove trailing spaces
    char* end = result->text + strlen(result->text) - 1;
    while (end >= result->text && *end == ' ') {
        *end = '\0';
        end--;
    }
    
    if (strlen(result->text) > 0) {
        printf("📝 Real Whisper: Timestamped transcription: '%.50s...' (%.2fs-%.2fs)\n", 
               result->text, result->start_time, result->end_time);
    } else {
        printf("📝 Real Whisper: Empty timestamped transcription result\n");
    }
    
    return result;
}

// v1.0.8 ENHANCEMENT: Free timestamped result structure
void whisper_bridge_free_timestamped_result(whisper_timestamped_result* result) {
    if (result) {
        if (result->text) {
            free(result->text);
        }
        if (result->segment_starts) {
            free(result->segment_starts);
        }
        if (result->segment_ends) {
            free(result->segment_ends);
        }
        free(result);
    }
}

// v1.0.8 ENHANCEMENT: Extract individual segment text for precise temporal filtering
char* whisper_bridge_get_segment_text(struct whisper_context* ctx, int segment_index) {
    if (!ctx || segment_index < 0) {
        return NULL;
    }
    
    // Get the number of segments from the last transcription
    int n_segments = whisper_full_n_segments(ctx);
    if (segment_index >= n_segments) {
        return NULL;
    }
    
    // Get the segment text
    const char* segment_text = whisper_full_get_segment_text(ctx, segment_index);
    if (!segment_text) {
        return NULL;
    }
    
    // Allocate memory for the result
    size_t text_len = strlen(segment_text);
    char* result = (char*)malloc(text_len + 1);
    if (!result) {
        return NULL;
    }
    
    // Copy the text
    strcpy(result, segment_text);
    
    // Trim whitespace
    char* start = result;
    while (*start == ' ') start++;
    
    if (start != result) {
        memmove(result, start, strlen(start) + 1);
    }
    
    // Remove trailing spaces
    char* end = result + strlen(result) - 1;
    while (end >= result && *end == ' ') {
        *end = '\0';
        end--;
    }
    
    return result;
}
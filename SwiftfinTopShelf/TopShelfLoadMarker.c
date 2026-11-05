//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

// TEMPORARY: records that the system loaded the top shelf extension's binary,
// before any extension or Swift code runs, in the extension's own container.

#include <execinfo.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static void topShelfWriteMarker(const char *message) {
    const char *home = getenv("HOME");
    if (home == NULL) {
        return;
    }

    char path[1024];
    snprintf(path, sizeof(path), "%s/Library/Caches/topshelf-diagnostics.txt", home);

    FILE *file = fopen(path, "a");
    if (file == NULL) {
        return;
    }

    fprintf(file, "%ld %s\n", (long)time(NULL), message);
    fclose(file);
}

/// Writes the stack of whatever called `exit`, to show why the extension quits
static void topShelfExitMarker(void) {
    topShelfWriteMarker("process exiting normally, called from:");

    void *frames[64];
    int count = backtrace(frames, 64);
    backtrace_symbols_fd(frames, count, fileno(stderr));
    fflush(stderr);
}

__attribute__((constructor))
static void topShelfLoadMarker(void) {
    topShelfWriteMarker("binary loaded");

    // Messages the system frameworks print go to the same file
    const char *home = getenv("HOME");
    if (home != NULL) {
        char path[1024];
        snprintf(path, sizeof(path), "%s/Library/Caches/topshelf-diagnostics.txt", home);
        freopen(path, "a", stderr);
    }

    atexit(topShelfExitMarker);
}

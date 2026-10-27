// ATLineEnd: lets BTServer's hands-free AT parser end a command at the end of its RFCOMM frame.
//
// AirPods (Pro 2, firmware 9A348) send every hands-free command with a closing CR except
// AT+IPHONEACCEV, their battery report, which arrives as one frame with no terminator (packet
// captures, 2026-10-27). iOS 6.1.6's parser (BTServer 0xef584, MobileBluetooth-85.10.1) holds a
// command until it sees CR, so it never answers OK. AirPods drop the hands-free channel after 10 s
// without a reply, the iPod reconnects it 10 s later, and after about three rounds they drop the
// iPod altogether, music included; a nearby Mac or iPhone set to connect automatically takes them
// in that gap.
//
// The parser takes (state, bytes, length) once per received frame; state+0xc is 3 while a command
// is half read. A command still open when its frame ends is finished with a CR, which is how the
// AirPods mean it. Every other command they send already ends its frame with CR.

#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <stdint.h>
#include <syslog.h>

enum {
    kParse = 0xef584,
    kStateOffset = 0xc,
    kInCommand = 3,
};

static int (*orig_parse)(uint8_t *, const uint8_t *, uint32_t);

static int line_end_parse(uint8_t *state, const uint8_t *bytes, uint32_t length) {
    int result = orig_parse(state, bytes, length);
    if (result == 0 && state[kStateOffset] == kInCommand) {
        static const uint8_t cr = '\r';
        result = orig_parse(state, &cr, 1);
        syslog(LOG_NOTICE, "ATLineEnd: ended a command that arrived without CR");
    }
    return result;
}

__attribute__((constructor)) static void ATLineEndInit(void) {
    static const uint8_t prologue[] = {
        0xf0, 0xb5, 0x03, 0xaf, 0x2d, 0xe9, 0x00, 0x0d, 0x81, 0xb0, 0x04, 0x46,
        0x00, 0x20, 0xad, 0xf8, 0x00, 0x00, 0x0e, 0x46, 0x21, 0x7b, 0x92, 0x46, 0x05, 0x29,
    };
    intptr_t slide = _dyld_get_image_vmaddr_slide(0);
    const uint8_t *parse = (const uint8_t *)(kParse + slide);
    for (unsigned i = 0; i < sizeof prologue; i++) {
        if (parse[i] == prologue[i]) continue;
        syslog(LOG_NOTICE, "ATLineEnd: unknown BTServer build, not loaded");
        return;
    }
    // Substrate loads this dylib before CydiaSubstrate itself, so MSHookFunction is not yet in RTLD_DEFAULT
    void *substrate = dlopen("/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate", RTLD_LAZY);
    void (*hook)(void *, void *, void **) = (void (*)(void *, void *, void **))dlsym(substrate, "MSHookFunction");
    if (!hook) return;
    hook((void *)((uintptr_t)parse | 1), (void *)line_end_parse, (void **)&orig_parse);
    syslog(LOG_NOTICE, "ATLineEnd: loaded");
}

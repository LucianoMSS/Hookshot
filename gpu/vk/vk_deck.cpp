// Steam Deck (RADV VANGOGH) defaults for the outdoor / post-door hang and earlyoom OOM (#1000, #1318).
#include "vk_deck.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "vk_internal.h"
#include "vk_loader.h"

namespace mkwvk {
namespace {

void deck_env(const char* name, const char* value) {
    if (getenv(name)) return;
#ifdef _WIN32
    char line[256];
    std::snprintf(line, sizeof line, "%s=%s", name, value);
    _putenv(line);
#else
    setenv(name, value, 0);
#endif
}

} // namespace

void deck_apply_vangogh_defaults() {
    if (!dev.is_vangogh()) return;
    if (getenv("RX_VK_DECK_DEFAULTS") && getenv("RX_VK_DECK_DEFAULTS")[0] == '0') {
        logf("vk: Steam Deck (VANGOGH): RX_VK_DECK_DEFAULTS=0, fork defaults left off");
        return;
    }

    // Hang: native task/mesh resets the GPU outdoors; compute fallback avoids it (may need post-2.0.11 SPIR-V fixes to draw).
    // RX_VK_DECK_NATIVE_MESH=1 keeps the native path for A/B.
    if (!(getenv("RX_VK_DECK_NATIVE_MESH") && atoi(getenv("RX_VK_DECK_NATIVE_MESH")) != 0))
        deck_env("RX_VK_FORCE_MESH_FALLBACK", "1");

    // Cull task hang without dropping models (#817). Prefer this over RX_VK_SKIP_CODE (hides geometry).
    deck_env("RX_VK_MESH_NOCULL", "2c56dc1006942f74");

    // Memory: fallback run was SIGTERM'd by earlyoom (swap empty, ~4 GB RSS). Keep headroom for the ~10 GB guest.
    deck_env("RX_VK_LOW_SPEC", "1");
    deck_env("HOS_HANDHELD", "1");
    deck_env("RX_VK_VRAM_MB", "1800");
    deck_env("RX_VK_TEX_MAX_MB", "512");
    deck_env("RX_VK_TEX_MAX_DIM", "1024");
    deck_env("RX_VK_TEX_SKIP_MB", "32");
    deck_env("RX_VK_ASTC_BC_ALL", "1");
    deck_env("RX_VK_KEEP_RETIRED", "1");
    deck_env("RX_VK_WB_SHADOW_MB", "256");

    // Markers for the next device-lost (if any); cheap on RADV with AMD buffer markers when NV is missing.
    deck_env("RX_VK_CHECKPOINTS", "1");

    logf("vk: Steam Deck (VANGOGH): fork defaults on (mesh fallback, MESH_NOCULL, handheld, tight tex/VRAM; "
         "RX_VK_DECK_DEFAULTS=0 or per-switch overrides; #817 #1000 #1318)");
}

void deck_disable_fault_vendor_binary(VkPhysicalDeviceFaultFeaturesEXT* fault) {
    // RADV_DEBUG=hang keeps the vendor binary in memory unless this is cleared; dumps then never reach disk (#1000).
    if (!fault) return;
    fault->deviceFaultVendorBinary = VK_FALSE;
}

} // namespace mkwvk

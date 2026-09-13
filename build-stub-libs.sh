#!/bin/bash
set -e
# Get all undefined symbols from the failed link
UNDEFS=$(echo '/usr/bin/ld: src/Hyprland.p/events_Misc.cpp.o: in function `Events::listener_leaseRequest(wl_listener*, void*)':
Misc.cpp:(.text+0x211c): undefined reference to `wlr_drm_lease_request_v1_grant'
Misc.cpp:(.text+0x214b): undefined reference to `wlr_drm_lease_request_v1_reject'
/usr/bin/ld: src/Hyprland.p/render_Renderer.cpp.o: in function `CHyprRenderer::applyMonitorRule(CMonitor*, SMonitorRule*, bool)':
Renderer.cpp:(.text+0x11509): undefined reference to `wlr_output_is_drm'
Renderer.cpp:(.text+0x11aed): undefined reference to `wlr_drm_connector_add_mode'
/usr/bin/ld: src/Hyprland.p/helpers_Monitor.cpp.o: in function `CMonitor::onConnect(bool)':
Monitor.cpp:(.text+0x68c4): undefined reference to `wlr_backend_is_drm'
Monitor.cpp:(.text+0x7187): undefined reference to `wlr_drm_lease_v1_manager_offer_output'
/usr/bin/ld: src/Hyprland.p/Compositor.cpp.o: in function `CCompositor::initServer()':
Compositor.cpp:(.text+0x13ecb): undefined reference to `wlr_drm_lease_v1_manager_create' | grep "undefined reference" | sed "s/.*undefined reference to \`//" | sed "s/'.*//" | sort -u)

echo "Undefined symbols:"
echo "$UNDEFS"

# Create stub source
cat > /tmp/drm_stubs.c << 'STUBEOF'
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

struct wlr_drm_lease_request_v1 { int dummy; };
struct wlr_drm_lease_v1 { int dummy; };
struct wlr_drm_lease_v1_manager { int dummy; };
struct wlr_backend { int dummy; };
struct wlr_output { int dummy; };
struct wlr_surface { int dummy; };
struct wl_listener { int dummy; };
struct wl_signal { int dummy; };

// DRM lease stubs
struct wlr_drm_lease_v1 *wlr_drm_lease_request_v1_grant(struct wlr_drm_lease_request_v1 *req) { return NULL; }
void wlr_drm_lease_request_v1_reject(struct wlr_drm_lease_request_v1 *req) {}
bool wlr_output_is_drm(struct wlr_output *output) { return false; }
int wlr_drm_connector_add_mode(void *conn, void *mode) { return 0; }
bool wlr_backend_is_drm(struct wlr_backend *backend) { return false; }
void wlr_drm_lease_v1_manager_offer_output(struct wlr_drm_lease_v1_manager *mgr, struct wlr_output *output) {}
struct wlr_drm_lease_v1_manager *wlr_drm_lease_v1_manager_create(void *display, struct wlr_backend *backend) { return NULL; }

// drmMode stubs for older libdrm
int drmModeCreateDumbBuffer(int fd, uint32_t w, uint32_t h, uint32_t bpp, uint32_t flags, uint32_t *handle, uint32_t *pitch, uint32_t *size) { return -1; }
int drmModeDestroyDumbBuffer(int fd, uint32_t handle) { return -1; }
int drmModeMapDumbBuffer(int fd, uint32_t handle, uint64_t *offset) { return -1; }
STUBEOF

echo "177695" | sudo -S gcc -shared -fPIC -o /usr/lib/x86_64-linux-gnu/libdrm_stubs.so /tmp/drm_stubs.c -Wl,-soname,libdrm_stubs.so
echo "177695" | sudo -S ldconfig
echo "=== Created libdrm_stubs.so ==="

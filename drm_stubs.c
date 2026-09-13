#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

struct wlr_drm_lease_request_v1 { int dummy; };
struct wlr_drm_lease_v1 { int dummy; };
struct wlr_drm_lease_v1_manager { int dummy; };
struct wlr_backend { int dummy; };
struct wlr_output { int dummy; };

struct wlr_drm_lease_v1 *wlr_drm_lease_request_v1_grant(struct wlr_drm_lease_request_v1 *req) { return NULL; }
void wlr_drm_lease_request_v1_reject(struct wlr_drm_lease_request_v1 *req) {}
bool wlr_output_is_drm(struct wlr_output *output) { return false; }
int wlr_drm_connector_add_mode(void *conn, void *mode) { return 0; }
bool wlr_backend_is_drm(struct wlr_backend *backend) { return false; }
void wlr_drm_lease_v1_manager_offer_output(struct wlr_drm_lease_v1_manager *mgr, struct wlr_output *output) {}
struct wlr_drm_lease_v1_manager *wlr_drm_lease_v1_manager_create(void *display, struct wlr_backend *backend) { return NULL; }
int drmModeCreateDumbBuffer(int fd, uint32_t w, uint32_t h, uint32_t bpp, uint32_t flags, uint32_t *handle, uint32_t *pitch, uint32_t *size) { return -1; }
int drmModeDestroyDumbBuffer(int fd, uint32_t handle) { return -1; }
int drmModeMapDumbBuffer(int fd, uint32_t handle, uint64_t *offset) { return -1; }

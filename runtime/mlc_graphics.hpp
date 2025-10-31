#ifndef AURORA_GRAPHICS_HPP
#define AURORA_GRAPHICS_HPP

#include <cstdint>
#include <memory>
#include <thread>
#include <chrono>
#include <xcb/xcb.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xcb.h>
#include "mlc_string.hpp"

namespace mlc::graphics {

// Forward declarations
struct Window;
struct DrawContext;

// Color structure (RGBA)
struct Color {
    double r, g, b, a;

    Color(double red, double green, double blue, double alpha = 1.0)
        : r(red), g(green), b(blue), a(alpha) {}
};

// Window handle - wraps XCB connection and window
struct Window {
    xcb_connection_t* connection;
    xcb_window_t window;
    xcb_screen_t* screen;
    int32_t width;
    int32_t height;

    Window(int32_t w, int32_t h, const mlc::String& title)
        : width(w), height(h) {

        // Connect to X server
        connection = xcb_connect(nullptr, nullptr);
        if (xcb_connection_has_error(connection)) {
            throw std::runtime_error("Failed to connect to X server");
        }

        // Get first screen
        screen = xcb_setup_roots_iterator(xcb_get_setup(connection)).data;

        // Create window
        window = xcb_generate_id(connection);
        uint32_t values[] = {
            screen->white_pixel,
            XCB_EVENT_MASK_EXPOSURE | XCB_EVENT_MASK_KEY_PRESS |
            XCB_EVENT_MASK_BUTTON_PRESS | XCB_EVENT_MASK_BUTTON_RELEASE |
            XCB_EVENT_MASK_POINTER_MOTION
        };

        xcb_create_window(
            connection,
            XCB_COPY_FROM_PARENT,
            window,
            screen->root,
            0, 0,
            static_cast<uint16_t>(width), static_cast<uint16_t>(height),
            0,
            XCB_WINDOW_CLASS_INPUT_OUTPUT,
            screen->root_visual,
            XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK,
            values
        );

        // Set window title
        xcb_change_property(
            connection,
            XCB_PROP_MODE_REPLACE,
            window,
            XCB_ATOM_WM_NAME,
            XCB_ATOM_STRING,
            8,
            title.length(),
            title.c_str()
        );

        // Map window (make it visible)
        xcb_map_window(connection, window);
        xcb_flush(connection);
    }

    ~Window() {
        if (connection) {
            xcb_disconnect(connection);
        }
    }

    // No copying
    Window(const Window&) = delete;
    Window& operator=(const Window&) = delete;
};

// Drawing context - wraps Cairo
struct DrawContext {
    cairo_surface_t* surface;
    cairo_t* cr;
    xcb_visualtype_t* visual;

    DrawContext(Window* win) {
        // Find the visual
        visual = nullptr;
        xcb_depth_iterator_t depth_iter =
            xcb_screen_allowed_depths_iterator(win->screen);

        for (; depth_iter.rem; xcb_depth_next(&depth_iter)) {
            if (depth_iter.data->depth == win->screen->root_depth) {
                xcb_visualtype_iterator_t visual_iter =
                    xcb_depth_visuals_iterator(depth_iter.data);
                visual = visual_iter.data;
                break;
            }
        }

        // Create XCB surface
        surface = cairo_xcb_surface_create(
            win->connection,
            win->window,
            visual,
            win->width,
            win->height
        );

        // Create Cairo context
        cr = cairo_create(surface);
    }

    ~DrawContext() {
        if (cr) cairo_destroy(cr);
        if (surface) cairo_surface_destroy(surface);
    }

    // No copying
    DrawContext(const DrawContext&) = delete;
    DrawContext& operator=(const DrawContext&) = delete;

    void flush() {
        cairo_surface_flush(surface);
    }
};

// Event types
enum class EventType {
    None = 0,
    Expose = XCB_EXPOSE,
    KeyPress = XCB_KEY_PRESS,
    ButtonPress = XCB_BUTTON_PRESS,
    ButtonRelease = XCB_BUTTON_RELEASE,
    MotionNotify = XCB_MOTION_NOTIFY,
    Quit = 999
};

struct Event {
    EventType type;
    int32_t x, y;  // For mouse events
    uint32_t button;  // For button events
    uint32_t keycode;  // For key events
};

// ============================================================================
// Aurora API Functions
// ============================================================================

// Create a window
inline Window* create_window(int32_t width, int32_t height, const mlc::String& title) {
    return new Window(width, height, title);
}

// Create drawing context for window
inline DrawContext* create_draw_context(Window* win) {
    return new DrawContext(win);
}

// Poll for events (non-blocking)
inline Event poll_event(Window* win) {
    Event evt{EventType::None, 0, 0, 0, 0};

    xcb_generic_event_t* event = xcb_poll_for_event(win->connection);
    if (!event) {
        return evt;
    }

    uint8_t type = event->response_type & ~0x80;
    evt.type = static_cast<EventType>(type);

    switch (type) {
        case XCB_BUTTON_PRESS:
        case XCB_BUTTON_RELEASE: {
            xcb_button_press_event_t* bp = (xcb_button_press_event_t*)event;
            evt.x = bp->event_x;
            evt.y = bp->event_y;
            evt.button = bp->detail;
            break;
        }
        case XCB_MOTION_NOTIFY: {
            xcb_motion_notify_event_t* mn = (xcb_motion_notify_event_t*)event;
            evt.x = mn->event_x;
            evt.y = mn->event_y;
            break;
        }
        case XCB_KEY_PRESS: {
            xcb_key_press_event_t* kp = (xcb_key_press_event_t*)event;
            evt.keycode = kp->detail;
            break;
        }
    }

    free(event);
    return evt;
}

// Flush window (make drawing visible)
inline void flush_window(Window* win) {
    xcb_flush(win->connection);
}

// ============================================================================
// Cairo Drawing Functions
// ============================================================================

// Clear screen with color
inline void clear(DrawContext* ctx, const Color& color) {
    cairo_set_source_rgba(ctx->cr, color.r, color.g, color.b, color.a);
    cairo_paint(ctx->cr);
}

// Set drawing color
inline void set_color(DrawContext* ctx, const Color& color) {
    cairo_set_source_rgba(ctx->cr, color.r, color.g, color.b, color.a);
}

// Draw rectangle
inline void draw_rect(DrawContext* ctx, double x, double y, double w, double h) {
    cairo_rectangle(ctx->cr, x, y, w, h);
    cairo_fill(ctx->cr);
}

// Draw rectangle outline
inline void stroke_rect(DrawContext* ctx, double x, double y, double w, double h, double line_width) {
    cairo_set_line_width(ctx->cr, line_width);
    cairo_rectangle(ctx->cr, x, y, w, h);
    cairo_stroke(ctx->cr);
}

// Draw circle
inline void draw_circle(DrawContext* ctx, double x, double y, double radius) {
    cairo_arc(ctx->cr, x, y, radius, 0, 2 * 3.14159265359);
    cairo_fill(ctx->cr);
}

// Draw circle outline
inline void stroke_circle(DrawContext* ctx, double x, double y, double radius, double line_width) {
    cairo_set_line_width(ctx->cr, line_width);
    cairo_arc(ctx->cr, x, y, radius, 0, 2 * 3.14159265359);
    cairo_stroke(ctx->cr);
}

// Draw line
inline void draw_line(DrawContext* ctx, double x1, double y1, double x2, double y2, double line_width) {
    cairo_set_line_width(ctx->cr, line_width);
    cairo_move_to(ctx->cr, x1, y1);
    cairo_line_to(ctx->cr, x2, y2);
    cairo_stroke(ctx->cr);
}

// Draw text
inline void draw_text(DrawContext* ctx, const mlc::String& text, double x, double y, double font_size) {
    cairo_select_font_face(ctx->cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(ctx->cr, font_size);
    cairo_move_to(ctx->cr, x, y);
    cairo_show_text(ctx->cr, text.c_str());
}

// Helper to create color
inline Color rgb(double r, double g, double b) {
    return Color(r, g, b, 1.0);
}

inline Color rgba(double r, double g, double b, double a) {
    return Color(r, g, b, a);
}

// ============================================================================
// Timing and Event Loop Utilities
// ============================================================================

// Sleep for given milliseconds
inline void sleep_ms(int32_t milliseconds) {
    std::this_thread::sleep_for(std::chrono::milliseconds(milliseconds));
}

// Check if event is a quit event (key press or explicit quit)
inline bool is_quit_event(const Event& evt) {
    return evt.type == EventType::KeyPress ||
           evt.type == EventType::Quit;
}

} // namespace mlc::graphics

#endif // AURORA_GRAPHICS_HPP

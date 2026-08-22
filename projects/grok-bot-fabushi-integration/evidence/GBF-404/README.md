# GBF-404 Evidence — Linux adapter

Added Rust portable adapter for X11/Wayland-capable input/capture with explicit display availability reporting. Clean-room Linux layer retains X11 coordinate control plus AT-SPI semantic application control; CI provisions X11/AT-SPI and separately installs Wayland/native capture dependencies. No unsupported platform silently reports ready when neither DISPLAY nor WAYLAND_DISPLAY is present.

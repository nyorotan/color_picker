🌐 **English** | [日本語](./README.ja.md)

# Color Picker for HSP3

![Image](./000.jpg)

This project is a high‑functionality color picker application developed with HSP3, as well as a module that can be integrated into other applications.

---

## User Guide (How to Use)

The tool is an application that lets you pick colors from the screen, create and save custom colors using a palette, and view the selected color in both RGB and HSV formats in real‑time. Pressing the **OK** button copies the ARGB value to the clipboard.

### 1. Selecting a Color

- **Color wheel:** Drag the outer circle to choose the hue (color type).
- **Center square:** Drag inside the square to adjust saturation (vividness) and value (brightness).
- **Slider:** Use the slider at the bottom of the window to adjust the alpha (transparency) of the color.

### 2. Picking a Color (Eyedropper)

While the eyedropper is active, normal click actions are temporarily disabled.

![Image](./001.jpg)

1. Click the **Pick** button.
2. The mouse cursor changes to a crosshair.
3. Click any point on the screen to sample its color.
4. Press **Esc** to cancel.

### 3. Palette Feature

- **Save a color:** Right‑click a palette slot to store the currently created color.
- **Load a color:** Left‑click a palette slot to retrieve a saved color.

### 4. Using the Color

- **Copy the color:** Press the **OK** button to copy the color code (RGB/HEX) to the clipboard. A small window also shows detailed information that you can copy as needed.

---

## Developer Guide (Integrating the Module)

This section explains how to embed the module into your own HSP3 project and use it as a custom color picker.

### Integration Steps

1. Place `color_picker.as` in your project folder.
2. Include it in your main script:
   ```hsp
   #include "color_picker.as"
   ```

### Calling the Module

Invoke the following function to launch the color picker in a separate window:
```hsp
// result_color: variable to receive the result, dark_mode (0/1), title bar color, font name, use_alpha (0/1)
open_custom_color_picker result_color, 1, 0x1E1E1E, "Meiryo", 1
```

#### Parameter Details

- `result_color`: Variable that receives the selected color as a 0xAARRGGBB value.
- `is_dark`: `1` for dark mode, `0` for light mode.
- `bar_color`: Title‑bar color (Windows 11) expressed as a color code.
- `f_name`: Font name used in the UI.
- `use_alpha`: `1` to enable transparency, `0` to disable.

Setting the `SET_OLD` flag inside `color_picker.as` to `1` will also display the previous color (`old`) alongside the new one (`new`) in the popup window.

### Features

- **High‑DPI support:** Uses `SetThreadDpiAwarenessContext` for proper rendering on high‑resolution displays.
- **Windows dark‑mode support:** Adapts the window frame to match the OS theme.
- **JSON palette management:** Saves palette data to `utils\color_palette.json` so settings persist.

### Notes

- You need to include `user32.as` and `kernel32.as`.
- If the `utils` folder does not exist, it will be created automatically.

---

## License

This project is released under the **NYSL (Niru nari Yaku nari Suki ni Shiro License)**.

```
Do whatever you like with it—boil it, grill it, or whatever.
```

- **Copyright**: © 2026 nyorotan

## Version Information

- **Version**: v1.2.0
- **Author**: nyorotan

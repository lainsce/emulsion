/*
* Copyright (C) 2021 Lains
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/
namespace Emulsion {
    [GtkTemplate (ui = "/io/github/lainsce/Emulsion/cep.ui")]
    public class ColorEditPopover : He.Window {
        [GtkChild]
        public unowned He.Slider red_scale;
        [GtkChild]
        public unowned He.Slider green_scale;
        [GtkChild]
        public unowned He.Slider blue_scale;
        [GtkChild]
        public unowned He.TextField red_entry;
        [GtkChild]
        public unowned He.TextField green_entry;
        [GtkChild]
        public unowned He.TextField blue_entry;
        [GtkChild]
        public unowned He.TextField hex_entry;
        [GtkChild]
        public unowned He.TextField name_entry;
        [GtkChild]
        public unowned He.Button close_button;
        [GtkChild]
        public unowned Gtk.Box color_preview;
        [GtkChild]
        public unowned Gtk.Label hex_preview_label;

        public MainWindow win { get; construct; }
        public Gdk.RGBA color = {};
        public uint edit_position = Gtk.INVALID_LIST_POSITION;

        public ColorInfo _color_info;
        private string _original_name = "";
        private string _original_color = "";
        private string _original_uid = "";
        private Gtk.CssProvider? preview_css_provider = null;
        public ColorInfo color_info {
            get {
                return _color_info;
            }

            set {
                if(_color_info == value) {
                    return;
                }

                 _color_info = value;
                 _original_name = _color_info.name; // Store original name for updates
                 _original_color = _color_info.color; // Store original color for updates
                 _original_uid = _color_info.uid; // Store original uid for updates
                 color.parse(_color_info.color);

                var red_entry_internal = red_entry.get_internal_entry ();
                if (red_entry_internal != null) {
                    red_entry_internal.text = "%00.0f".printf(Utils.make_srgb(color.red));
                }
                var green_entry_internal = green_entry.get_internal_entry ();
                if (green_entry_internal != null) {
                    green_entry_internal.text = "%00.0f".printf(Utils.make_srgb(color.green));
                }
                var blue_entry_internal = blue_entry.get_internal_entry ();
                if (blue_entry_internal != null) {
                    blue_entry_internal.text = "%00.0f".printf(Utils.make_srgb(color.blue));
                }

                red_scale.scale.set_value (Utils.make_srgb(color.red));
                green_scale.scale.set_value (Utils.make_srgb(color.green));
                blue_scale.scale.set_value (Utils.make_srgb(color.blue));

                var hex_entry_internal = hex_entry.get_internal_entry ();
                if (hex_entry_internal != null) {
                    hex_entry_internal.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                }
                var name_entry_internal = name_entry.get_internal_entry ();
                if (name_entry_internal != null) {
                    name_entry_internal.text = _color_info.name;
                }
                update_preview ();
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            }
        }
        
        private void update_preview () {
            // Update preview box color via CSS
            var style_context = color_preview.get_style_context ();
            
            // Remove old provider if it exists
            if (preview_css_provider != null) {
                style_context.remove_provider (preview_css_provider);
            }
            
            // Create new provider with updated color
            preview_css_provider = new Gtk.CssProvider ();
            var css = "* { background: %s; border-radius: 25px; }".printf (_color_info.color);
            preview_css_provider.load_from_data (css.data);
            style_context.add_provider (preview_css_provider, 9999);
            
            // Update hex preview label
            hex_preview_label.label = _color_info.color;
            
            color_preview.queue_draw ();
        }

        public ColorEditPopover (MainWindow win) {
            Object( win: win );
            
            // Set up window properties
            this.modal = true;
            this.set_transient_for (win);
            this.title = _("Edit Color");
            
            // Set up adjustments for sliders
            var red_adj = new Gtk.Adjustment (0, 0, 255, 1, 1, 0);
            var green_adj = new Gtk.Adjustment (0, 0, 255, 1, 1, 0);
            var blue_adj = new Gtk.Adjustment (0, 0, 255, 1, 1, 0);
            red_scale.set_adjustment (red_adj);
            green_scale.set_adjustment (green_adj);
            blue_scale.set_adjustment (blue_adj);
            
            win.palette_fb.queue_draw ();
            win.color_fb.queue_draw ();
            queue_draw ();
            
            // Handle window close
            this.close_request.connect (() => {
                handle_close ();
                return false; // Don't prevent default close behavior
            });

            red_scale.scale.value_changed.connect (() => {
                var red_entry_internal = red_entry.get_internal_entry ();
                if (red_entry_internal != null) {
                    red_entry_internal.text = "%00.0f".printf(red_scale.scale.get_value ());
                    color.red = (float)(double.parse(red_entry_internal.text ?? "0") / 255);
                }
                var hex_entry_internal = hex_entry.get_internal_entry ();
                if (hex_entry_internal != null) {
                    hex_entry_internal.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                    _color_info.color = hex_entry_internal.text ?? "";
                    update_palette_color ();
                    update_preview ();
                }

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            green_scale.scale.value_changed.connect (() => {
                var green_entry_internal = green_entry.get_internal_entry ();
                if (green_entry_internal != null) {
                    green_entry_internal.text = "%00.0f".printf(green_scale.scale.get_value ());
                    color.green = (float)(double.parse(green_entry_internal.text ?? "0") / 255);
                }
                var hex_entry_internal = hex_entry.get_internal_entry ();
                if (hex_entry_internal != null) {
                    hex_entry_internal.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                    _color_info.color = hex_entry_internal.text ?? "";
                    update_palette_color ();
                    update_preview ();
                }

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            blue_scale.scale.value_changed.connect (() => {
                var blue_entry_internal = blue_entry.get_internal_entry ();
                if (blue_entry_internal != null) {
                    blue_entry_internal.text = "%00.0f".printf(blue_scale.scale.get_value ());
                    color.blue = (float)(double.parse(blue_entry_internal.text ?? "0") / 255);
                }
                var hex_entry_internal = hex_entry.get_internal_entry ();
                if (hex_entry_internal != null) {
                    hex_entry_internal.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                    _color_info.color = hex_entry_internal.text ?? "";
                    update_palette_color ();
                    update_preview ();
                }

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            red_entry.entry.activate.connect (() => {
                var red_entry_internal = red_entry.get_internal_entry ();
                string? red_text = red_entry_internal != null ? red_entry_internal.text : null;
                color.red = (float)(double.parse(red_text ?? "0") / 255);
                red_scale.scale.set_value (double.parse(red_text ?? "0"));
                var hex_entry_internal = hex_entry.get_internal_entry ();
                if (hex_entry_internal != null) {
                    hex_entry_internal.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                    _color_info.color = hex_entry_internal.text ?? "";
                    update_palette_color ();
                    update_preview ();
                }

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            green_entry.entry.activate.connect (() => {
                var green_entry_internal = green_entry.get_internal_entry ();
                string? green_text = green_entry_internal != null ? green_entry_internal.text : null;
                color.green = (float)(double.parse(green_text ?? "0") / 255);
                green_scale.scale.set_value (double.parse(green_text ?? "0"));
                var hex_entry_internal = hex_entry.get_internal_entry ();
                if (hex_entry_internal != null) {
                    hex_entry_internal.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                    _color_info.color = hex_entry_internal.text ?? "";
                    update_palette_color ();
                    update_preview ();
                }

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            blue_entry.entry.activate.connect (() => {
                var blue_entry_internal = blue_entry.get_internal_entry ();
                string? blue_text = blue_entry_internal != null ? blue_entry_internal.text : null;
                color.blue = (float)(double.parse(blue_text ?? "0") / 255);
                blue_scale.scale.set_value (double.parse(blue_text ?? "0"));
                var hex_entry_internal = hex_entry.get_internal_entry ();
                if (hex_entry_internal != null) {
                    hex_entry_internal.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                    _color_info.color = hex_entry_internal.text ?? "";
                    update_palette_color ();
                    update_preview ();
                }

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            hex_entry.entry.activate.connect (() => {
                var hex_entry_internal = hex_entry.get_internal_entry ();
                string? hex_text = hex_entry_internal != null ? hex_entry_internal.text : null;
                if (hex_text == null || hex_text.length == 0) {
                    return;
                }
                
                // Remove # if present
                if (hex_text.has_prefix ("#")) {
                    hex_text = hex_text.substring (1);
                }
                
                // Parse hex string
                if (hex_text.length == 6) {
                    uint64 red_val = 0;
                    uint64 green_val = 0;
                    uint64 blue_val = 0;
                    
                    // Parse hex values
                    if (hex_text.substring (0, 2).scanf ("%02llx", &red_val) == 1 &&
                        hex_text.substring (2, 2).scanf ("%02llx", &green_val) == 1 &&
                        hex_text.substring (4, 2).scanf ("%02llx", &blue_val) == 1) {
                        
                        // Update RGB values
                        red_scale.scale.set_value ((double)red_val);
                        green_scale.scale.set_value ((double)green_val);
                        blue_scale.scale.set_value ((double)blue_val);
                        
                        // Update color object
                        color.red = (float)red_val / 255.0f;
                        color.green = (float)green_val / 255.0f;
                        color.blue = (float)blue_val / 255.0f;
                        
                        // Update entries
                        var red_entry_internal = red_entry.get_internal_entry ();
                        if (red_entry_internal != null) {
                            red_entry_internal.text = "%d".printf ((int)red_val);
                        }
                        var green_entry_internal = green_entry.get_internal_entry ();
                        if (green_entry_internal != null) {
                            green_entry_internal.text = "%d".printf ((int)green_val);
                        }
                        var blue_entry_internal = blue_entry.get_internal_entry ();
                        if (blue_entry_internal != null) {
                            blue_entry_internal.text = "%d".printf ((int)blue_val);
                        }
                        
                        // Update color info
                        _color_info.color = "#" + hex_text;
                        update_palette_color ();
                        update_preview ();
                        
                        win.m.save_palettes.begin (win.palettestore);
                        win.palette_fb.queue_draw ();
                        win.color_fb.queue_draw ();
                        queue_draw ();
                    }
                }
            });

            name_entry.entry.activate.connect (() => {
                var entry = name_entry.get_internal_entry ();
                string? new_name = entry != null ? entry.text : null;
                if (new_name != null) {
                    string sanitized_name = new_name.strip ();
                    if (sanitized_name != "" && sanitized_name != _color_info.name) {
                        // Update the palette's colors map if name changed
                        if (_original_name != _color_info.name) {
                            // Name was already changed, update with previous name as original
                            _original_name = _color_info.name;
                        }
                        
                        // Find and update the palette
                        uint i, m = win.palettestore.get_n_items ();
                        for (i = 0; i < m; i++) {
                            var pitem = win.palettestore.get_item (i);
                            if (pitem == null) continue;
                            
                            if (_color_info.uid == ((PaletteInfo)pitem).palname) {
                                // Remove old entry if name changed
                                if (_original_name != sanitized_name && ((PaletteInfo)pitem).colors.has_key (_original_name)) {
                                    ((PaletteInfo)pitem).colors.unset (_original_name);
                                }
                                // Set new entry
                                ((PaletteInfo)pitem).colors.set (sanitized_name, _color_info.color);
                                break;
                            }
                        }
                        
                        _color_info.name = sanitized_name;
                        _original_name = sanitized_name;
                        
                        win.m.save_palettes.begin (win.palettestore);
                        win.palette_fb.queue_draw ();
                        win.color_fb.queue_draw ();
                        queue_draw ();
                    }
                }
            });

            close_button.clicked.connect (() => {
                close ();
            });
        }
        
        private void update_palette_color () {
            // Update the palette's colors map with the current color value
            uint i, palette_count = win.palettestore.get_n_items ();
            for (i = 0; i < palette_count; i++) {
                var pitem = win.palettestore.get_item (i);
                if (pitem == null) continue;
                
                if (_color_info.uid == ((PaletteInfo)pitem).palname) {
                    // Update the color value in the palette's colors map
                    ((PaletteInfo)pitem).colors.set (_color_info.name, _color_info.color);
                    break;
                }
            }
            
            // Trigger colorstore refresh by removing and reinserting the item
            // This causes the GridView to redraw with the updated color
            // Skip remove/insert for position 0 to avoid navigation issues
            if (edit_position == Gtk.INVALID_LIST_POSITION) {
                return; // Can't update if we don't know the position
            }
            
            uint pos = edit_position;
            
            // For position 0, emit a property notification to trigger renderer update
            // This avoids remove/insert which can trigger navigation checks
            if (pos == 0) {
                // Notify that the color property changed so renderers can update
                _color_info.notify_property ("color");
                win.color_fb.queue_draw ();
                return;
            }
            
            // For other positions, use remove/insert to trigger refresh
            // Store state before operation
            string? current_view = win.main_stack.get_visible_child_name ();
            uint current_selected = win.color_model.selected;
            uint store_size = win.colorstore.get_n_items ();
            
            // Verify position is still valid
            if (pos >= store_size) {
                return;
            }
            
            // Use a very short timeout to ensure this happens after any synchronous checks
            Timeout.add (10, () => {
                // Verify we're still in the same view before proceeding
                if (current_view != null && win.main_stack.get_visible_child_name () != current_view) {
                    win.main_stack.set_visible_child_name (current_view);
                }
                
                // Verify position is still valid (store might have changed)
                if (pos >= win.colorstore.get_n_items ()) {
                    return false;
                }
                
                // Get a fresh reference to the color info (in case store changed)
                var color_item = win.colorstore.get_item (pos);
                if (color_item != _color_info) {
                    // Store was rebuilt, can't safely update
                    return false;
                }
                
                // Preserve view
                if (current_view != null) {
                    win.main_stack.set_visible_child_name (current_view);
                }
                
                win.colorstore.remove (pos);
                
                // Immediately restore view after remove
                if (current_view != null) {
                    win.main_stack.set_visible_child_name (current_view);
                }
                
                win.colorstore.insert (pos, _color_info);
                
                // Restore selection (adjust for any shifts)
                if (current_selected != Gtk.INVALID_LIST_POSITION) {
                    if (current_selected > pos) {
                        // Selection was after removed item, adjust
                        win.color_model.selected = current_selected;
                    } else if (current_selected == pos) {
                        // Selection was the item we removed, restore it
                        win.color_model.selected = pos;
                    } else {
                        // Selection was before removed item, unchanged
                        win.color_model.selected = current_selected;
                    }
                }
                
                // Final view check
                if (current_view != null && win.main_stack.get_visible_child_name () != current_view) {
                    win.main_stack.set_visible_child_name (current_view);
                }
                
                return false; // Don't repeat
            });
        }
        
        private void handle_close () {
            // Store current view to preserve it - colors are already saved in real-time
            string? current_view = win.main_stack.get_visible_child_name ();
            
            // Simply refresh the display after window closes - data is already updated
            Idle.add (() => {
                // Ensure we stay in the same view
                if (current_view != null && win.main_stack.get_visible_child_name () != current_view) {
                    win.main_stack.set_visible_child_name (current_view);
                }
                
                // Refresh displays
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                
                // Return focus to color grid view
                if (current_view == "colbody") {
                    win.color_fb.grab_focus ();
                }
                
                return false;
            });
        }
    }
}

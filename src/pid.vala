/*
 * Copyright (c) 2021-2022 Lains
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */
namespace Emulsion {
    [GtkTemplate (ui = "/io/github/lainsce/Emulsion/pid.ui")]
    public class PaletteImportDialog : He.Window {
        const string COLORED_SURFACE = "* { background: %s; }";

        [GtkChild]
        unowned Gtk.Box color_box;
        [GtkChild]
        unowned Gtk.Button ok_button;
        [GtkChild]
        unowned Gtk.Button cancel_button;
        [GtkChild]
        unowned Gtk.Button apply_button;
        [GtkChild]
        unowned Gtk.Button image;
        [GtkChild]
        unowned Gtk.Label file_label;
        [GtkChild]
        unowned Gtk.Image file_image;
        [GtkChild]
        unowned Gtk.SpinButton pick_spin;
        [GtkChild]
        unowned Gtk.DropDown prefer_dropdown;
        [GtkChild]
        unowned Gtk.DropDown order_dropdown;
        [GtkChild]
        unowned Gtk.CheckButton distinct_check;
        [GtkChild]
        unowned Gtk.CheckButton avoid_white_check;
        [GtkChild]
        unowned Gtk.CheckButton avoid_black_check;

        private MainWindow win = null;
        private File file;
        private Utils.Palette palette;
        private Gdk.Pixbuf original_pixbuf;
        private uint16 last_max_colors = 0;

        public PaletteImportDialog (MainWindow win) {
            this.win = win;
        }

        construct {
            color_box.add_css_class ("palette");
            color_box.set_overflow(Gtk.Overflow.HIDDEN);
            color_box.set_visible (false);
            color_box.set_margin_top (6);
            file_label.set_visible (true);
            file_image.set_visible (true);
            image.set_sensitive (true);
            ok_button.set_sensitive (false);
            apply_button.set_sensitive (false);

            // Set up "Prefer" dropdown
            var prefer_store = new Gtk.StringList ({ _("Any Color"), _("Pastel Colors"), _("Neon Colors") });
            prefer_dropdown.model = prefer_store;
            
            // Set up "Order by" dropdown
            var order_store = new Gtk.StringList ({ _("Frequency"), _("Saturation"), _("Luminosity"), _("Hue") });
            order_dropdown.model = order_store;

            cancel_button.clicked.connect (() => {
                this.dispose ();
            });

            apply_button.clicked.connect (() => {
                if (original_pixbuf == null) {
                    return;
                }
                
                uint16 current_max_colors = (uint16)pick_spin.get_value_as_int ();
                
                // Only regenerate palette if max_colors changed
                // Otherwise, just update the display with current filters/sorting (much faster)
                if (palette == null || current_max_colors != last_max_colors) {
                    last_max_colors = current_max_colors;
                    regenerate_palette ();
                } else {
                    // Just update display with new filters/sorting (non-blocking)
                    update_color_display ();
                }
            });

            ok_button.clicked.connect (() => {
                if (palette == null) {
                    this.dispose ();
                }

                string[] n;
                // Collect filtered colors from the palette swatches
                var filtered_swatches = get_filtered_swatches ();
                foreach (var swatch in filtered_swatches) {
                    n += Utils.make_hex(swatch.red, swatch.green, swatch.blue);
                }

                var a = new PaletteInfo ();
                a.palname = "%s".printf(file.get_basename().replace(".jpg","").replace(".png",""));
                a.colors = new Gee.HashMap<string, string> ();

                for (int i = 0; i < n.length; i++) {
                    a.colors.set (n[i], n[i]);
                }

                win.palettestore.append (a);
                win.back_button.set_visible(true);
                win.palette_stack.set_visible_child_name ("palfull");
                win.search_button.set_visible(true);
                this.dispose ();
            });
        }

        [GtkCallback]
        private void on_clicked () {
            var chooser = new Gtk.FileChooserNative ((_("Import")), win, Gtk.FileChooserAction.OPEN, null, null);

            var png_filter = new Gtk.FileFilter ();
            png_filter.set_filter_name (_("Picture"));
            png_filter.add_pattern ("*.png");
            png_filter.add_pattern ("*.jpg");

            chooser.add_filter (png_filter);

            chooser.response.connect ((response_id) => {
                switch (response_id) {
                    case Gtk.ResponseType.OK:
                    case Gtk.ResponseType.ACCEPT:
                    case Gtk.ResponseType.APPLY:
                    case Gtk.ResponseType.YES:
                        try {
                            file = null;
                            file = File.new_for_uri (chooser.get_file ().get_uri ());
                            original_pixbuf = new Gdk.Pixbuf.from_file (file.get_path ());
                            
                            // Scale pixbuf to fit in the image button while maintaining aspect ratio
                            int max_width = 500;
                            int max_height = 400;
                            double scale = double.min (
                                (double)max_width / original_pixbuf.get_width (),
                                (double)max_height / original_pixbuf.get_height ()
                            );
                            int scaled_width = (int)(original_pixbuf.get_width () * scale);
                            int scaled_height = (int)(original_pixbuf.get_height () * scale);
                            
                            var scaled_pixbuf = original_pixbuf.scale_simple (
                                scaled_width, scaled_height, Gdk.InterpType.BILINEAR);
                            var texture = Gdk.Texture.for_pixbuf (scaled_pixbuf);
                            file_image.set_from_paintable (texture);

                            image.set_sensitive (false);
                            image.remove_css_class ("dim-label");

                            last_max_colors = 8; // Default value from UI
                            regenerate_palette ();

                            color_box.set_visible (true);
                            file_label.set_visible (false);
                            ok_button.set_sensitive (true);
                        } catch {

                        }
                        break;
                    case Gtk.ResponseType.NO:
                    case Gtk.ResponseType.CANCEL:
                    case Gtk.ResponseType.CLOSE:
                    case Gtk.ResponseType.DELETE_EVENT:
                        chooser.dispose ();
                        break;
                    default:
                        break;
                }
            });

            chooser.show ();
        }

        private void regenerate_palette () {
            if (original_pixbuf == null) {
                return;
            }

            // Disable all controls during regeneration
            apply_button.set_sensitive (false);
            pick_spin.set_sensitive (false);
            prefer_dropdown.set_sensitive (false);
            order_dropdown.set_sensitive (false);
            distinct_check.set_sensitive (false);
            avoid_white_check.set_sensitive (false);
            avoid_black_check.set_sensitive (false);
            
            uint16 max_colors = (uint16)pick_spin.get_value_as_int ();
            var new_palette = new Utils.Palette.from_pixbuf (original_pixbuf, max_colors);
            new_palette.generate_async.begin ((obj, res) => {
                try {
                    new_palette.generate_async.end (res);
                    // Update on main thread - flush old palette first
                    Idle.add (() => {
                        // Flush old palette to free memory
                        if (palette != null) {
                            palette = null;
                        }
                        palette = new_palette;
                        update_color_display ();
                        // Re-enable all controls
                        apply_button.set_sensitive (true);
                        pick_spin.set_sensitive (true);
                        prefer_dropdown.set_sensitive (true);
                        order_dropdown.set_sensitive (true);
                        distinct_check.set_sensitive (true);
                        avoid_white_check.set_sensitive (true);
                        avoid_black_check.set_sensitive (true);
                        return false;
                    });
                } catch (Error e) {
                    // On error, re-enable controls
                    Idle.add (() => {
                        apply_button.set_sensitive (true);
                        pick_spin.set_sensitive (true);
                        prefer_dropdown.set_sensitive (true);
                        order_dropdown.set_sensitive (true);
                        distinct_check.set_sensitive (true);
                        avoid_white_check.set_sensitive (true);
                        avoid_black_check.set_sensitive (true);
                        return false;
                    });
                }
            });
        }

        private void update_color_display () {
            if (palette == null) {
                return;
            }

            // Clear existing colors - remove all children properly
            Gtk.Widget? child;
            while ((child = color_box.get_first_child ()) != null) {
                color_box.remove (child);
                child.destroy ();
            }
            
            // Force the container to update/refresh
            color_box.queue_draw ();
            
            // Do filtering and display directly - it should be fast enough
            // If it's not, we'll need to profile and optimize get_filtered_swatches()
            var filtered_swatches = get_filtered_swatches ();
            
            // Display all swatches at once - widget creation should be fast
            foreach (var swatch in filtered_swatches) {
                add_swatch (swatch, "Color");
            }
            
            // Ensure the container updates after adding widgets
            color_box.queue_resize ();
        }


        private Gee.List<Utils.Palette.Swatch> get_filtered_swatches () {
            if (palette == null) {
                return new Gee.ArrayList<Utils.Palette.Swatch> ();
            }

            var filtered = new Gee.ArrayList<Utils.Palette.Swatch> ();
            
            // Get prefer selection
            uint prefer_selected = prefer_dropdown.get_selected ();
            
            foreach (var swatch in palette.swatches) {
                // Check prefer filter
                if (prefer_selected == 1) {
                    // Pastel Colors: high lightness, low saturation
                    double lightness = get_lightness (swatch);
                    double saturation = get_saturation (swatch);
                    if (lightness < 0.7 || saturation > 0.4) {
                        continue;
                    }
                } else if (prefer_selected == 2) {
                    // Neon Colors: high saturation
                    double saturation = get_saturation (swatch);
                    if (saturation < 0.7) {
                        continue;
                    }
                }
                // prefer_selected == 0 means "Any Color", no filtering
                
                // Check avoid white
                if (avoid_white_check.active) {
                    // Consider white as RGB values > 240
                    if (swatch.red > 240 && swatch.green > 240 && swatch.blue > 240) {
                        continue;
                    }
                }
                
                // Check avoid black
                if (avoid_black_check.active) {
                    // Consider black as RGB values < 15
                    if (swatch.red < 15 && swatch.green < 15 && swatch.blue < 15) {
                        continue;
                    }
                }
                
                filtered.add (swatch);
            }

            // If "Only distinct colors" is checked, remove very similar colors
            if (distinct_check.active && filtered.size > 1) {
                // Sort by population first (most common colors first)
                filtered.sort ((c1, c2) => {
                    return c2.population - c1.population;
                });
                
                // Threshold for considering colors "very similar" (squared distance)
                // 2500 = ~50 RGB units, which is quite similar visually
                const double SIMILARITY_THRESHOLD = 2500.0;
                
                var distinct_colors = new Gee.ArrayList<Utils.Palette.Swatch> ();
                
                // Iterate through colors, only adding if sufficiently different from all previously added
                foreach (var swatch in filtered) {
                    bool is_similar = false;
                    
                    // Check against all colors we've already accepted
                    foreach (var existing in distinct_colors) {
                        double dist = color_distance_squared (swatch, existing);
                        if (dist < SIMILARITY_THRESHOLD) {
                            is_similar = true;
                            break; // No need to check further, already found a similar color
                        }
                    }
                    
                    // Only add if it's different enough from all existing colors
                    if (!is_similar) {
                        distinct_colors.add (swatch);
                    }
                }
                
                filtered = distinct_colors;
            }

            // Apply ordering - optimize by pre-computing sort keys to avoid repeated calculations
            uint order_selected = order_dropdown.get_selected ();
            if (order_selected == 0) {
                // Frequency: already sorted by population (default) - no computation needed
                // Just ensure it's sorted
                filtered.sort ((a, b) => {
                    return b.population - a.population;
                });
            } else if (order_selected == 1) {
                // Saturation: pre-compute saturation values to avoid repeated calculations in sort
                var swatch_values = new Gee.HashMap<Utils.Palette.Swatch, double?> ();
                foreach (var swatch in filtered) {
                    swatch_values[swatch] = get_saturation (swatch);
                }
                filtered.sort ((a, b) => {
                    double val_a = swatch_values[a];
                    double val_b = swatch_values[b];
                    if (val_b > val_a) return 1;
                    if (val_b < val_a) return -1;
                    return 0;
                });
            } else if (order_selected == 2) {
                // Luminosity: pre-compute lightness values
                var swatch_values = new Gee.HashMap<Utils.Palette.Swatch, double?> ();
                foreach (var swatch in filtered) {
                    swatch_values[swatch] = get_lightness (swatch);
                }
                filtered.sort ((a, b) => {
                    double val_a = swatch_values[a];
                    double val_b = swatch_values[b];
                    if (val_b > val_a) return 1;
                    if (val_b < val_a) return -1;
                    return 0;
                });
            } else if (order_selected == 3) {
                // Hue: pre-compute hue values
                var swatch_values = new Gee.HashMap<Utils.Palette.Swatch, double?> ();
                foreach (var swatch in filtered) {
                    swatch_values[swatch] = get_hue (swatch);
                }
                filtered.sort ((a, b) => {
                    double val_a = swatch_values[a];
                    double val_b = swatch_values[b];
                    if (val_b > val_a) return 1;
                    if (val_b < val_a) return -1;
                    return 0;
                });
            }

            return filtered;
        }

        private double get_saturation (Utils.Palette.Swatch swatch) {
            double r = swatch.red / 255.0;
            double g = swatch.green / 255.0;
            double b = swatch.blue / 255.0;
            double max = double.max (double.max (r, g), b);
            double min = double.min (double.min (r, g), b);
            if (max == 0) return 0.0;
            return (max - min) / max;
        }

        private double get_lightness (Utils.Palette.Swatch swatch) {
            double r = swatch.red / 255.0;
            double g = swatch.green / 255.0;
            double b = swatch.blue / 255.0;
            double max = double.max (double.max (r, g), b);
            double min = double.min (double.min (r, g), b);
            return (max + min) / 2.0;
        }

        private double get_hue (Utils.Palette.Swatch swatch) {
            double r = swatch.red / 255.0;
            double g = swatch.green / 255.0;
            double b = swatch.blue / 255.0;
            double max = double.max (double.max (r, g), b);
            double min = double.min (double.min (r, g), b);
            double delta = max - min;
            
            if (delta == 0) return 0.0;
            
            double hue = 0.0;
            if (max == r) {
                hue = ((g - b) / delta) % 6;
            } else if (max == g) {
                hue = ((b - r) / delta) + 2;
            } else {
                hue = ((r - g) / delta) + 4;
            }
            
            hue *= 60;
            if (hue < 0) hue += 360;
            
            return hue;
        }

        private double color_distance_squared (Utils.Palette.Swatch a, Utils.Palette.Swatch b) {
            double dr = (double)a.red - (double)b.red;
            double dg = (double)a.green - (double)b.green;
            double db = (double)a.blue - (double)b.blue;
            return dr * dr + dg * dg + db * db;
        }

        private void set_colors (Utils.Palette palette) {
            this.palette = palette;
            update_color_display ();
        }

        private void add_swatch (Utils.Palette.Swatch? swatch, string tooltip) {
            if (swatch == null) return;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.set_size_request (48, 48);
            box.set_hexpand (false);
            box.tooltip_text = tooltip;

            var provider = new Gtk.CssProvider ();
            var context = box.get_style_context ();
            Gdk.RGBA rgba = {swatch.R, swatch.G, swatch.B, swatch.A};
            var css = COLORED_SURFACE.printf (rgba.to_string ());
            provider.load_from_data (css.data);
            context.add_provider (provider, 9999);

            color_box.append (box);
        }
    }
}

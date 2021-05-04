/*
 * Copyright (c) 2021 Lains
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
    public class PaletteImportDialog : Gtk.Window {
        const string COLORED_SURFACE = """
            * {
                background: %s;
                margin-top: 12px;
                margin-bottom: 12px;
                outline: 1px solid alpha(white, 0.25);
	            outline-offset: -1px;
            }

            *:first-child {
                border-radius: 9999px 0 0 9999px;
            }
            *:last-child {
                border-radius: 0 9999px 9999px 0;
            }
        """;

        [GtkChild]
        unowned Gtk.Box color_box;
        [GtkChild]
        unowned Gtk.Box palette_drag_place;
        [GtkChild]
        unowned Gtk.Button ok_button;
        [GtkChild]
        unowned Gtk.Button cancel_button;
        [GtkChild]
        unowned Gtk.Label file_label;

        private MainWindow win = null;
        private Gtk.Image image;
        private File file;
        private Utils.Palette palette;
        int i = 0;

        public PaletteImportDialog (MainWindow win) {
            this.win = win;
        }

        construct {
            image = new Gtk.Image ();
            image.halign = Gtk.Align.CENTER;
            image.height_request = 300;
            image.width_request = 350;
            palette_drag_place.insert_child_after (image, file_label);

            cancel_button.clicked.connect (() => {
                this.dispose ();
            });

            ok_button.clicked.connect (() => {
                string[] n = {
                  Utils.make_hex(palette.dominant_swatch.red, palette.dominant_swatch.green, palette.dominant_swatch.blue),
                  Utils.make_hex(palette.title_swatch.red, palette.title_swatch.green, palette.title_swatch.blue),
                  Utils.make_hex(palette.vibrant_swatch.red, palette.vibrant_swatch.green, palette.vibrant_swatch.blue),
                  Utils.make_hex(palette.light_vibrant_swatch.red, palette.light_vibrant_swatch.green, palette.light_vibrant_swatch.blue),
                  Utils.make_hex(palette.dark_vibrant_swatch.red, palette.dark_vibrant_swatch.green, palette.dark_vibrant_swatch.blue),
                  Utils.make_hex(palette.muted_swatch.red, palette.muted_swatch.green, palette.muted_swatch.blue),
                  Utils.make_hex(palette.light_muted_swatch.red, palette.light_muted_swatch.green, palette.light_muted_swatch.blue),
                  Utils.make_hex(palette.dark_muted_swatch.red, palette.dark_muted_swatch.green, palette.dark_muted_swatch.blue)
                };

                var a = new PaletteInfo ();
                a.palname = "%s".printf(file.get_basename().replace(".jpg","").replace(".png",""));
                a.colors = new Gee.TreeSet<string> ();
                a.colors.add_all_array (n);

                win.palettestore.append (a);
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
						    var pixbuf = new Gdk.Pixbuf.from_file (file.get_path ());
                            var new_width = pixbuf.width / (pixbuf.height / image.get_allocated_height ());

                            pixbuf = pixbuf.scale_simple (new_width, image.get_allocated_height (), Gdk.InterpType.BILINEAR);
                            image.width_request = pixbuf.width/2;
                            image.set_from_pixbuf (pixbuf);

                            var palette = new Utils.Palette.from_pixbuf (pixbuf);
                            palette.generate_async.begin (() => {
                                set_colors (palette);
                            });
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

        private void set_colors (Utils.Palette palette) {
            while (color_box.get_last_child () != null) {
                color_box.get_first_child ().destroy ();
            }
            this.palette = palette;

            add_swatch (palette.dominant_swatch, "Dominant color");
            add_swatch (palette.title_swatch, "Title color");
            add_swatch (palette.vibrant_swatch, "Vibrant color");
            add_swatch (palette.light_vibrant_swatch, "Light vibrant color");
            add_swatch (palette.dark_vibrant_swatch, "Dark vibrant color");
            add_swatch (palette.muted_swatch, "Muted color");
            add_swatch (palette.dark_muted_swatch, "Dark muted color");
        }

        private void add_swatch (Utils.Palette.Swatch? swatch, string tooltip) {
            if (swatch == null) return;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.set_size_request (48, 48);
            box.set_hexpand (false);
            box.tooltip_text = tooltip;

            try {
                var provider = new Gtk.CssProvider ();
                var context = box.get_style_context ();
                Gdk.RGBA rgba = {swatch.R, swatch.G, swatch.B, swatch.A};
                var css = COLORED_SURFACE.printf (rgba.to_string ());
                provider.load_from_data (css.data);
                context.add_provider (provider, 9999);
            } catch (Error e) {
                warning ("Setting swatch color failed: %s", e.message);
            }

            color_box.append (box);
        }
    }
}

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
    public class PaletteImportDialog : Adw.Window {
        const string COLORED_SURFACE = """
            * {
                background: %s;
            }
        """;

        [GtkChild]
        unowned Gtk.Box color_box;
        [GtkChild]
        unowned Gtk.Button ok_button;
        [GtkChild]
        unowned Gtk.Button cancel_button;
        [GtkChild]
        unowned Gtk.Button image;
        [GtkChild]
        unowned Gtk.Label file_label;

        private MainWindow win = null;
        private File file;
        private Utils.Palette palette;

        public PaletteImportDialog (MainWindow win) {
            this.win = win;
        }

        construct {
            color_box.get_style_context ().add_class ("palette");
            color_box.set_overflow(Gtk.Overflow.HIDDEN);
            color_box.set_margin_bottom (12);
            color_box.set_visible (false);
            file_label.set_visible (true);
            image.set_sensitive (true);
            image.set_margin_top (12);
            ((Gtk.Image)image.get_child ()).set_pixel_size (64);

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
                            pixbuf = pixbuf.scale_simple (((Gtk.Image)image.get_child ()).get_allocated_width (), ((Gtk.Image)image.get_child ()).get_allocated_height ()*3, Gdk.InterpType.BILINEAR);
                            ((Gtk.Image)image.get_child ()).set_from_pixbuf (pixbuf);

                            image.set_sensitive (false);
                            image.set_margin_top (0);
                            ((Gtk.Image)image.get_child ()).set_pixel_size (256);
                            image.get_style_context ().remove_class ("dim-label");

                            var palette = new Utils.Palette.from_pixbuf (pixbuf);
                            palette.generate_async.begin (() => {
                                set_colors (palette);
                            });

                            color_box.set_visible (true);
                            file_label.set_visible (false);
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

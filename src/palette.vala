namespace Emulsion {
    public class PaletteInfo : Object {
        /*
         * name : string of the Palette's name e.g. "GNOME";
         * colors : string array of the Palette, all in hexcodes;
         */

        public string palname { get; set; }
        public Gee.TreeSet<string> colors { get; set; }
        public Gee.TreeSet<string> colorsnames { get; set; }
    }

    public class PaletteRenderer : Gtk.Box {
        public PaletteInfo _palette;
        public PaletteInfo palette {
            get {
                return _palette;
            }

            set {
                if(_palette == value) {
                    return;
                }
                _palette = value;
                queue_draw ();
            }
        }

        construct {
            this.get_style_context().add_class ("palette");
            this.set_overflow(Gtk.Overflow.HIDDEN);
            this.set_orientation (Gtk.Orientation.HORIZONTAL);
            this.set_halign (Gtk.Align.CENTER);
            this.set_margin_start (6);
            this.set_margin_top (6);
            this.set_margin_end (6);
            this.set_size_request (256, 64);
	    }

	    protected override void snapshot (Gtk.Snapshot snapshot) {
	        int j = 0;
	        var arrco = palette.colors.to_array ();
            for (int i = 0; i < arrco.length; i++) {
                Gdk.RGBA gc = {};
                gc.parse (arrco[i]);

                switch (arrco.length) {
                    case 1:
                        snapshot.append_color (gc, {{i * 256, 0}, {256, 64}});
                        break;
                    case 2:
                        snapshot.append_color (gc, {{i * 128, 0}, {128, 64}});
                        break;
                    case 3:
                        snapshot.append_color (gc, {{i * 85, 0}, {85, 64}});
                        break;
                    case 4:
                        snapshot.append_color (gc, {{i * 64, 0}, {64, 64}});
                        break;
                    case 5:
                        snapshot.append_color (gc, {{i * 51, 0}, {51, 64}});
                        break;
                    case 6:
                        snapshot.append_color (gc, {{i * 43, 0}, {43, 64}});
                        break;
                    case 7:
                        snapshot.append_color (gc, {{i * 37, 0}, {37, 64}});
                        break;
                    case 8:
                        snapshot.append_color (gc, {{i * 32, 0}, {32, 64}});
                        break;
                    default:
                        if (i < 8) {
                            snapshot.append_color (gc, {{i * 32, 0}, {32, 32}});
                            this.set_size_request (i * 32, 32);
                        } else {
                            if (i <= 15) {
                                snapshot.append_color (gc, {{j++ * 32, 32}, {32, 32}});
                            } else if (i > 15) {
                                if (contrast_ratio(gc, {0,0,0,1}) > contrast_ratio(gc, {1,1,1,1}) + 3) {
                                    snapshot.append_color ({0,0,0,1}, {{232, 48}, {16, 2}});
                                    snapshot.append_color ({0,0,0,1}, {{239, 41}, {2, 16}});
                                } else {
                                    snapshot.append_color ({1,1,1,1}, {{232, 48}, {16, 2}});
                                    snapshot.append_color ({1,1,1,1}, {{239, 41}, {2, 16}});
                                }
                            }
                            this.set_size_request (8 * 32, 64);
                        }
                        break;
                }
            }
        }

        private static double contrast_ratio (Gdk.RGBA bg_color, Gdk.RGBA fg_color) {
            // From WCAG 2.0 https://www.w3.org/TR/WCAG20/#contrast-ratiodef
            var bg_luminance = get_luminance (bg_color);
            var fg_luminance = get_luminance (fg_color);

            if (bg_luminance > fg_luminance) {
                return (bg_luminance + 0.05) / (fg_luminance + 0.05);
            }

            return (fg_luminance + 0.05) / (bg_luminance + 0.05);
        }

        private static double get_luminance (Gdk.RGBA color) {
            // Values from WCAG 2.0 https://www.w3.org/TR/WCAG20/#relativeluminancedef
            var red = sanitize_color (color.red) * 0.2126;
            var green = sanitize_color (color.green) * 0.7152;
            var blue = sanitize_color (color.blue) * 0.0722;

            return red + green + blue;
        }

        private static double sanitize_color (double color) {
            // From WCAG 2.0 https://www.w3.org/TR/WCAG20/#relativeluminancedef
            if (color <= 0.03928) {
                return color / 12.92;
            }

            return Math.pow ((color + 0.055) / 1.055, 2.4);
        }
    }
}

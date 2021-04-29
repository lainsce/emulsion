namespace Emulsion {
    public class PaletteInfo : Object {
        public string name { get; set; }
        public string[] colors { get; set; }
    }

    public class PaletteRenderer : Gtk.Box {
        public PaletteInfo _palette;
        public PaletteInfo palette {
            get {
                return _palette;
            }

            set {
                if(value == _palette) {
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
            this.set_halign (Gtk.Align.START);
            this.set_margin_start (6);
            this.set_margin_top (6);
            this.set_margin_end (6);
            this.set_margin_bottom (6);
	    }

	    protected override void snapshot (Gtk.Snapshot snapshot) {
	        int j = 0;
            for (int i = 0; i <= palette.colors.length; i++) {
                Gdk.RGBA gc = {};
                gc.parse (palette.colors[i]);

                if (i <= 8) {
                   snapshot.append_color (gc, {{i * 32, 0}, {32, 32}});
                   this.set_size_request (i * 32, 32);
                } else {
                   snapshot.append_color (gc, {{j++ * 32, 32}, {32, 32}});
                   this.set_size_request (8 * 32, 64);
                }
            }
        }
    }
}

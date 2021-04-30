namespace Emulsion {
    public class ColorInfo : Object {
        public string name { get; set; }
        public string color { get; set; }
    }

    public class ColorRenderer : Gtk.Box {
        public ColorInfo _color;
        public ColorInfo color {
            get {
                return _color;
            }

            set {
                if(_color == value) {
                    return;
                }
                _color = value;
                queue_draw ();
            }
        }

        construct {
            this.get_style_context().add_class ("color");
            this.set_overflow(Gtk.Overflow.HIDDEN);
            this.set_orientation (Gtk.Orientation.HORIZONTAL);
            this.set_halign (Gtk.Align.CENTER);
            this.set_margin_start (6);
            this.set_margin_top (6);
            this.set_margin_end (6);
            this.set_size_request (128, 128);
	    }

	    protected override void snapshot (Gtk.Snapshot snapshot) {
            Gdk.RGBA gc = {};
            gc.parse (color.color);
            snapshot.append_color (gc, {{0, 0}, {128, 128}});
        }
    }
}

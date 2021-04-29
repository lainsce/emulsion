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
                if (_palette == value) {
                    return;
                }
                _palette = value;
            }
        }

        construct {
            this.get_style_context().add_class ("palette");

            if(palette.colors != null) {
                foreach (string c in palette.colors) {
                    var p = new PaletteButton (c);
                    this.append(p);
                }
            }
	    }
    }
}

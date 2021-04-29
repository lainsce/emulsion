namespace Emulsion {
    public class PaletteInfo : Object {
        public string _name;
        public string name {
            get {
                return _name;
            }

            set {
                _name = value;
            }
        }

        public string[] _colors;
        public string[] colors {
            get {
                return _colors;
            }

            set {
                _colors = value;
            }
        }
    }

    public class PaletteRenderer : Gtk.Box {
        public PaletteInfo _palette;
        public PaletteInfo palette {
            get {
                return _palette;
            }

            set {
                _palette = value;
            }
        }

        construct {
            this.get_style_context().add_class ("palette");

            foreach (string c in palette.colors) {
                var p = new PaletteButton (c);
                this.append(p);
            }
	    }
    }
}

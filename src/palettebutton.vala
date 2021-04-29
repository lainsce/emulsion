namespace Emulsion {
    public class PaletteButton : Gtk.Button {
		private Gtk.CssProvider provider = new Gtk.CssProvider();
		private string _hex = "";

		public string hex {
			get {
				return _hex;
			}

			set {
				_hex = value;
				provider.load_from_data("* { background: %s; }".printf(value).data);
			}
		}

		construct {
			width_request = 32;
			height_request = 32;
			get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		}

		public PaletteButton (string hex) {
			Object(hex: hex);
		}
	}
}

/* window.vala
 *
 * Copyright 2021 Lains
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Emulsion {
	[GtkTemplate (ui = "/io/github/lainsce/Emulsion/window.ui")]
	public class MainWindow : Adw.ApplicationWindow {
	    [GtkChild]
	    unowned Gtk.MenuButton menu_button;
	    [GtkChild]
	    unowned Gtk.MenuButton menu_button2;
	    [GtkChild]
	    unowned Gtk.ToggleButton search_button;
	    [GtkChild]
	    unowned Gtk.Button add_palette_button;
	    [GtkChild]
	    unowned Gtk.Button back_button;
	    [GtkChild]
	    unowned Gtk.Revealer search_revealer;

	    [GtkChild]
	    unowned Gtk.Label color_label;
	    [GtkChild]
	    unowned Gtk.Stack header_stack;
	    [GtkChild]
	    unowned Gtk.Stack main_stack;

        [GtkChild]
	    public unowned Gtk.GridView palette_fb;
	    [GtkChild]
	    unowned Gtk.SingleSelection palette_model;
	    [GtkChild]
	    public unowned Gtk.GridView color_fb;
	    [GtkChild]
	    unowned Gtk.SingleSelection color_model;

	    public GLib.ListStore palettestore;
	    public GLib.ListStore colorstore;
	    public Manager m;
	    public ColorInfo win_color_info;

	    public signal void clicked ();
	    public signal void toggled ();

	    public SimpleActionGroup actions { get; construct; }
        public const string ACTION_PREFIX = "win.";
        public const string ACTION_ABOUT = "action_about";
        public const string ACTION_KEYS = "action_keys";
        public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();
        private const GLib.ActionEntry[] ACTION_ENTRIES = {
              {ACTION_ABOUT, action_about},
              {ACTION_KEYS, action_keys},
        };

        public Gtk.Application app { get; construct; }
		public MainWindow (Gtk.Application app) {
			Object (
			    application: app,
			    app: app
			);
		}

		static construct {
		    // TODO: Figure out what to do with these so they work.
		    //       There's abysmal demo/examples count online.

		    //install_action ("win.delete_palette", "u", (Gtk.WidgetActionActivateFunc)delete_palette);
            //install_action ("win.delete_color", "u", (Gtk.WidgetActionActivateFunc)delete_color);
		}

        construct {
			// Initial settings
            Adw.init ();
            m = new Manager (this);

            actions = new SimpleActionGroup ();
            actions.add_action_entries (ACTION_ENTRIES, this);
            insert_action_group ("win", actions);

            foreach (var action in action_accelerators.get_keys ()) {
                var accels_array = action_accelerators[action].to_array ();
                accels_array += null;

                app.set_accels_for_action (ACTION_PREFIX + action, accels_array);
            }

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/io/github/lainsce/Emulsion/app.css");
            Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            default_theme.add_resource_path ("/io/github/lainsce/Emulsion");

            var builder = new Gtk.Builder.from_resource ("/io/github/lainsce/Emulsion/menu.ui");
            menu_button.menu_model = (MenuModel)builder.get_object ("menu");
            menu_button2.menu_model = (MenuModel)builder.get_object ("menu");

            palettestore = new GLib.ListStore (typeof (PaletteInfo));
            palette_model.set_model (palettestore);

            palette_fb.activate.connect ((pos) => {
                header_stack.set_visible_child_name ("colheader");
                main_stack.set_visible_child_name ("colbody");

                int j = 0;
                uint i, n = palettestore.get_n_items ();
                for (i = 0; i < n; i++) {
                    var item = palettestore.get_item (pos);

                    colorstore.remove_all ();

                    for (j = 0; j < ((PaletteInfo)item).colors.length; j++) {
                        var a = new ColorInfo ();
                        a.name = ((PaletteInfo)item).colors[j];
                        a.color = ((PaletteInfo)item).colors[j];
                        colorstore.append (a);
                    }
                    color_label.label = ((PaletteInfo)item).name;
                }
            });

            colorstore = new GLib.ListStore (typeof (ColorInfo));
            color_model.set_model (colorstore);

            color_fb.activate.connect ((pos) => {
                var cep = new ColorEditPopover (this);

                var item = colorstore.get_item (pos);
                cep.color_info = ((ColorInfo)item);

                Gtk.Allocation allocation;
                color_fb.get_allocation (out allocation);

                cep.set_pointing_to (allocation);
                cep.show ();

                cep.closed.connect (() => {
                    colorstore.remove (pos);
                    colorstore.insert (pos, cep.color_info);

                    int j = 0;
                    uint i, n = palettestore.get_n_items ();
                    for (i = 0; i < n; i++) {
                        var pitem = palettestore.get_item (i);

                        if (color_label.label == ((PaletteInfo)pitem).name) {
                            foreach (string color in ((PaletteInfo)pitem).colors) {
                                if (color != ((ColorInfo)item).color) {
                                    ((PaletteInfo)pitem).colors[pos] = cep.color_info.color;
                                    palette_fb.queue_draw ();
                                    m.save_palettes.begin (palettestore);
                                }
                            }
                        }
                    }
                });

                color_fb.queue_draw ();
            });

            back_button.clicked.connect (() => {
                header_stack.set_visible_child_name ("palheader");
                main_stack.set_visible_child_name ("palbody");
                palette_fb.queue_draw ();
            });

            search_button.toggled.connect (() => {
               search_revealer.set_reveal_child (search_button.get_active());
            });

            palettestore.items_changed.connect (() => {
                m.save_palettes.begin (palettestore);
            });

            colorstore.items_changed.connect (() => {
                m.save_palettes.begin (palettestore);
            });

            // Some palettes to start
            if (Emulsion.Application.gsettings.get_boolean("first-time")) {
                populate_palettes_view ();
                Emulsion.Application.gsettings.set_boolean("first-time", false);
            } else {
                m.load_from_file.begin ();
            }

            add_palette_button.clicked.connect (() => {
                var rand = new GLib.Rand ();
                string[] n = {};

                for (int i = 0; i <= rand.int_range (1, 16); i++) {
                    var rc = "#" + "%02x%02x%02x".printf (rand.int_range(15, 255), rand.int_range(15, 255), rand.int_range(15, 255));
                    n += rc;
                }

                var a = new PaletteInfo ();
                a.name = "New Palette";
                a.colors = n;

                palettestore.append (a);
            });

            this.set_size_request (360, 500);
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
			this.show ();
		}

	    void delete_palette (Gtk.Widget w, string a, GLib.Variant p) {
	        var selfe = w as MainWindow;
            selfe.palettestore.remove ((uint)p_pos(p.get_uint32()));
        }

        void delete_color (Gtk.Widget w, string a, GLib.Variant p) {
            var selfe = w as MainWindow;
            selfe.colorstore.remove ((uint)c_pos(p.get_uint32()));
        }

        [GtkCallback]
        private GLib.Variant p_pos (uint pos) {
            return new GLib.Variant.uint32 (pos);
        }

        [GtkCallback]
        private GLib.Variant c_pos (uint pos) {
            return new GLib.Variant.uint32 (pos);
        }

        public void action_keys () {
            try {
                var build = new Gtk.Builder ();
                build.add_from_resource ("/io/github/lainsce/Emulsion/keys.ui");
                var window =  (Gtk.ShortcutsWindow) build.get_object ("shortcuts-emulsion");
                window.set_transient_for (this);
                window.show ();
            } catch (Error e) {
                warning ("Failed to open shortcuts window: %s\n", e.message);
            }
        }

        public void action_about () {
            const string COPYRIGHT = "Copyright \xc2\xa9 2021 Paulo \"Lains\" Galardi\n";

            const string? AUTHORS[] = {
                "Paulo \"Lains\" Galardi",
                null
            };

            var program_name = Config.NAME_PREFIX + _("Emulsion");
            Gtk.show_about_dialog (this,
                                   "program-name", program_name,
                                   "logo-icon-name", Config.APP_ID,
                                   "version", Config.VERSION,
                                   "comments", _("Stock up on colors."),
                                   "copyright", COPYRIGHT,
                                   "authors", AUTHORS,
                                   "artists", null,
                                   "license-type", Gtk.License.GPL_3_0,
                                   "wrap-license", false,
                                   "translator-credits", _("translator-credits"),
                                   null);
        }

        void populate_palettes_view () {
            var a = new PaletteInfo ();
            a.name = "Flat";
            a.colors = {"#e65353", "#e6b453", "#94e692", "#53e6c3", "#6b89d4"};

            palettestore.append (a);

            var b = new PaletteInfo ();
            b.name = "GNOME";
            b.colors = {"#e01b24", "#ff7800", "#f6d32d", "#33d17a","#3584e4", "#9141ac"};

            palettestore.append (b);

            var c = new PaletteInfo ();
            c.name = "Sandy";
            c.colors = {"#f6efdc", "#dabab1", "#bacaba"};

            palettestore.append (c);

            var d = new PaletteInfo ();
            d.name = "Game Boy";
            d.colors = {"#0f380f", "#306230", "#8bac0f", "#9bbc0f"};

            palettestore.append (d);

            var e = new PaletteInfo ();
            e.name = "Pico-8";
            e.colors = {"#000000", "#1D2B53", "#7E2553", "#008751", "#AB5236", "#5F574F",
                        "#C2C3C7", "#FFF1E8", "#FF004D", "#FFA300", "#FFEC27", "#00E436",
                        "#29ADFF", "#83769C", "#FF77A8", "#FFCCAA"};

            palettestore.append (e);

            var f = new PaletteInfo ();
            f.name = "Monochroma";
            f.colors = {"#171219", "#f2fbeb"};

            palettestore.append (f);

            var g = new PaletteInfo ();
            g.name = "Endesga 8";
            g.colors = {"#1b1c33", "#d32734", "#da7d22", "#e6da29", "#28c641", "#2d93dd",
                        "#7b53ad", "#fdfdf8"};

            palettestore.append (g);

            var h = new PaletteInfo ();
            h.name = "CGA";
            h.colors = {"#000000", "#AA0000", "#AAAA00", "#00AA00", "#0000AA", "#00AAAA",
                        "#AA00AA", "#FFFFFF"};

            palettestore.append (h);
        }
	}
}

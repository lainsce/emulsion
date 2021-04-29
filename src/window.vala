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
	    unowned Gtk.ToggleButton search_button2;
	    [GtkChild]
	    unowned Gtk.Button add_palette_button;
	    [GtkChild]
	    unowned Gtk.Revealer search_revealer;
	    [GtkChild]
	    unowned Gtk.Revealer search_revealer2;

	    [GtkChild]
	    unowned Gtk.SingleSelection palette_model;

	    public GLib.ListStore palettestore;

	    public signal void clicked ();
	    public signal void toggled ();

		public MainWindow (Gtk.Application app) {
			Object (
			    application: app
			);
		}

        construct {
			// Initial settings
            Adw.init ();
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

            search_button.toggled.connect (() => {
               search_revealer.set_reveal_child (search_button.get_active());
            });

            search_button2.toggled.connect (() => {
               search_revealer2.set_reveal_child (search_button2.get_active());
            });

            // Some palettes to start
            populate_palettes_view ();

            add_palette_button.clicked.connect (() => {
                var rand = new GLib.Rand ();
                string[] cmyk = {};

                for (int i = 0; i <= rand.int_range (4, 15); i++) {
                    var rc = "#" + "%x".printf(((uint)Math.floor(((int)rand.next_int ())*16777215)));
                    cmyk += rc;
                }

                var a = new PaletteInfo ();
                a.name = "Random";
                a.colors = cmyk;

                palettestore.append (a);
            });

            install_action ("delete-palette", "u", (Gtk.WidgetActionActivateFunc)delete_palette);

            this.set_size_request (360, 500);
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
			this.show ();
		}

	    void delete_palette (Gtk.Widget widget, string action, GLib.Variant param) {
	        var self = widget as MainWindow;
            self.palettestore.remove ((uint32) get_pos(param.get_uint32 ()));
        }

        [GtkCallback]
        private GLib.Variant get_pos (uint32 pos) {
            return new Variant.uint32 (pos);
        }

        void populate_palettes_view () {
            var a = new PaletteInfo ();
            a.name = "Flat";
            a.colors = {"#e65353", "#e6b453", "#94e653", "#53e6c3", "#6b89d4", "#c181cb"};

            palettestore.append (a);

            var b = new PaletteInfo ();
            b.name = "GNOME";
            b.colors = {"#e01b24", "#ff7800", "#f6d32d", "#33d17a","#3584e4", "#9141ac"};

            palettestore.append (b);

            var c = new PaletteInfo ();
            c.name = "Sandy";
            c.colors = {"#b27777", "#dacaac", "#b9cbab", "#bfc8e9", "#abadcb", "#c4abcb"};

            palettestore.append (c);

            var d = new PaletteInfo ();
            d.name = "Game Boy";
            d.colors = {"#0f380f", "#306230", "#8bac0f", "#9bbc0f"};

            palettestore.append (d);

            var e = new PaletteInfo ();
            e.name = "Pico-8";
            e.colors = {"#000000", "#1D2B53", "#7E2553", "#008751", "#AB5236", "#5F574F",
                        "#C2C3C7", "#FFF1E8", "#FF004D", "#FFA300", "#FFEC27", "#00E436",
                        "#29ADFF", "#83769C", "#FF77A8", "#FFCCAA", "#FFFFFF"};

            palettestore.append (e);
        }
	}
}

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
	    unowned Gtk.Button add_color_button;
	    [GtkChild]
	    unowned Gtk.Button back_button;

	    [GtkChild]
	    unowned Gtk.Revealer search_revealer;
        [GtkChild]
	    unowned Gtk.SearchBar searchbar;
	    [GtkChild]
	    unowned Gtk.SearchEntry searchentry;
	    [GtkChild]
	    unowned Gtk.FilterListModel palette_filter_model;

	    [GtkChild]
	    unowned Gtk.Label palette_hlabel;
	    [GtkChild]
	    unowned Gtk.Label palette_label;
	    [GtkChild]
	    unowned Gtk.Entry color_label;
	    [GtkChild]
	    unowned Gtk.Stack header_stack;
	    [GtkChild]
	    unowned Gtk.Stack main_stack;
	    [GtkChild]
	    unowned Gtk.Stack palette_stack;

	    [GtkChild]
	    unowned Gtk.ScrolledWindow palette_window;
	    [GtkChild]
	    unowned Gtk.ScrolledWindow color_window;

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
        private Gtk.CustomFilter palette_filter;
	    int uid_counter = 1;

	    public signal void clicked ();
	    public signal void toggled ();

	    public SimpleActionGroup actions { get; construct; }
        public const string ACTION_PREFIX = "win.";
        public const string ACTION_ABOUT = "action_about";
        public const string ACTION_KEYS = "action_keys";
        public const string ACTION_DELETE_PALETTE = "delete_palette";
        public const string ACTION_DELETE_COLOR = "delete_color";
        public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();
        private const GLib.ActionEntry[] ACTION_ENTRIES = {
              {ACTION_ABOUT, action_about},
              {ACTION_KEYS, action_keys},
              {ACTION_DELETE_PALETTE, delete_palette},
              {ACTION_DELETE_COLOR, delete_color},
        };

        public Gtk.Application app { get; construct; }
		public MainWindow (Gtk.Application app) {
			Object (
			    application: app,
			    app: app
			);
		}

		static construct {
		    install_action ("win.delete_palette", null, (Gtk.WidgetActionActivateFunc)delete_palette);
            install_action ("win.delete_color", null, (Gtk.WidgetActionActivateFunc)delete_color);
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
            palette_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            palette_fb.hscroll_policy = palette_fb.vscroll_policy = Gtk.ScrollablePolicy.MINIMUM;

            palette_filter = new Gtk.CustomFilter (filter_palettes);
            palette_filter.bind_property ("search", searchentry, "text", 0);
            palette_filter_model.set_model (palettestore);
            palette_filter_model.set_filter (palette_filter);

            palette_fb.activate.connect ((pos) => {
                header_stack.set_visible_child_name ("colheader");
                main_stack.set_visible_child_name ("colbody");
                search_revealer.set_reveal_child (false);
                search_button.set_active (false);

                int j = 0;
                uint i, n = palettestore.get_n_items ();
                for (i = 0; i < n; i++) {
                    var item = palettestore.get_item (pos);

                    colorstore.remove_all ();

                    for (j = 0; j < ((PaletteInfo)item).colors.size; j++) {
                        var a = new ColorInfo ();
                        var arrco = ((PaletteInfo)item).colors.to_array();
                        a.name = arrco[j];
                        a.color = arrco[j];
                        a.uid = ((PaletteInfo)item).palname;
                        colorstore.append (a);
                    }
                    color_label.set_text(((PaletteInfo)item).palname);
                }
            });

            colorstore = new GLib.ListStore (typeof (ColorInfo));
            color_model.set_model (colorstore);
            color_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            color_fb.hscroll_policy = color_fb.vscroll_policy = Gtk.ScrollablePolicy.NATURAL;

            color_label.set_icon_from_icon_name (Gtk.EntryIconPosition.SECONDARY,"document-edit-symbolic");
            color_label.set_icon_activatable (Gtk.EntryIconPosition.SECONDARY, true);
            color_label.set_icon_tooltip_text (Gtk.EntryIconPosition.SECONDARY, _("Set New Palette Name"));
            color_label.activate.connect (() => {
                var pitem = palettestore.get_item (palette_model.get_selected ());
                ((PaletteInfo)pitem).palname = color_label.get_text ();
            });
            color_label.icon_press.connect (() => {
                var pitem = palettestore.get_item (palette_model.get_selected ());
                ((PaletteInfo)pitem).palname = color_label.get_text ();
            });

            color_fb.activate.connect ((pos) => {
                var cep = new ColorEditPopover (this);

                var item = colorstore.get_item (pos);
                cep.color_info = ((ColorInfo)item);

                Gtk.Allocation alloc;
                color_fb.get_focus_child ().get_allocation (out alloc);
                cep.set_pointing_to (alloc);
                cep.set_offset (100, 100);
                cep.popup ();

                cep.closed.connect (() => {
                    colorstore.remove (pos);
                    colorstore.insert (pos, cep.color_info);

                    int j;
                    uint i, n = palettestore.get_n_items ();
                    for (i = 0; i < n; i++) {
                        var pitem = palettestore.get_item (i);

                        var arrco = ((PaletteInfo)pitem).colors.to_array();
                        for (j = 0; j < arrco.length; j++) {
                            if (((ColorInfo)item).uid == ((PaletteInfo)pitem).palname) {
                                if (arrco[j] != ((ColorInfo)item).color) {
                                    ((PaletteInfo)pitem).colors.remove (arrco[pos]);
                                    ((PaletteInfo)pitem).colors.add (cep.color_info.color);
                                    m.save_palettes.begin (palettestore);
                                    color_fb.queue_draw ();
                                    palette_fb.queue_draw ();
                                }
                            }
                        }
                    }
                });

                color_fb.queue_draw ();
                palette_fb.queue_draw ();
            });

            back_button.clicked.connect (() => {
                header_stack.set_visible_child_name ("palheader");
                main_stack.set_visible_child_name ("palbody");
                palette_fb.queue_draw ();
            });

            searchbar.set_key_capture_widget (this);
            search_button.toggled.connect (() => {
               search_revealer.set_reveal_child (search_button.get_active());
            });

            palettestore.items_changed.connect (() => {
                m.save_palettes.begin (palettestore);
            });

            colorstore.items_changed.connect (() => {
                color_fb.queue_draw ();
                palette_fb.queue_draw ();
                m.save_palettes.begin (palettestore);
            });

            // Some palettes to start
            if (Emulsion.Application.gsettings.get_boolean("first-time")) {
                populate_palettes_view ();
                palette_label.set_visible(true);
                palette_stack.set_visible_child_name ("palfull");
                palette_hlabel.set_text("");
                Emulsion.Application.gsettings.set_boolean("first-time", false);
            } else {
                m.load_from_file.begin ();
                if (palettestore.get_item(0) == null) {
                    palette_label.set_visible(false);
                    palette_stack.set_visible_child_name ("palempty");
                    palette_hlabel.set_text("Emulsion");
                    search_button.set_visible(false);
                } else {
                    palette_label.set_visible(true);
                    palette_stack.set_visible_child_name ("palfull");
                    palette_hlabel.set_text("");
                    search_button.set_visible(true);
                }
            }

            add_palette_button.clicked.connect (() => {
                palette_stack.set_visible_child_name ("palfull");
                palette_label.set_visible(true);
                palette_hlabel.set_text("");
                search_button.set_visible(true);

                var rand = new GLib.Rand ();
                string[] n = {};

                for (int i = 0; i <= rand.int_range (1, 16); i++) {
                    var rc = "#" + "%02x%02x%02x".printf (rand.int_range(15, 255), rand.int_range(15, 255), rand.int_range(15, 255));
                    n += rc;
                }

                var a = new PaletteInfo ();
                a.palname = "New Palette " + "%d".printf(uid_counter++);
                a.colors = new Gee.TreeSet<string> ();
                a.colors.add_all_array (n);

                palettestore.append (a);
            });

            add_color_button.clicked.connect (() => {
                var rand = new GLib.Rand ();
                var rc = "#" + "%02x%02x%02x".printf (rand.int_range(15, 255), rand.int_range(15, 255), rand.int_range(15, 255));

                var a = new ColorInfo ();
                a.name = rc;
                a.color = rc;

                var pitem = palettestore.get_item (palette_model.get_selected ());
                a.uid = ((PaletteInfo)pitem).palname;

                if (a.uid == ((PaletteInfo)pitem).palname) {
                    var arrco = ((PaletteInfo)pitem).colors.to_array();
                    for (int j = 0; j <= arrco.length; j++) {
                        ((PaletteInfo)pitem).colors.add(a.color);
                    }
                }

                m.save_palettes.begin (palettestore);
                colorstore.append (a);
                color_fb.queue_draw ();
                palette_fb.queue_draw ();
            });

            this.set_size_request (360, 360);
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
			this.show ();
		}

		bool filter_palettes () {
		    var search = searchentry.get_text ();
		    if (search.length > 0) {
		        uint i, n = palettestore.get_n_items ();
                for (i = 0; i < n; i++) {
                    var pitem = palettestore.get_item (i);
                    return ((PaletteInfo)pitem).palname.contains (search);
                }
            }
            return true;
		}

	    public void delete_palette () {
            palettestore.remove (palette_model.selected);

            if (palettestore.get_item(0) == null) {
                palette_stack.set_visible_child_name ("palempty");
                palette_label.set_visible(false);
                search_button.set_visible(false);
                palette_hlabel.set_text("Emulsion");
            }
        }

        public void delete_color () {
            var pitem = palettestore.get_item (palette_model.get_selected());
            var citem = colorstore.get_item (color_model.get_selected());
            var arrco = ((PaletteInfo)pitem).colors.to_array();

            if (arrco[0] != null) {
                if (((ColorInfo)citem).uid == ((PaletteInfo)pitem).palname) {
                    if (((ColorInfo)citem).color == arrco[color_model.get_selected()]) {
                        ((PaletteInfo)pitem).colors.remove(((ColorInfo)citem).color);
                    }
                }
                colorstore.remove (color_model.get_selected());
            }
            if (colorstore.get_item(0) == null) {
                header_stack.set_visible_child_name ("palheader");
                main_stack.set_visible_child_name ("palbody");
                palettestore.remove (palette_model.selected);
            }

            m.save_palettes.begin (palettestore);
            color_fb.queue_draw ();
            palette_fb.queue_draw ();
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
            a.palname = "Flat";
            string[] ar = {"#e65353", "#e6b453", "#94e692", "#53e6c3", "#6b89d4"};
            a.colors = new Gee.TreeSet<string> ();
            a.colors.add_all_array (ar);

            palettestore.append (a);

            var b = new PaletteInfo ();
            b.palname = "GNOME";
            string[] br = {"#e01b24", "#ff7800", "#f6d32d", "#33d17a","#3584e4", "#9141ac"};
            b.colors = new Gee.TreeSet<string> ();
            b.colors.add_all_array (br);

            palettestore.append (b);

            var c = new PaletteInfo ();
            c.palname = "Sandy";
            string[] cr = {"#f6efdc", "#dabab1", "#bacaba"};
            c.colors = new Gee.TreeSet<string> ();
            c.colors.add_all_array (cr);

            palettestore.append (c);

            var d = new PaletteInfo ();
            d.palname = "Game Boy";
            string[] dr = {"#0f380f", "#306230", "#8bac0f", "#9bbc0f"};
            d.colors = new Gee.TreeSet<string> ();
            d.colors.add_all_array (dr);

            palettestore.append (d);

            var e = new PaletteInfo ();
            e.palname = "Pico-8";
            string[] er = {"#000000", "#1D2B53", "#7E2553", "#008751", "#AB5236", "#5F574F",
                          "#C2C3C7", "#FFF1E8", "#FF004D", "#FFA300", "#FFEC27", "#00E436",
                          "#29ADFF", "#83769C", "#FF77A8", "#FFCCAA"};
            e.colors = new Gee.TreeSet<string> ();
            e.colors.add_all_array (er);

            palettestore.append (e);

            var f = new PaletteInfo ();
            f.palname = "Monochroma";
            string[] fr = {"#171219", "#f2fbeb"};
            f.colors = new Gee.TreeSet<string> ();
            f.colors.add_all_array (fr);

            palettestore.append (f);

            var g = new PaletteInfo ();
            g.palname = "Endesga 8";
            string[] gr = {"#1b1c33", "#d32734", "#da7d22", "#e6da29", "#28c641", "#2d93dd",
                          "#7b53ad", "#fdfdf8"};
            g.colors = new Gee.TreeSet<string> ();
            g.colors.add_all_array (gr);

            palettestore.append (g);

            var h = new PaletteInfo ();
            h.palname = "CGA";
            string[] hr = {"#000000", "#AA0000", "#AAAA00", "#00AA00", "#0000AA", "#00AAAA",
                          "#AA00AA", "#FFFFFF"};
            h.colors = new Gee.TreeSet<string> ();
            h.colors.add_all_array (hr);

            palettestore.append (h);
        }
	}
}

/* window.vala
 *
 * Copyright 2021-2022 Lains
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
        public unowned Gtk.ToggleButton search_button;
        [GtkChild]
        unowned Gtk.Button add_palette_button;
        [GtkChild]
        unowned Gtk.Button import_palette_button;
        [GtkChild]
        unowned Gtk.Button add_color_button;
        [GtkChild]
        unowned Gtk.Button back_button;

        [GtkChild]
        unowned Gtk.Revealer search_revealer;
        [GtkChild]
        unowned Gtk.SearchBar searchbar;
        [GtkChild]
        unowned Gtk.FilterListModel palette_filter_model;

        [GtkChild]
        public unowned Gtk.Label palette_label;
        [GtkChild]
        unowned Gtk.Entry color_label;
        [GtkChild]
        unowned Gtk.Stack main_stack;
        [GtkChild]
        public unowned Gtk.Stack palette_stack;

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

        [GtkChild]
        public unowned Gtk.Button picker_button;

        public GLib.ListStore palettestore;
        public GLib.ListStore colorstore;
        public Manager m;
        public ColorInfo win_color_info;
        int uid_counter = 1;

        public signal void clicked ();
        public signal void toggled ();

        public SimpleActionGroup actions { get; construct; }
        public const string ACTION_PREFIX = "win.";
        public const string ACTION_ABOUT = "action_about";
        public const string ACTION_KEYS = "action_keys";
        public const string ACTION_EX_TXT = "action_ex_txt";
        public const string ACTION_EX_PNG = "action_ex_png";
        public const string ACTION_EXC_TXT = "action_exc_txt";
        public const string ACTION_EXC_TXT_RGB = "action_exc_txt_rgb";
        public const string ACTION_DELETE_PALETTE = "delete_palette";
        public const string ACTION_DELETE_COLOR = "delete_color";
        public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();
        private const GLib.ActionEntry[] ACTION_ENTRIES = {
              {ACTION_ABOUT, action_about},
              {ACTION_KEYS, action_keys},
              {ACTION_EX_TXT, action_ex_txt},
              {ACTION_EX_PNG, action_ex_png},
              {ACTION_EXC_TXT, action_exc_txt},
              {ACTION_EXC_TXT_RGB, action_exc_txt_rgb},
              {ACTION_DELETE_PALETTE, delete_palette},
              {ACTION_DELETE_COLOR, delete_color},
        };

        public Adw.Application app { get; construct; }
        public MainWindow (Adw.Application app) {
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
            m = new Manager (this);

            actions = new SimpleActionGroup ();
            actions.add_action_entries (ACTION_ENTRIES, this);
            insert_action_group ("win", actions);

            foreach (var action in action_accelerators.get_keys ()) {
                var accels_array = action_accelerators[action].to_array ();
                accels_array += null;

                app.set_accels_for_action (ACTION_PREFIX + action, accels_array);
            }
            app.set_accels_for_action("app.quit", {"<Ctrl>q"});

            weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            default_theme.add_resource_path ("/io/github/lainsce/Emulsion");

            var builder = new Gtk.Builder.from_resource ("/io/github/lainsce/Emulsion/menu.ui");
            menu_button.menu_model = (MenuModel)builder.get_object ("menu");

            palettestore = new GLib.ListStore (typeof (PaletteInfo));
            palette_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            palette_fb.hscroll_policy = palette_fb.vscroll_policy = Gtk.ScrollablePolicy.NATURAL;
            palette_filter_model.set_model (palettestore);

            palette_fb.activate.connect ((pos) => {
                main_stack.set_visible_child_name ("colbody");
                search_revealer.set_reveal_child (false);
                search_button.set_active (false);
                color_fb.grab_focus ();
                colorstore.remove_all ();
                back_button.set_visible (true);
                search_button.set_visible (false);

                if (palette_model.is_selected (pos)) {
                    palette_label.set_visible (false);
                    color_label.set_visible (true);
                    color_label.set_text (((PaletteInfo)palettestore.get_item (pos)).palname);
                    int j = 0;

                    var arrcom = ((PaletteInfo)palettestore.get_item (pos)).colors.keys.to_array();
                    var arrco = ((PaletteInfo)palettestore.get_item (pos)).colors.values.to_array();
                    for (j = 0; j < arrco.length; j++) {
                        var a = new ColorInfo ();
                        a.name = arrcom[j];
                        a.color = arrco[j];
                        a.uid = ((PaletteInfo)palettestore.get_item (pos)).palname;
                        colorstore.append (a);
                    }
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
                if (color_model.is_selected (pos)) {
                    var cep = new ColorEditPopover (this);
                    var item = colorstore.get_item (pos);
                    cep.color_info = ((ColorInfo)item);
                    Gtk.Allocation alloc;
                    color_fb.get_focus_child ().get_allocation (out alloc);
                    cep.set_pointing_to (alloc);
                    cep.set_offset (25, 50);
                    cep.popup ();

                    cep.closed.connect (() => {
                        colorstore.remove (pos);
                        colorstore.insert (pos, cep.color_info);

                        int j;
                        uint i, n = palettestore.get_n_items ();
                        for (i = 0; i < n; i++) {
                            var pitem = palettestore.get_item (i);

                            var arrco = ((PaletteInfo)pitem).colors.values.to_array();
                            for (j = 0; j < arrco.length; j++) {
                                if (((ColorInfo)item).uid == ((PaletteInfo)pitem).palname) {
                                    if (arrco[j] != ((ColorInfo)item).color) {
                                        ((PaletteInfo)pitem).colors.set (cep.color_info.name, cep.color_info.color);
                                    }
                                }
                            }
                        }

                        palette_fb.queue_draw ();
                        color_fb.queue_draw ();
                    });
                }
            });

            import_palette_button.clicked.connect (() => {
                var pid = new PaletteImportDialog (this);
                pid.set_transient_for (this);
                pid.show ();
            });

            back_button.set_visible (false);
            back_button.clicked.connect (() => {
                main_stack.set_visible_child_name ("palbody");
                back_button.set_visible (false);
                search_button.set_visible (true);
                palette_label.set_visible (true);
                color_label.set_visible (false);
            });

            searchbar.set_key_capture_widget (this);
            search_button.toggled.connect (() => {
               search_revealer.set_reveal_child (search_button.get_active());
            });

            palettestore.items_changed.connect (() => {
                color_fb.queue_draw ();
                palette_fb.queue_draw ();
                m.save_palettes.begin (palettestore);
            });

            colorstore.items_changed.connect (() => {
                color_fb.queue_draw ();
                palette_fb.queue_draw ();
                m.save_palettes.begin (palettestore);
            });

            // Some palettes to start
            var settings = new Settings ();
            if (settings.first_time == true) {
                populate_palettes_view ();
                palette_label.set_visible(true);
                palette_stack.set_visible_child_name ("palfull");
                search_button.set_visible(true);
                settings.first_time = false;
            } else {
                m.load_from_file.begin ();
                if (palettestore.get_item(0) == null) {
                    palette_label.set_visible(false);
                    palette_stack.set_visible_child_name ("palempty");
                    search_button.set_visible(false);
                } else {
                    palette_label.set_visible(true);
                    palette_stack.set_visible_child_name ("palfull");
                    search_button.set_visible(true);
                }
            }

            add_palette_button.clicked.connect (() => {
                palette_stack.set_visible_child_name ("palfull");
                palette_label.set_visible(true);
                search_button.set_visible(true);

                var rand = new GLib.Rand ();
                string[] n = {};

                for (int i = 0; i <= rand.int_range (1, 16); i++) {
                    var rc = "#%02x%02x%02x".printf (rand.int_range(15, 255), rand.int_range(15, 255), rand.int_range(15, 255));
                    n += rc;
                }

                var a = new PaletteInfo ();
                a.palname = "New Palette %d".printf(uid_counter++);
                a.colors = new Gee.HashMap<string, string> ();

                for (int i = 0; i < n.length; i++) {
                    a.colors.set(n[i], n[i]);
                }

                palettestore.append (a);
            });

            add_color_button.clicked.connect (() => {
                var rand = new GLib.Rand ();
                var rc = "#" + "%02x%02x%02x".printf (rand.int_range(15, 255), rand.int_range(15, 255), rand.int_range(15, 255));

                var a = new ColorInfo ();
                a.color = rc;
                a.name = "Color %d".printf(rand.int_range(1, 255));

                var pitem = palettestore.get_item (palette_model.get_selected ());
                a.uid = ((PaletteInfo)pitem).palname;

                if (a.uid == ((PaletteInfo)pitem).palname) {
                    var arrco = ((PaletteInfo)pitem).colors.values.to_array();
                    for (int j = 0; j <= arrco.length; j++) {
                        ((PaletteInfo)pitem).colors.set(a.name, a.color);
                    }
                }
                colorstore.append (a);
            });

            picker_button.clicked.connect (() => {
                pick_color.begin ();
                m.save_palettes.begin (palettestore);
            });

            if (Config.DEVELOPMENT)
                add_css_class ("devel");

            this.set_size_request (360, 360);
            this.show ();
            var adwsm = Adw.StyleManager.get_default ();
            adwsm.set_color_scheme (Adw.ColorScheme.PREFER_DARK);
        }

        public async void pick_color () {
            try {
                var bus = yield Bus.get(BusType.SESSION);
                var shot = yield bus.get_proxy<org.freedesktop.portal.Screenshot>("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop");
                var options = new GLib.HashTable<string, GLib.Variant>(str_hash, str_equal);
                var handle = shot.pick_color ("", options);
                var request = yield bus.get_proxy<org.freedesktop.portal.Request>("org.freedesktop.portal.Desktop", handle);
                var rand = new GLib.Rand ();

                request.response.connect ((response, results) => {
                    if (response == 0) {
                        debug ("User picked a color.");
                        Gdk.RGBA color_portal = {};
                        double cr, cg, cb = 0.0;

                        results.@get("color").get ("(ddd)", out cr, out cg, out cb);

                        color_portal.red = (float)cr;
                        color_portal.green = (float)cg;
                        color_portal.blue = (float)cb;
                        color_portal.alpha = 1;

                        var pc = Utils.make_hex((float)Utils.make_srgb(color_portal.red), (float)Utils.make_srgb(color_portal.green), (float)Utils.make_srgb(color_portal.blue));

                        print ("HEX:%s\n", pc);
                        print ("R:%00.0f\nG:%00.0f\nB:%00.0f\n", (float)Utils.make_srgb(color_portal.red), (float)Utils.make_srgb(color_portal.green), (float)Utils.make_srgb(color_portal.blue));

                        var a = new ColorInfo ();
                        a.name = "Picked Color %d".printf (rand.int_range(1, 255));
                        a.color = pc;

                        var pitem = palettestore.get_item (palette_model.get_selected ());
                        a.uid = ((PaletteInfo)pitem).palname;

                        if (a.uid == ((PaletteInfo)pitem).palname) {
                            var arrco = ((PaletteInfo)pitem).colors.values.to_array();
                            for (int j = 0; j <= arrco.length; j++) {
                                ((PaletteInfo)pitem).colors.set(a.name, a.color);
                            }
                        }

                        colorstore.append (a);

                        pick_color.callback();
                    } else {
                       debug ("User didn't pick a color.");
                       return;
                    }
                });

                yield;
            } catch (GLib.Error error) {
                warning ("Failed to request color: %s", error.message);
            }
        }

        public void action_ex_txt () {
            if (palettestore.get_item(palette_model.selected) != null) {
                string ext_txt = "";
                var item = palettestore.get_item(palette_model.selected);

                ext_txt += ((PaletteInfo)item).palname + "\n";

                foreach (string c in ((PaletteInfo)item).colors.values) {
                    ext_txt += c + "\n";
                }

                // Put this ext_txt in clipboard
                var display = Gdk.Display.get_default ();
                unowned var clipboard = display.get_clipboard ();
                clipboard.set_text (ext_txt);
            }
        }

        public void action_exc_txt () {
            if (colorstore.get_item(color_model.selected) != null) {
                string ext_txt = "";
                var item = colorstore.get_item(color_model.selected);

                ext_txt += ((ColorInfo)item).color;

                // Put this ext_txt in clipboard
                var display = Gdk.Display.get_default ();
                unowned var clipboard = display.get_clipboard ();
                clipboard.set_text (ext_txt);
            }
        }

        public void action_exc_txt_rgb () {
            if (colorstore.get_item(color_model.selected) != null) {
                string ext_txt = "";
                var item = colorstore.get_item(color_model.selected);

                Gdk.RGBA gc = {};
                gc.parse(((ColorInfo)item).color);
                ext_txt += gc.to_string ();

                // Put this ext_txt in clipboard
                var display = Gdk.Display.get_default ();
                unowned var clipboard = display.get_clipboard ();
                clipboard.set_text (ext_txt);
            }
        }

        public void action_ex_png () {
            if (palettestore.get_item(palette_model.selected) != null) {
                var palren = new PaletteRenderer ();
                palren.palette = ((PaletteInfo)palettestore.get_item(palette_model.selected));
                var snap = new Gtk.Snapshot ();
                palren.snapshot (snap);

                var sf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 256, 64); // 256×64 is the palette's size;
                var cr = new Cairo.Context (sf);
                var node = snap.to_node ();
                node.draw(cr);

                var pb = Gdk.pixbuf_get_from_surface (sf, 0, 0, 256, 64);
                var mt = Gdk.Texture.for_pixbuf (pb);

                var display = Gdk.Display.get_default ();
                unowned var clipboard = display.get_clipboard ();
                clipboard.set_texture (mt);
            }
        }

        public void delete_palette () {
            palettestore.remove (palette_model.selected);

            if (palettestore.get_item(0) == null) {
                palette_stack.set_visible_child_name ("palempty");
                palette_label.set_visible(false);
                search_button.set_visible(false);
            }
        }

        public void delete_color () {
            var pitem = palettestore.get_item (palette_model.get_selected());
            var citem = colorstore.get_item (color_model.get_selected());
            var arrco = ((PaletteInfo)pitem).colors.values.to_array();

            if (arrco[0] != null) {
                if (((ColorInfo)citem).uid == ((PaletteInfo)pitem).palname) {
                    if (((ColorInfo)citem).color == arrco[color_model.get_selected()]) {
                        ((PaletteInfo)pitem).colors.unset(((ColorInfo)citem).name);
                        colorstore.remove (color_model.get_selected());
                    }
                }
            }
            if (colorstore.get_item(0) == null) {
                main_stack.set_visible_child_name ("palbody");
                palettestore.remove (palette_model.selected);
            }
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

            var program_name = "Emulsion" + Config.NAME_SUFFIX;
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
                                   // TRANSLATORS: 'Name <email@domain.com>' or 'Name https://website.example'
                                   "translator-credits", _("translator-credits"),
                                   null);
        }

        void populate_palettes_view () {
            var g = new PaletteInfo ();
            g.colors = new Gee.HashMap<string, string> ();
            g.palname = "Merveilles";
            string[] gr = {"#000000", "#72dec2", "#ffb545", "#ffffff"};
            string[] grn = {"Black", "Ultraviolet Sun", "Infrared Moon", "White"};

            for (int i = 0; i < gr.length; i++) {
                g.colors.set (grn[i], gr[i]);
            }
            palettestore.append (g);
            print("Merveilles loaded in!\n");

            var p = new PaletteInfo ();
            p.palname = "Pico-8";
            p.colors = new Gee.HashMap<string, string> ();
            string[] pr = {"#000000", "#1d2b53", "#7e2553", "#008751", "#ab5236", "#5f574f",
                          "#c2c3c7", "#fff1e8", "#ff004d", "#ffa300", "#ffec27", "#00e436",
                          "#29adff", "#83769c", "#ff77a8", "#ffccaa"};
            string[] prn = {"#000000", "#1d2b53", "#7e2553", "#008751", "#ab5236", "#5f574f",
                          "#c2c3c7", "#fff1e8", "#ff004d", "#ffa300", "#ffec27", "#00e436",
                          "#29adff", "#83769c", "#ff77a8", "#ffccaa"};

            for (int i = 0; i < pr.length; i++) {
                p.colors.set (prn[i], pr[i]);
            }
            palettestore.append (p);
            print("Pico-8 loaded in!\n");

            var e = new PaletteInfo ();
            e.palname = "Endesga 8";
            e.colors = new Gee.HashMap<string, string> ();
            string[] er = {"#1b1c33", "#d32734", "#da7d22", "#e6da29", "#28c641", "#2d93dd",
                          "#7b53ad", "#fdfdf8"};
            string[] ern = {"BLK", "RED", "ORG", "YLW", "GRN", "BLU",
                          "MAG", "WHT"};

            for (int i = 0; i < er.length; i++) {
                e.colors.set (ern[i], er[i]);
            }
            palettestore.append (e);
            print("Endesga 8 loaded in!\n");

            var d = new PaletteInfo ();
            d.palname = "Dot Matrix Game";
            d.colors = new Gee.HashMap<string, string> ();
            string[] dr = {"#081820", "#346856", "#88c070", "#e0f8d0"};
            string[] drn = {"FG", "MD1", "MD2", "BG"};

            for (int i = 0; i < dr.length; i++) {
                d.colors.set (drn[i], dr[i]);
            }
            palettestore.append (d);
            print("Dot Matrix Game loaded in!\n");

            var m = new PaletteInfo ();
            m.palname = "Monochroma";
            m.colors = new Gee.HashMap<string, string> ();
            string[] mr = {"#171219", "#f2fbeb"};
            string[] mrn = {"Murky Water", "Glistening Moon"};

            for (int i = 0; i < mr.length; i++) {
                m.colors.set (mrn[i], mr[i]);
            }
            palettestore.append (m);
            print("Monochroma loaded in!\n");
        }
    }
}

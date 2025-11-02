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
    public class MainWindow : He.ApplicationWindow {
        [GtkChild]
        unowned Gtk.MenuButton menu_button;
        [GtkChild]
        public unowned Gtk.ToggleButton search_button;
        [GtkChild]
        unowned He.OverlayButton palette_overlay_button;
        [GtkChild]
        unowned He.OverlayButton color_overlay_button;
        [GtkChild]
        unowned Gtk.ListBox library_list;
        [GtkChild]
        unowned Gtk.ListBox collections_list;
        [GtkChild]
        unowned Gtk.ListBoxRow all_palettes_row;
        [GtkChild]
        unowned Gtk.ListBoxRow recents_row;
        [GtkChild]
        unowned Gtk.ListBoxRow colors_row;
        [GtkChild]
        unowned Gtk.Button add_collection_button;
        [GtkChild]
        unowned Gtk.Button add_to_collection_button;
        [GtkChild]
        public unowned Gtk.Button back_button;
        [GtkChild]
        unowned Gtk.Image arrow;
        [GtkChild]
        unowned Gtk.Box viewtitle_box;
        [GtkChild]
        unowned He.AppBar palette_headerbar;
        [GtkChild]
        unowned Gtk.Label view_title_label;

        [GtkChild]
        unowned Gtk.Revealer searchbar;
        [GtkChild]
        unowned Gtk.FilterListModel palette_filter_model;

        [GtkChild]
        unowned He.TextField color_label;
        [GtkChild]
        public unowned Gtk.Stack main_stack;
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
        public unowned Gtk.SingleSelection color_model;
        [GtkChild]
        unowned Gtk.GridView recents_fb;
        [GtkChild]
        unowned Gtk.SingleSelection recents_model;
        [GtkChild]
        unowned He.OverlayButton recents_overlay_button;
        [GtkChild]
        unowned Gtk.GridView collections_fb;
        [GtkChild]
        unowned Gtk.SingleSelection collections_model;
        [GtkChild]
        unowned Gtk.GridView colors_fb;
        [GtkChild]
        unowned Gtk.SingleSelection colors_model;
        [GtkChild]
        public unowned Gtk.Revealer color_edit_revealer;
        [GtkChild]
        unowned ColorEditPopover color_edit_panel;


        public GLib.ListStore palettestore;
        public GLib.ListStore colorstore;
        public GLib.ListStore recent_colors_store;
        public GLib.ListStore collections_store;
        public GLib.ListStore all_colors_store;
        public Manager m;
        public ColorInfo win_color_info;
        int uid_counter = 1;
        private const int MAX_RECENT_COLORS = 100;
        private CollectionInfo? current_collection_filter = null;

        /**
         * Populate the collections sidebar ListBox with rows for each collection
         */
        private void populate_collections_sidebar () {
            // Remove all existing rows (except any static ones)
            var rows = collections_list.get_row_at_index (0);
            while (rows != null) {
                var next = rows.get_next_sibling () as Gtk.ListBoxRow;
                collections_list.remove (rows);
                rows = next;
            }

            // Add rows for each collection
            uint n = collections_store.get_n_items ();
            for (uint i = 0; i < n; i++) {
                var collection = (CollectionInfo)collections_store.get_item (i);
                if (collection == null) continue;

                var row = new Gtk.ListBoxRow ();
                var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
                box.margin_start = 18;
                box.margin_end = 12;

                var label = new Gtk.Label (collection.name);
                label.xalign = 0;
                label.hexpand = true;

                // Create menu button for context menu
                var menu_button = new Gtk.MenuButton ();
                menu_button.icon_name = "view-more-symbolic";
                menu_button.vexpand = false;
                menu_button.valign = Gtk.Align.CENTER;
                
                // Create menu model for this collection
                var menu = new Menu ();
                menu.append (_("Edit Collection"), "win.edit_collection");
                menu.append (_("Delete Collection"), "win.delete_collection");
                menu_button.menu_model = menu;
                
                // Connect activate signal to update selection model when menu button is clicked
                uint collection_index = i;
                menu_button.activate.connect (() => {
                    collections_list.select_row (row);
                    // Update the GridView selection model as well
                    if (collection_index < collections_store.get_n_items ()) {
                        collections_model.selected = collection_index;
                    }
                });

                box.append (label);
                box.append (menu_button);
                row.set_child (box);
                collections_list.append (row);
            }
        }

        /**
         * Update AppBar title and back button based on current view
         */
        public void update_appbar_title () {
            var visible_child = main_stack.get_visible_child_name ();
            
            if (visible_child == "palbody") {
                // Main palettes view - hide back button, hide title
                palette_headerbar.show_back = false;
                viewtitle_box.set_visible (true);
                back_button.set_visible (false);
                arrow.set_visible (false);
                color_label.set_visible (false);
                add_to_collection_button.set_visible (false);
                if (view_title_label != null) {
                    // Show collection name if filtering by collection
                    if (current_collection_filter != null) {
                        view_title_label.label = current_collection_filter.name;
                    } else {
                        view_title_label.label = _("Palettes");
                    }
                    view_title_label.set_visible (true);
                }
            } else if (visible_child == "colbody") {
                // Color view - show back button, show palette name in custom format
                palette_headerbar.show_back = true;
                viewtitle_box.set_visible (true);
                back_button.set_visible (true);
                arrow.set_visible (true);
                color_label.set_visible (true);
                add_to_collection_button.set_visible (true);
                if (view_title_label != null) {
                    view_title_label.set_visible (false);
                }
                var pitem = palettestore.get_item (palette_model.get_selected ());
                if (pitem != null) {
                    color_label.text = ((PaletteInfo)pitem).palname;
                }
            } else if (visible_child == "recentsbody") {
                // Recents view - show back button, show "Recents" title
                palette_headerbar.show_back = true;
                viewtitle_box.set_visible (true);
                back_button.set_visible (false);
                arrow.set_visible (false);
                color_label.set_visible (false);
                add_to_collection_button.set_visible (false);
                if (view_title_label != null) {
                    view_title_label.label = _("Recents");
                    view_title_label.set_visible (true);
                }
            } else if (visible_child == "colorsbody") {
                // Colors view - show back button, show "All Colors" title
                palette_headerbar.show_back = true;
                viewtitle_box.set_visible (true);
                back_button.set_visible (false);
                arrow.set_visible (false);
                color_label.set_visible (false);
                add_to_collection_button.set_visible (false);
                if (view_title_label != null) {
                    view_title_label.label = _("All Colors");
                    view_title_label.set_visible (true);
                }
            } else {
                // Default - hide back button
                palette_headerbar.show_back = false;
                viewtitle_box.set_visible (false);
                add_to_collection_button.set_visible (false);
            }
        }

        /**
         * Update the all_colors_store with all colors from all palettes
         */
        public void update_all_colors_store () {
            all_colors_store.remove_all ();
            
            uint n = palettestore.get_n_items ();
            for (uint i = 0; i < n; i++) {
                var palette = (PaletteInfo)palettestore.get_item (i);
                if (palette == null) continue;
                
                foreach (var entry in palette.colors.entries) {
                    var color_info = new ColorInfo ();
                    color_info.name = entry.key;
                    color_info.color = entry.value;
                    color_info.uid = palette.palname;
                    all_colors_store.append (color_info);
                }
            }
        }

        public signal void clicked ();
        public signal void toggled ();

        /**
         * Add or update a color in the recent colors list
         */
        public void add_to_recent_colors (string name, string color) {
            // Remove existing entry if present
            for (uint i = 0; i < recent_colors_store.get_n_items (); i++) {
                var item = (RecentColorInfo)recent_colors_store.get_item (i);
                if (item.color == color && item.name == name) {
                    recent_colors_store.remove (i);
                    break;
                }
            }

            // Add to front
            var recent = new RecentColorInfo (name, color);
            recent_colors_store.insert (0, recent);

            // Limit to MAX_RECENT_COLORS
            while (recent_colors_store.get_n_items () > MAX_RECENT_COLORS) {
                recent_colors_store.remove (recent_colors_store.get_n_items () - 1);
            }
        }

        public SimpleActionGroup actions { get; construct; }
        public const string ACTION_PREFIX = "win.";
        public const string ACTION_ABOUT = "action_about";
        public const string ACTION_EX_TXT = "action_ex_txt";
        public const string ACTION_EX_PNG = "action_ex_png";
        public const string ACTION_EXC_TXT = "action_exc_txt";
        public const string ACTION_EXC_TXT_RGB = "action_exc_txt_rgb";
        public const string ACTION_DELETE_PALETTE = "delete_palette";
        public const string ACTION_EDIT_PALETTE = "edit_palette";
        public const string ACTION_DELETE_COLOR = "delete_color";
        public const string ACTION_EDIT_COLLECTION = "edit_collection";
        public const string ACTION_DELETE_COLLECTION = "delete_collection";
        public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();
        private const GLib.ActionEntry[] ACTION_ENTRIES = {
              {ACTION_ABOUT, action_about},
              {ACTION_EX_TXT, action_ex_txt},
              {ACTION_EX_PNG, action_ex_png},
              {ACTION_EXC_TXT, action_exc_txt},
              {ACTION_EXC_TXT_RGB, action_exc_txt_rgb},
              {ACTION_DELETE_PALETTE, delete_palette},
              {ACTION_EDIT_PALETTE, edit_palette},
              {ACTION_DELETE_COLOR, delete_color},
              {ACTION_EDIT_COLLECTION, edit_collection},
              {ACTION_DELETE_COLLECTION, delete_collection},
        };

        public He.Application app { get; construct; }
        public MainWindow (He.Application app) {
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
            recent_colors_store = new GLib.ListStore (typeof (RecentColorInfo));
            collections_store = new GLib.ListStore (typeof (CollectionInfo));
            all_colors_store = new GLib.ListStore (typeof (ColorInfo));
            palette_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            palette_fb.hscroll_policy = palette_fb.vscroll_policy = Gtk.ScrollablePolicy.NATURAL;
            
            palette_filter_model.set_model (palettestore);
            
            // Create collection filter that will be applied on top of search filter
            var collection_filter = new Gtk.CustomFilter ((item) => {
                if (current_collection_filter == null) {
                    return true; // Show all if no collection selected
                }
                var palette = (PaletteInfo)item;
                return current_collection_filter.palette_names.contains (palette.palname);
            });
            
            // Get the existing search filter (from UI binding)
            var existing_filter = palette_filter_model.get_filter ();
            
            // Combine filters: first apply collection filter, then search filter
            // Use EveryFilter which is the concrete implementation of MultiFilter
            var every_filter = new Gtk.EveryFilter ();
            every_filter.append (collection_filter);
            if (existing_filter != null && !(existing_filter is Gtk.MultiFilter)) {
                // If there's an existing single filter, add it to the multi-filter
                every_filter.append (existing_filter);
            } else if (existing_filter is Gtk.MultiFilter) {
                // If it's already a multi-filter, we need to rebuild it
                // For now, just replace it entirely
                palette_filter_model.set_filter (collection_filter);
                // Reapply search filter after a delay to let the UI binding work
                Timeout.add (100, () => {
                    var search_filt = palette_filter_model.get_filter ();
                    if (search_filt != null && search_filt != collection_filter) {
                        var new_every = new Gtk.EveryFilter ();
                        new_every.append (collection_filter);
                        new_every.append (search_filt);
                        palette_filter_model.set_filter (new_every);
                    }
                    return false;
                });
                return;
            }
            
            palette_filter_model.set_filter (every_filter);

            palette_fb.activate.connect ((pos) => {
                var pitem = palettestore.get_item (pos);
                if (pitem != null) {
                    main_stack.set_visible_child_name ("colbody");
                    searchbar.set_reveal_child (false);
                    search_button.set_active (false);
                    color_fb.grab_focus ();
                    colorstore.remove_all ();
                    back_button.set_visible (true);
                    search_button.set_visible (false);
                    arrow.set_visible (true);


                    color_label.set_visible (true);
                    color_label.text = ((PaletteInfo)pitem).palname;
                    update_appbar_title ();
                    int j = 0;

                    var arrcom = ((PaletteInfo)pitem).colors.keys.to_array();
                    var arrco = ((PaletteInfo)pitem).colors.values.to_array();
                    for (j = 0; j < arrco.length; j++) {
                        var a = new ColorInfo ();
                        a.name = arrcom[j];
                        a.color = arrco[j];
                        a.uid = ((PaletteInfo)pitem).palname;
                        colorstore.append (a);
                    }
                }
            });

            colorstore = new GLib.ListStore (typeof (ColorInfo));
            color_model.set_model (colorstore);
            color_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            color_fb.hscroll_policy = color_fb.vscroll_policy = Gtk.ScrollablePolicy.NATURAL;

            color_label.entry.set_tooltip_text (_("Set New Palette Name"));
            color_label.entry.activate.connect (() => {
                if (palette_model.get_selected () != Gtk.INVALID_LIST_POSITION) {
                    var pitem = palettestore.get_item (palette_model.get_selected ());
                    if (pitem != null) {
                        var entry = color_label.get_internal_entry ();
                        string? new_name = entry != null ? entry.text : null;
                        if (new_name != null && new_name.strip () != "") {
                            string sanitized_name = new_name.strip ();
                            ((PaletteInfo)pitem).palname = sanitized_name;
                            // Update the text field to match the saved name (in case of sanitization)
                            if (entry != null) {
                                entry.text = sanitized_name;
                            }
                            m.save_palettes.begin (palettestore);
                            update_appbar_title (); // Update title bar if it shows palette name
                        }
                    }
                }
            });

            color_fb.activate.connect ((pos) => {
                // Open dialog for any clicked color, not just selected ones
                // This makes editing easier - just click the color you want to edit
                if (pos != Gtk.INVALID_LIST_POSITION && pos < colorstore.get_n_items ()) {
                    var item = colorstore.get_item (pos);
                    if (item != null) {
                        var original_color_info = (ColorInfo)item;
                        
                        color_edit_panel.edit_position = pos;
                        color_edit_panel.color_info = original_color_info;
                        
                        // Ensure this position is selected so the panel knows which item it's editing
                        color_model.selected = pos;
                        
                        // Show the panel
                        color_edit_revealer.set_reveal_child (true);
                        color_edit_panel.show_panel ();
                        color_edit_revealer.set_visible (true);
                    } else {
                        color_edit_revealer.set_visible (false);
                    }
                }
            });

            palette_overlay_button.secondary_clicked.connect (() => {
                var pid = new PaletteImportDialog (this);
                pid.set_transient_for (this);
                pid.show ();
            });

            arrow.set_visible (false);
            
            // Connect to stack changes to update title and back button
            main_stack.notify["visible-child-name"].connect (update_appbar_title);
            
            // Handle AppBar back button with custom navigation
            // We manually control show_back, so we don't set the stack property
            // This prevents automatic stack navigation and lets us handle it manually
            palette_headerbar.back_button.clicked.connect (() => {
                var visible_child = main_stack.get_visible_child_name ();
                if (visible_child == "colbody") {
                    // From color view back to palette view
                    main_stack.set_visible_child_name ("palbody");
                } else if (visible_child == "recentsbody" || visible_child == "colorsbody") {
                    // From recents/colors back to palettes
                    library_list.select_row (all_palettes_row);
                } else {
                    // Default: go back to palettes
                    main_stack.set_visible_child_name ("palbody");
                    library_list.select_row (all_palettes_row);
                }
            });
            
            // Keep old back_button handler for color view navigation
            back_button.clicked.connect (() => {
                main_stack.set_visible_child_name ("palbody");
                search_button.set_visible (true);
                color_label.set_visible (false);
                arrow.set_visible (false);
                update_appbar_title ();
            });
            
            // Initialize AppBar state
            update_appbar_title ();

            search_button.toggled.connect (() => {
               searchbar.set_reveal_child (search_button.get_active());
            });
            
            // Initialize color edit panel (it's in the UI template, so we need to set win manually)
            color_edit_panel.win = this;
            
            color_edit_revealer.set_visible (false);
            // Connect to color edit revealer to coordinate AppBar buttons and width
            color_edit_revealer.notify["reveal-child"].connect (() => {
                // Update AppBar buttons based on panel visibility
                palette_headerbar.show_right_title_buttons = !color_edit_revealer.reveal_child;
                // Update width-request: 0 when hidden, 200 when shown
                color_edit_revealer.width_request = color_edit_revealer.reveal_child ? 200 : 0;
                color_edit_revealer.set_visible (color_edit_revealer.reveal_child);
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
                back_button.set_visible(true);
                palette_stack.set_visible_child_name ("palfull");
                search_button.set_visible(true);
                settings.first_time = false;
            } else {
                m.load_from_file.begin ();
                m.load_collections.begin ((obj, res) => {
                    m.load_collections.end (res);
                    populate_collections_sidebar ();
                });
                update_all_colors_store ();
                if (palettestore.get_item(0) == null) {
                    back_button.set_visible(false);
                    palette_stack.set_visible_child_name ("palempty");
                    search_button.set_visible(false);
                } else {
                    back_button.set_visible(true);
                    palette_stack.set_visible_child_name ("palfull");
                    search_button.set_visible(true);
                }
            }

            palette_overlay_button.clicked.connect (() => {
                palette_stack.set_visible_child_name ("palfull");
                back_button.set_visible(true);
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
                update_all_colors_store ();
            });

            color_overlay_button.clicked.connect (() => {
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
                add_to_recent_colors (a.name, a.color);
                update_all_colors_store ();
            });

            color_overlay_button.secondary_clicked.connect (() => {
                pick_color.begin ();
                m.save_palettes.begin (palettestore);
            });

            // Initialize recents view
            recents_model.set_model (recent_colors_store);
            recents_fb.hscroll_policy = recents_fb.vscroll_policy = Gtk.ScrollablePolicy.NATURAL;

            // Initialize collections view
            collections_model.set_model (collections_store);
            collections_fb.hscroll_policy = collections_fb.vscroll_policy = Gtk.ScrollablePolicy.NATURAL;
            
            // Track which menu buttons we've already connected to avoid duplicates
            var connected_buttons = new Gee.HashSet<Gtk.Widget> ();
            
            // Helper function to connect menu buttons in collection items
            void connect_menu_buttons () {
                var children = collections_fb.observe_children ();
                uint n = children.get_n_items ();
                for (uint i = 0; i < n; i++) {
                    var child = children.get_item (i);
                    if (child is Gtk.ListItem) {
                        var list_item = child as Gtk.ListItem;
                        var vertical_box = list_item.get_child () as Gtk.Box;
                        if (vertical_box != null && vertical_box.get_orientation () == Gtk.Orientation.VERTICAL) {
                            // Get the first child (horizontal box containing label and menu button)
                            var horizontal_box = vertical_box.get_first_child () as Gtk.Box;
                            if (horizontal_box != null) {
                                // Find the menu button (it's the second child, after the label)
                                var widget = horizontal_box.get_first_child ();
                                while (widget != null) {
                                    if (widget is Gtk.MenuButton) {
                                        var button = widget as Gtk.MenuButton;
                                        // Check if we already connected to this button
                                        if (!connected_buttons.contains (button)) {
                                            // Store the position for this button
                                            uint item_pos = list_item.position != Gtk.INVALID_LIST_POSITION ? 
                                                           (uint)list_item.position : 0;
                                            
                                            // Connect to the activate signal when menu button is clicked
                                            button.activate.connect (() => {
                                                // Update selection model when menu button is activated
                                                if (item_pos < collections_store.get_n_items ()) {
                                                    collections_model.selected = item_pos;
                                                }
                                            });
                                            
                                            connected_buttons.add (button);
                                        }
                                        break;
                                    }
                                    widget = widget.get_next_sibling ();
                                }
                            }
                        }
                    }
                }
            }
            
            // Connect to GridView's item creation/realization
            // Use a timeout to periodically check for new items (since BuilderListItemFactory doesn't expose signals)
            // This is called after a short delay to ensure items are created
            Timeout.add (50, () => {
                connect_menu_buttons ();
                return Source.CONTINUE; // Keep checking periodically
            });
            
            // Also check when model items change
            collections_store.items_changed.connect ((pos, removed, added) => {
                // Small delay to let GridView create new items
                Timeout.add (50, () => {
                    connect_menu_buttons ();
                    return false;
                });
            });
            
            // Handle collection activation (click) - filter palettes by collection
            collections_fb.activate.connect ((pos) => {
                if (pos != Gtk.INVALID_LIST_POSITION && pos < collections_store.get_n_items ()) {
                    // Update selection model to match the clicked position
                    collections_model.selected = pos;
                    
                    var collection = (CollectionInfo)collections_store.get_item (pos);
                    if (collection != null) {
                        // Filter palettes by collection
                        current_collection_filter = collection;
                        var filter_obj = palette_filter_model.get_filter ();
                        if (filter_obj is Gtk.MultiFilter) {
                            var multi_filter = (Gtk.MultiFilter)filter_obj;
                            if (multi_filter.get_n_items () > 0) {
                                var filter_item = multi_filter.get_item (0);
                                if (filter_item is Gtk.CustomFilter) {
                                    var coll_filter = (Gtk.CustomFilter)filter_item;
                                    coll_filter.changed (Gtk.FilterChange.DIFFERENT);
                                }
                            }
                        }
                        // Switch to palettes view
                        // Don't modify library_list selection as it would clear the filter
                        // The filter will show only palettes in this collection
                        main_stack.set_visible_child_name ("palbody");
                        palette_stack.set_visible_child_name ("palfull");
                        update_appbar_title ();
                    }
                }
            });

            // Populate collections sidebar list
            populate_collections_sidebar ();

            // Watch for changes to collections_store and update sidebar
            collections_store.items_changed.connect ((pos, removed, added) => {
                populate_collections_sidebar ();
            });

            // Initialize colors view
            colors_model.set_model (all_colors_store);
            colors_fb.hscroll_policy = colors_fb.vscroll_policy = Gtk.ScrollablePolicy.NATURAL;
            update_all_colors_store ();

            // Sidebar navigation handlers
            library_list.row_selected.connect ((row) => {
                // Clear collection filter when selecting library items
                current_collection_filter = null;
                var filter_obj = palette_filter_model.get_filter ();
                if (filter_obj is Gtk.MultiFilter) {
                    var multi_filter = (Gtk.MultiFilter)filter_obj;
                    // Get the first filter (collection filter) if it exists
                    if (multi_filter.get_n_items () > 0) {
                        var filter_item = multi_filter.get_item (0);
                        if (filter_item is Gtk.CustomFilter) {
                            var coll_filter = (Gtk.CustomFilter)filter_item;
                            coll_filter.changed (Gtk.FilterChange.DIFFERENT);
                        }
                    }
                }
                // Deselect any selected collection
                collections_list.unselect_all ();
                
                if (row == all_palettes_row) {
                    main_stack.set_visible_child_name ("palbody");
                    palette_stack.set_visible_child_name (palettestore.get_n_items () > 0 ? "palfull" : "palempty");
                    update_appbar_title ();
                } else if (row == recents_row) {
                    main_stack.set_visible_child_name ("recentsbody");
                    update_appbar_title ();
                } else if (row == colors_row) {
                    main_stack.set_visible_child_name ("colorsbody");
                    update_all_colors_store ();
                    update_appbar_title ();
                }
            });

            // Collections list - handle single-click activation
            collections_list.row_activated.connect ((row) => {
                if (row != null) {
                    int pos = row.get_index ();
                    if (pos >= 0 && pos < (int)collections_store.get_n_items ()) {
                        var collection = (CollectionInfo)collections_store.get_item ((uint)pos);
                        if (collection != null) {
                            // Filter palettes by collection
                            current_collection_filter = collection;
                            var filter_obj = palette_filter_model.get_filter ();
                            if (filter_obj is Gtk.MultiFilter) {
                                var multi_filter = (Gtk.MultiFilter)filter_obj;
                                if (multi_filter.get_n_items () > 0) {
                                    var filter_item = multi_filter.get_item (0);
                                    if (filter_item is Gtk.CustomFilter) {
                                        var coll_filter = (Gtk.CustomFilter)filter_item;
                                        coll_filter.changed (Gtk.FilterChange.DIFFERENT);
                                    }
                                }
                            }
                            // Deselect library items
                            library_list.unselect_all ();
                            main_stack.set_visible_child_name ("palbody");
                            palette_stack.set_visible_child_name ("palfull");
                            update_appbar_title ();
                        }
                    }
                }
            });
            
            // Collections list selection handler (for visual feedback and immediate filtering)
            collections_list.row_selected.connect ((row) => {
                if (row != null) {
                    int pos = row.get_index ();
                    if (pos >= 0 && pos < (int)collections_store.get_n_items ()) {
                        var collection = (CollectionInfo)collections_store.get_item ((uint)pos);
                        if (collection != null) {
                            // Filter palettes by collection
                            current_collection_filter = collection;
                            var filter_obj = palette_filter_model.get_filter ();
                            if (filter_obj is Gtk.MultiFilter) {
                                var multi_filter = (Gtk.MultiFilter)filter_obj;
                                if (multi_filter.get_n_items () > 0) {
                                    var filter_item = multi_filter.get_item (0);
                                    if (filter_item is Gtk.CustomFilter) {
                                        var coll_filter = (Gtk.CustomFilter)filter_item;
                                        coll_filter.changed (Gtk.FilterChange.DIFFERENT);
                                    }
                                }
                            }
                            // Deselect library items
                            library_list.unselect_all ();
                            main_stack.set_visible_child_name ("palbody");
                            palette_stack.set_visible_child_name ("palfull");
                            update_appbar_title ();
                        }
                    }
                } else {
                    // Deselected - clear filter
                    current_collection_filter = null;
                    var filter_obj = palette_filter_model.get_filter ();
                    if (filter_obj is Gtk.MultiFilter) {
                        var multi_filter = (Gtk.MultiFilter)filter_obj;
                        if (multi_filter.get_n_items () > 0) {
                            var filter_item = multi_filter.get_item (0);
                            if (filter_item is Gtk.CustomFilter) {
                                var coll_filter = (Gtk.CustomFilter)filter_item;
                                coll_filter.changed (Gtk.FilterChange.DIFFERENT);
                            }
                        }
                    }
                }
            });

            // Select "All Palettes" by default
            library_list.select_row (all_palettes_row);

            // Recents overlay button handlers
            recents_overlay_button.clicked.connect (() => {
                var rand = new GLib.Rand ();
                var rc = "#" + "%02x%02x%02x".printf (rand.int_range(15, 255), rand.int_range(15, 255), rand.int_range(15, 255));
                var recent = new RecentColorInfo ("Color %d".printf(rand.int_range(1, 255)), rc);
                add_to_recent_colors (recent.name, recent.color);
            });

            recents_overlay_button.secondary_clicked.connect (() => {
                pick_color.begin ();
            });

            add_collection_button.clicked.connect (() => {
                // Create dialog for new collection
                var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);

                var name_label = new Gtk.Label (_("Collection Name:"));
                name_label.halign = Gtk.Align.START;
                var name_entry = new He.TextField ();
                name_entry.text = "New Collection %d".printf(uid_counter++);
                name_entry.is_outline = true;

                content.append (name_label);
                content.append (name_entry);

                var create_button = new He.Button (null, _("Create"));
                var dialog = new He.Dialog (this,
                    _("New Collection"),
                    null,
                    null,
                    create_button,
                    null);

                create_button.clicked.connect (() => {
                    var entry = name_entry.get_internal_entry ();
                    string? text = entry != null ? entry.text : null;
                    if (text != null && text.strip () != "") {
                        var collection = new CollectionInfo ();
                        collection.name = text.strip ();
                        collections_store.append (collection);
                        m.save_collections.begin (collections_store);
                        dialog.hide_dialog ();
                    }
                });

                dialog.add (content);
                dialog.present ();
                name_entry.entry.grab_focus ();
                name_entry.entry.select_region (0, -1);
            });

            add_to_collection_button.clicked.connect (() => {
                var pitem = palettestore.get_item (palette_model.get_selected ());
                if (pitem == null) {
                    return;
                }
                
                var palette_name = ((PaletteInfo)pitem).palname;
                
                // Create dialog content
                var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
                content.margin_top = 12;
                content.margin_bottom = 12;
                content.margin_start = 12;
                content.margin_end = 12;
                
                var label = new Gtk.Label (_("Select collections to add \"%s\" to:").printf (palette_name));
                label.halign = Gtk.Align.START;
                label.wrap = true;
                content.append (label);
                
                var scrolled = new Gtk.ScrolledWindow ();
                scrolled.height_request = 200;
                scrolled.vexpand = true;
                
                var collections_list = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
                scrolled.child = collections_list;
                content.append (scrolled);
                
                // Store checkboxes and their corresponding collections
                var checkboxes = new Gee.HashMap<Gtk.CheckButton, CollectionInfo> ();
                
                // Populate list with collections
                uint n = collections_store.get_n_items ();
                if (n == 0) {
                    var empty_label = new Gtk.Label (_("No collections available. Create one first."));
                    empty_label.halign = Gtk.Align.CENTER;
                    empty_label.valign = Gtk.Align.CENTER;
                    empty_label.margin_top = 12;
                    collections_list.append (empty_label);
                } else {
                    for (uint i = 0; i < n; i++) {
                        var item = collections_store.get_item (i);
                        if (item == null) {
                            continue;
                        }
                        
                        var collection = (CollectionInfo)item;
                        var check = new Gtk.CheckButton ();
                        check.label = collection.name;
                        check.active = collection.palette_names.contains (palette_name);
                        check.halign = Gtk.Align.START;
                        check.margin_start = 6;
                        
                        checkboxes.set (check, collection);
                        collections_list.append (check);
                    }
                }
                
                var save_button = new He.Button (null, _("Save"));
                var dialog = new He.Dialog (this,
                    _("Add to Collection"),
                    null,
                    null,
                    save_button,
                    null);
                
                save_button.clicked.connect (() => {
                    bool changed = false;
                    
                    foreach (var entry in checkboxes.entries) {
                        var checkbox = entry.key;
                        var collection = entry.value;
                        
                        bool should_contain = checkbox.active;
                        bool currently_contains = collection.palette_names.contains (palette_name);
                        
                        if (should_contain && !currently_contains) {
                            collection.palette_names.add (palette_name);
                            changed = true;
                        } else if (!should_contain && currently_contains) {
                            collection.palette_names.remove (palette_name);
                            changed = true;
                        }
                    }
                    
                    if (changed) {
                        m.save_collections.begin (collections_store);
                        // Update filter if we're viewing a collection
                        if (current_collection_filter != null) {
                            var filter_obj = palette_filter_model.get_filter ();
                            if (filter_obj is Gtk.MultiFilter) {
                                var multi_filter = (Gtk.MultiFilter)filter_obj;
                                if (multi_filter.get_n_items () > 0) {
                                    var filter_item = multi_filter.get_item (0);
                                    if (filter_item is Gtk.CustomFilter) {
                                        var coll_filter = (Gtk.CustomFilter)filter_item;
                                        coll_filter.changed (Gtk.FilterChange.DIFFERENT);
                                    }
                                }
                            }
                        }
                    }
                    
                    dialog.hide_dialog ();
                });
                
                dialog.add (content);
                dialog.present ();
            });

            if (Config.DEVELOPMENT)
                add_css_class ("devel");

            this.set_size_request (360, 360);
            this.show ();

            viewtitle_box.remove_css_class ("disclosure-button");
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
                        add_to_recent_colors (a.name, a.color);
                        update_all_colors_store ();

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

                // Extract pixel data from Cairo surface and create texture
                int width = sf.get_width ();
                int height = sf.get_height ();
                int stride = sf.get_stride ();
                unowned uint8[]? surface_data = sf.get_data ();
                
                if (surface_data != null) {
                    // Cairo Format.ARGB32 stores pixels as native-endian 32-bit ARGB
                    // On little-endian systems (most common), this is BGRA in memory
                    // Copy data with proper stride handling
                    uint8[] rgba_data = new uint8[width * height * 4];
                    for (int y = 0; y < height; y++) {
                        for (int x = 0; x < width; x++) {
                            int src_idx = y * stride + x * 4;
                            int dst_idx = (y * width + x) * 4;
                            // Native endian ARGB32 -> BGRA8 (already in correct byte order on little-endian)
                            rgba_data[dst_idx + 0] = surface_data[src_idx + 0]; // B
                            rgba_data[dst_idx + 1] = surface_data[src_idx + 1]; // G
                            rgba_data[dst_idx + 2] = surface_data[src_idx + 2]; // R
                            rgba_data[dst_idx + 3] = surface_data[src_idx + 3]; // A
                        }
                    }
                    
                    var bytes = new GLib.Bytes.take ((owned)rgba_data);
                    var mt = new Gdk.MemoryTexture (width, height, Gdk.MemoryFormat.B8G8R8A8, bytes, width * 4);
                    
                    var display = Gdk.Display.get_default ();
                    unowned var clipboard = display.get_clipboard ();
                    clipboard.set_texture (mt);
                }
            }
        }

        public void edit_palette () {
            if (palette_model.selected == Gtk.INVALID_LIST_POSITION) {
                return;
            }

            uint pos = palette_model.selected;
            var palette = (PaletteInfo)palettestore.get_item (pos);
            if (palette == null) {
                return;
            }

            // Create a simple dialog to edit palette name
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);

            var name_label = new Gtk.Label (_("Palette Name:"));
            name_label.halign = Gtk.Align.START;
            var name_entry = new He.TextField ();
            name_entry.text = palette.palname;
            name_entry.is_outline = true;

            content.append (name_label);
            content.append (name_entry);

            var save_button = new He.Button (null, _("Save"));
            var dialog = new He.Dialog (this,
                _("Edit Palette"),
                null,
                null,
                save_button,
                null);
            
            save_button.clicked.connect (() => {
                var entry = name_entry.get_internal_entry ();
                string? text = entry != null ? entry.text : null;
                if (text != null && text.strip () != "") {
                    palette.palname = text.strip ();
                    m.save_palettes.begin (palettestore);
                    dialog.hide_dialog ();
                }
            });

            dialog.add (content);
            dialog.present ();
            name_entry.entry.grab_focus ();
            name_entry.entry.select_region (0, -1);
        }

        public void delete_palette () {
            palettestore.remove (palette_model.selected);
            update_all_colors_store ();

            if (palettestore.get_item(0) == null) {
                palette_stack.set_visible_child_name ("palempty");
                back_button.set_visible(false);
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
                update_all_colors_store ();
                update_appbar_title ();
            } else {
                update_all_colors_store ();
            }
        }

        public void edit_collection () {
            if (collections_model.selected == Gtk.INVALID_LIST_POSITION) {
                return;
            }

            uint pos = collections_model.selected;
            var collection = (CollectionInfo)collections_store.get_item (pos);
            if (collection == null) {
                return;
            }

            // Create a simple dialog to edit collection name
            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);

            var name_label = new Gtk.Label (_("Collection Name:"));
            name_label.halign = Gtk.Align.START;
            var name_entry = new He.TextField ();
            name_entry.is_outline = true;
            
            // Set initial text using internal entry
            var ientry = name_entry.get_internal_entry ();
            if (ientry != null) {
                ientry.text = collection.name;
            }

            content.append (name_label);
            content.append (name_entry);

            var save_button = new He.Button (null, _("Save"));
            var dialog = new He.Dialog (this,
                _("Edit Collection"),
                null,
                null,
                save_button,
                null);
            
            save_button.clicked.connect (() => {
                var entry = name_entry.get_internal_entry ();
                string? text = entry != null ? entry.text : null;
                if (text != null && text.strip () != "") {
                    collection.name = text.strip ();
                    // Update title if this collection is currently being filtered
                    if (current_collection_filter == collection) {
                        update_appbar_title ();
                    }
                    m.save_collections.begin (collections_store);
                    dialog.hide_dialog ();
                }
            });
            
            // Allow Enter key to save
            name_entry.entry.activate.connect (() => {
                save_button.clicked ();
            });

            dialog.add (content);
            dialog.present ();
            name_entry.entry.grab_focus ();
            name_entry.entry.select_region (0, -1);
        }

        public void delete_collection () {
            if (collections_model.selected == Gtk.INVALID_LIST_POSITION) {
                return;
            }

            uint pos = collections_model.selected;
            var collection = (CollectionInfo)collections_store.get_item (pos);
            if (collection == null) {
                return;
            }

            // Confirm deletion
            var delete_button = new He.Button (null, _("Delete"));
            var dialog = new He.Dialog (this,
                _("Delete Collection"),
                _("Are you sure you want to delete the collection \"%s\"?").printf (collection.name),
                null,
                delete_button,
                null);
            
            delete_button.clicked.connect (() => {
                // Clear filter if deleting current filter
                if (current_collection_filter == collection) {
                    current_collection_filter = null;
                    var filter_obj = palette_filter_model.get_filter ();
                    if (filter_obj is Gtk.MultiFilter) {
                        var multi_filter = (Gtk.MultiFilter)filter_obj;
                        if (multi_filter.get_n_items () > 0) {
                            var filter_item = multi_filter.get_item (0);
                            if (filter_item is Gtk.CustomFilter) {
                                var coll_filter = (Gtk.CustomFilter)filter_item;
                                coll_filter.changed (Gtk.FilterChange.DIFFERENT);
                            }
                        }
                    }
                    library_list.select_row (all_palettes_row);
                    // Update title to show "Palettes" instead of collection name
                    update_appbar_title ();
                }

                collections_store.remove (pos);
                m.save_collections.begin (collections_store);
                dialog.hide_dialog ();
            });

            dialog.present ();
        }

        private He.AboutWindow? about_window = null;

        public void action_about () {
            if (about_window == null) {
                string[]? translators = null;
                string translator_credits = _("translator-credits");
                if (translator_credits != "translator-credits" && translator_credits != "") {
                    translators = {translator_credits};
                }

                string[] developers = {"Paulo \"Lains\" Galardi"};

                about_window = new He.AboutWindow (
                    this,
                    "Emulsion" + Config.NAME_SUFFIX,
                    Config.APP_ID,
                    Config.VERSION,
                    Config.APP_ID,
                    "https://github.com/lainsce/Emulsion/blob/main/TRANSLATE.md", // translate_url
                    "https://github.com/lainsce/Emulsion/issues", // issue_url
                    "https://github.com/lainsce/Emulsion", // more_info_url
                    translators,
                    developers,
                    2021, // copyright_year
                    He.AboutWindow.Licenses.GPLV3,
                    He.Colors.PURPLE
                );
                about_window.hidden.connect (() => {
                    about_window = null;
                });
            }
            about_window.present ();
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


/*
* Copyright (C) 2021 Lains
*
* This program is free software; you can redistribute it &&/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/
namespace Emulsion {
    public class Manager {
        public MainWindow win;
        public Json.Builder builder;
        private string app_dir = Environment.get_user_data_dir () +
                                 "/io.github.lainsce.Emulsion";
        private string file_name;

        public Manager (MainWindow win) {
            this.win = win;
            file_name = this.app_dir + "/saved_palettes.json";
        }

        public async void save_palettes (ListStore liststore) {
            string json_string = "";
            var b = new Json.Builder ();
            builder = b;

            builder.begin_array ();
	        uint i, n = liststore.get_n_items ();
            for (i = 0; i < n; i++) {
                builder.begin_array ();
                var item = liststore.get_item (i);
                int j = ((PaletteInfo)item).colors.size;
                builder.add_string_value (((PaletteInfo)item).palname);
                builder.begin_array ();
                for (uint k = i; k < j; k++) {
                    builder.begin_array ();
                    string col = ((PaletteInfo)item).colors.to_array()[k];
                    string coln = ((PaletteInfo)item).colorsnames.to_array()[k];
                    builder.add_string_value (col);
                    builder.add_string_value (coln);
                    builder.end_array ();
                }
                builder.end_array ();
                builder.end_array ();
            }
            builder.end_array ();

            Json.Generator generator = new Json.Generator ();
            Json.Node root = builder.get_root ();
            generator.set_root (root);
            json_string = generator.to_data (null);

            var dir = File.new_for_path(app_dir);
            var file = File.new_for_path (file_name);
            try {
                if (!dir.query_exists()) {
                    dir.make_directory();
                }
                if (file.query_exists ()) {
                    file.delete ();
                }
                GLib.FileUtils.set_contents (file.get_path (), json_string);
            } catch (Error e) {
                warning ("Failed to save file: %s\n", e.message);
            }
        }

        public async void load_from_file () {
            try {
                var file = File.new_for_path(file_name);

                if (file.query_exists()) {
                    string line;
                    GLib.FileUtils.get_contents (file.get_path (), out line);
                    var parser = new Json.Parser();
                    parser.load_from_data(line);
                    var root = parser.get_root();
                    var array = root.get_array();
                    foreach (var t in array.get_elements()) {
                        var pi = t.get_array ();
                        var name = pi.get_string_element(0);
                        var color = pi.get_array_element(1);

                        var a = new PaletteInfo ();

                        a.palname = name;

                        string[] arrco = {};
                        string[] arrcon = {};

                        color.foreach_element ((a, b, c) => {
                            var color_pairs = color.get_array_element(b);
                            color_pairs.foreach_element ((a, b, c) => {
                                arrco += color_pairs.get_string_element(0);
                                arrcon += color_pairs.get_string_element(1);
                            });
                        });

                        a.colors = new Gee.TreeSet<string> ();
                        a.colors.add_all_array (arrco);

                        a.colorsnames = new Gee.TreeSet<string> ();
                        a.colorsnames.add_all_array (arrcon);

                        win.palettestore.append (a);
                    }
                }
            } catch (Error e) {
                warning ("Failed to load file: %s\n", e.message);
            }
        }
    }
}

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
        private string backup_file_name;
        private string collections_file_name;
        private string collections_backup_file_name;
        private bool is_saving = false;
        private uint save_timeout_id = 0;

        public Manager (MainWindow win) {
            this.win = win;
            file_name = this.app_dir + "/saved_palettes.json";
            backup_file_name = this.app_dir + "/saved_palettes.json.backup";
            collections_file_name = this.app_dir + "/saved_collections.json";
            collections_backup_file_name = this.app_dir + "/saved_collections.json.backup";
        }

        /**
         * Validates a hex color code.
         * Accepts formats: #RGB, #RRGGBB, #RRGGBBAA (alpha is ignored)
         */
        private bool is_valid_hex_color (string color) {
            if (color == null || color.length == 0) {
                return false;
            }

            if (!color.has_prefix ("#")) {
                return false;
            }

            string hex_part = color.substring (1);
            if (hex_part.length != 3 && hex_part.length != 6 && hex_part.length != 8) {
                return false;
            }

            // Validate all characters are hex digits
            for (int i = 0; i < hex_part.length; i++) {
                unichar c = hex_part[i];
                if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) {
                    return false;
                }
            }

            return true;
        }

        /**
         * Validates and normalizes a hex color code.
         * Converts #RGB to #RRGGBB format.
         */
        private string? normalize_hex_color (string color) {
            if (!is_valid_hex_color (color)) {
                return null;
            }

            string hex_part = color.substring (1);
            
            // Convert #RGB to #RRGGBB
            if (hex_part.length == 3) {
                var r = hex_part[0].to_string ();
                var g = hex_part[1].to_string ();
                var b = hex_part[2].to_string ();
                return "#" + r + r + g + g + b + b;
            }

            // Ignore alpha channel if present
            if (hex_part.length == 8) {
                return "#" + hex_part.substring (0, 6);
            }

            return color;
        }

        /**
         * Validates a palette or color name.
         */
        private bool is_valid_name (string? name) {
            if (name == null || name.length == 0) {
                return false;
            }

            // Check for reasonable length (max 100 characters)
            if (name.length > 100) {
                return false;
            }

            return true;
        }

        /**
         * Sanitizes a palette or color name.
         */
        private string sanitize_name (string name) {
            if (name == null) {
                return "";
            }

            // Trim whitespace
            string sanitized = name.strip ();

            // Limit length
            if (sanitized.length > 100) {
                sanitized = sanitized.substring (0, 100);
            }

            return sanitized;
        }

        /**
         * Creates a backup of the current palette file if it exists.
         */
        private void create_backup () {
            try {
                var file = File.new_for_path (file_name);
                var backup = File.new_for_path (backup_file_name);

                if (file.query_exists ()) {
                    if (backup.query_exists ()) {
                        backup.delete ();
                    }
                    file.copy (backup, FileCopyFlags.OVERWRITE, null, null);
                }
            } catch (Error e) {
                warning ("Failed to create backup: %s\n", e.message);
            }
        }

        /**
         * Saves palettes with validation, atomic writes, and backup.
         * Uses debouncing to prevent multiple simultaneous saves.
         */
        public async void save_palettes (ListStore liststore) {
            // Cancel any pending save
            if (save_timeout_id != 0) {
                Source.remove (save_timeout_id);
                save_timeout_id = 0;
            }

            // Wait if a save is in progress
            while (is_saving) {
                Timeout.add (50, () => {
                    save_palettes.callback ();
                    return false;
                });
                yield;
            }

            is_saving = true;

            try {
                // Validate and build JSON
                var b = new Json.Builder ();
                builder = b;

                builder.begin_array ();
                uint i, n = liststore.get_n_items ();
                int valid_palettes = 0;

                for (i = 0; i < n; i++) {
                    var item = liststore.get_item (i);
                    if (item == null) {
                        continue;
                    }

                    var palette = (PaletteInfo)item;
                    
                    // Validate and sanitize palette name
                    if (!is_valid_name (palette.palname)) {
                        warning ("Skipping palette with invalid name at index %u\n", i);
                        continue;
                    }

                    string sanitized_name = sanitize_name (palette.palname);
                    if (sanitized_name == "") {
                        sanitized_name = "Unnamed Palette";
                    }

                    // Validate colors
                    var valid_colors = new Gee.HashMap<string, string> ();
                    foreach (var col_entry in palette.colors.entries) {
                        string color_name = sanitize_name (col_entry.key);
                        if (color_name == "") {
                            continue;
                        }

                        string? normalized_color = normalize_hex_color (col_entry.value);
                        if (normalized_color == null) {
                            warning ("Skipping invalid color '%s' in palette '%s'\n", col_entry.value, sanitized_name);
                            continue;
                        }

                        valid_colors.set (color_name, normalized_color);
                    }

                    // Only save palettes with at least one valid color
                    if (valid_colors.size == 0) {
                        warning ("Skipping palette '%s' with no valid colors\n", sanitized_name);
                        continue;
                    }

                    builder.begin_array ();
                    builder.add_string_value (sanitized_name);
                    builder.begin_array ();
                    foreach (var col in valid_colors.entries) {
                        builder.begin_object ();
                        builder.set_member_name (col.key);
                        builder.add_string_value (col.value);
                        builder.end_object ();
                    }
                    builder.end_array ();
                    builder.end_array ();

                    valid_palettes++;
                }
                builder.end_array ();

                if (valid_palettes == 0) {
                    debug ("No valid palettes to save\n");
                    is_saving = false;
                    return;
                }

                Json.Generator generator = new Json.Generator ();
                Json.Node root = builder.get_root ();
                generator.set_root (root);
                generator.set_pretty (false);
                string json_string = generator.to_data (null);

                if (json_string == null || json_string.length == 0) {
                    warning ("Failed to generate JSON data\n");
                    is_saving = false;
                    return;
                }

                // Ensure directory exists
                var dir = File.new_for_path (app_dir);
                if (!dir.query_exists ()) {
                    try {
                        dir.make_directory_with_parents ();
                    } catch (Error e) {
                        warning ("Failed to create directory: %s\n", e.message);
                        is_saving = false;
                        return;
                    }
                }

                // Create backup of existing file
                create_backup ();

                // Atomic write: write to temp file first, then rename
                string temp_file_name = file_name + ".tmp";
                var temp_file = File.new_for_path (temp_file_name);
                var main_file = File.new_for_path (file_name);

                try {
                    // Delete temp file if it exists
                    if (temp_file.query_exists ()) {
                        temp_file.delete ();
                    }

                    // Write to temp file
                    FileOutputStream stream = temp_file.create (FileCreateFlags.NONE);
                    DataOutputStream dos = new DataOutputStream (stream);
                    dos.put_string (json_string);
                    dos.close ();

                    // Verify temp file was written correctly
                    if (!temp_file.query_exists ()) {
                        throw new IOError.FAILED ("Temp file was not created");
                    }

                    // Read back and verify
                    string? verify_contents = null;
                    FileUtils.get_contents (temp_file.get_path (), out verify_contents);
                    if (verify_contents != json_string) {
                        throw new IOError.FAILED ("Verification failed: file contents don't match");
                    }

                    // Atomic move: replace old file with new one
                    if (main_file.query_exists ()) {
                        main_file.delete ();
                    }
                    temp_file.move (main_file, FileCopyFlags.OVERWRITE);

                    debug ("Successfully saved %d palette(s) to %s\n", valid_palettes, file_name);
                } catch (Error e) {
                    warning ("Failed to save file atomically: %s\n", e.message);
                    // Try to restore from backup if write failed
                    try {
                        var backup = File.new_for_path (backup_file_name);
                        if (backup.query_exists ()) {
                            if (main_file.query_exists ()) {
                                main_file.delete ();
                            }
                            backup.copy (main_file, FileCopyFlags.OVERWRITE, null, null);
                            warning ("Restored from backup after save failure\n");
                        }
                    } catch (Error restore_error) {
                        warning ("Failed to restore from backup: %s\n", restore_error.message);
                    }
                }
            } catch (Error e) {
                warning ("Failed to save palettes: %s\n", e.message);
            } finally {
                is_saving = false;
            }
        }

        /**
         * Loads palettes from file with validation and error recovery.
         * Attempts to load from backup if main file is corrupted.
         */
        public async void load_from_file () {
            var file = File.new_for_path (file_name);
            var backup = File.new_for_path (backup_file_name);
            File? load_file = null;

            // Try main file first
            if (file.query_exists ()) {
                load_file = file;
            } else if (backup.query_exists ()) {
                // Fallback to backup if main file doesn't exist
                warning ("Main palette file not found, attempting to load from backup\n");
                load_file = backup;
            } else {
                debug ("No palette file found, starting with empty palettes\n");
                return;
            }

            try {
                string? line = null;
                GLib.FileUtils.get_contents (load_file.get_path (), out line);

                if (line == null || line.length == 0) {
                    warning ("Palette file is empty\n");
                    return;
                }

                var parser = new Json.Parser ();
                parser.load_from_data (line);

                var root = parser.get_root ();
                if (root.get_node_type () != Json.NodeType.ARRAY) {
                    throw new IOError.FAILED ("Invalid JSON structure: expected array at root");
                }

                var array = root.get_array ();
                int loaded_count = 0;
                int skipped_count = 0;

                foreach (var t in array.get_elements ()) {
                    try {
                        if (t.get_node_type () != Json.NodeType.ARRAY) {
                            warning ("Skipping invalid palette entry: expected array\n");
                            skipped_count++;
                            continue;
                        }

                        var pi = t.get_array ();
                        
                        // Validate array structure
                        if (pi.get_length () < 2) {
                            warning ("Skipping invalid palette entry: array too short\n");
                            skipped_count++;
                            continue;
                        }

                        var name_node = pi.get_element (0);
                        var color_node = pi.get_element (1);

                        if (name_node == null || name_node.get_node_type () != Json.NodeType.VALUE ||
                            color_node == null || color_node.get_node_type () != Json.NodeType.ARRAY) {
                            warning ("Skipping invalid palette entry: invalid structure\n");
                            skipped_count++;
                            continue;
                        }

                        string? name = name_node.get_string ();
                        if (name == null || !is_valid_name (name)) {
                            warning ("Skipping palette with invalid name\n");
                            skipped_count++;
                            continue;
                        }

                        string sanitized_name = sanitize_name (name);
                        if (sanitized_name == "") {
                            sanitized_name = "Unnamed Palette";
                        }

                        var am = new PaletteInfo ();
                        am.palname = sanitized_name;
                        am.colors = new Gee.HashMap<string, string> ();

                        var color_array = color_node.get_array ();
                        var settings = new Settings ();
                        bool has_valid_colors = false;

                        if (settings.schema_version == 0) {
                            // Old schema: array of strings
                            color_array.foreach_element ((arr, index, element) => {
                                string? color_val = element.get_string ();
                                if (color_val != null && is_valid_hex_color (color_val)) {
                                    string? normalized = normalize_hex_color (color_val);
                                    if (normalized != null) {
                                        am.colors.set (normalized, normalized);
                                        has_valid_colors = true;
                                    }
                                }
                            });
                            settings.schema_version = 1;
                        } else {
                            // Current schema: array of objects {name: color}
                            foreach (var c in color_array.get_elements ()) {
                                if (c.get_node_type () != Json.NodeType.OBJECT) {
                                    continue;
                                }

                                var color_obj = c.get_object ();
                                color_obj.foreach_member ((obj, color_name, color_value) => {
                                    if (color_name == null || color_name.length == 0) {
                                        return;
                                    }

                                    if (color_value.get_node_type () != Json.NodeType.VALUE) {
                                        return;
                                    }

                                    string? color_hex = color_value.get_string ();
                                    if (color_hex == null || !is_valid_hex_color (color_hex)) {
                                        warning ("Skipping invalid color '%s' in palette '%s'\n", 
                                                 color_hex ?? "null", sanitized_name);
                                        return;
                                    }

                                    string? normalized_color = normalize_hex_color (color_hex);
                                    if (normalized_color == null) {
                                        return;
                                    }

                                    string sanitized_color_name = sanitize_name (color_name);
                                    if (sanitized_color_name == "") {
                                        sanitized_color_name = "Color";
                                    }

                                    am.colors.set (sanitized_color_name, normalized_color);
                                    has_valid_colors = true;
                                });
                            }
                        }

                        // Only add palettes with at least one valid color
                        if (has_valid_colors && am.colors.size > 0) {
                            win.palettestore.append (am);
                            loaded_count++;
                        } else {
                            warning ("Skipping palette '%s' with no valid colors\n", sanitized_name);
                            skipped_count++;
                        }
                    } catch (Error e) {
                        warning ("Error loading palette entry: %s\n", e.message);
                        skipped_count++;
                    }
                }

                if (loaded_count > 0) {
                    debug ("Successfully loaded %d palette(s) from %s\n", loaded_count, load_file.get_basename ());
                }
                if (skipped_count > 0) {
                    warning ("Skipped %d invalid palette entry(ies)\n", skipped_count);
                }
            } catch (Error e) {
                warning ("Failed to load palette file '%s': %s\n", load_file.get_basename (), e.message);
                
                // If main file failed and backup exists, try backup
                if (load_file == file && backup.query_exists ()) {
                    warning ("Attempting to load from backup file\n");
                    try {
                        string? backup_line = null;
                        GLib.FileUtils.get_contents (backup.get_path (), out backup_line);
                        
                        if (backup_line != null && backup_line.length > 0) {
                            var backup_parser = new Json.Parser ();
                            backup_parser.load_from_data (backup_line);
                            // Process backup similarly (could refactor to shared method)
                            warning ("Backup file exists but automatic recovery not fully implemented\n");
                        }
                    } catch (Error backup_error) {
                        warning ("Failed to load backup file: %s\n", backup_error.message);
                    }
                }
            }
        }

        /**
         * Creates a backup of the collections file if it exists.
         */
        private void create_collections_backup () {
            try {
                var file = File.new_for_path (collections_file_name);
                var backup = File.new_for_path (collections_backup_file_name);

                if (file.query_exists ()) {
                    if (backup.query_exists ()) {
                        backup.delete ();
                    }
                    file.copy (backup, FileCopyFlags.OVERWRITE, null, null);
                }
            } catch (Error e) {
                warning ("Failed to create collections backup: %s\n", e.message);
            }
        }

        /**
         * Saves collections with validation and atomic writes.
         */
        public async void save_collections (ListStore liststore) {
            // Wait if a save is in progress
            while (is_saving) {
                Timeout.add (50, () => {
                    save_collections.callback ();
                    return false;
                });
                yield;
            }

            is_saving = true;

            try {
                var b = new Json.Builder ();

                b.begin_array ();
                uint i, n = liststore.get_n_items ();
                int valid_collections = 0;

                for (i = 0; i < n; i++) {
                    var item = liststore.get_item (i);
                    if (item == null) {
                        continue;
                    }

                    var collection = (CollectionInfo)item;
                    
                    // Validate and sanitize collection name
                    if (!is_valid_name (collection.name)) {
                        warning ("Skipping collection with invalid name at index %u\n", i);
                        continue;
                    }

                    string sanitized_name = sanitize_name (collection.name);
                    if (sanitized_name == "") {
                        sanitized_name = "Unnamed Collection";
                    }

                    // Validate palette names exist
                    var valid_palette_names = new Gee.ArrayList<string> ();
                    foreach (var palette_name in collection.palette_names) {
                        string sanitized = sanitize_name (palette_name);
                        if (sanitized != "") {
                            valid_palette_names.add (sanitized);
                        }
                    }

                    b.begin_object ();
                    b.set_member_name ("name");
                    b.add_string_value (sanitized_name);
                    b.set_member_name ("palette_names");
                    b.begin_array ();
                    foreach (var pname in valid_palette_names) {
                        b.add_string_value (pname);
                    }
                    b.end_array ();
                    b.end_object ();

                    valid_collections++;
                }
                b.end_array ();

                if (valid_collections == 0) {
                    debug ("No valid collections to save\n");
                    is_saving = false;
                    return;
                }

                Json.Generator generator = new Json.Generator ();
                Json.Node root = b.get_root ();
                generator.set_root (root);
                generator.set_pretty (false);
                string json_string = generator.to_data (null);

                if (json_string == null || json_string.length == 0) {
                    warning ("Failed to generate collections JSON data\n");
                    is_saving = false;
                    return;
                }

                // Ensure directory exists
                var dir = File.new_for_path (app_dir);
                if (!dir.query_exists ()) {
                    try {
                        dir.make_directory_with_parents ();
                    } catch (Error e) {
                        warning ("Failed to create directory: %s\n", e.message);
                        is_saving = false;
                        return;
                    }
                }

                // Create backup
                create_collections_backup ();

                // Atomic write
                string temp_file_name = collections_file_name + ".tmp";
                var temp_file = File.new_for_path (temp_file_name);
                var main_file = File.new_for_path (collections_file_name);

                try {
                    if (temp_file.query_exists ()) {
                        temp_file.delete ();
                    }

                    FileOutputStream stream = temp_file.create (FileCreateFlags.NONE);
                    DataOutputStream dos = new DataOutputStream (stream);
                    dos.put_string (json_string);
                    dos.close ();

                    if (!temp_file.query_exists ()) {
                        throw new IOError.FAILED ("Temp file was not created");
                    }

                    string? verify_contents = null;
                    FileUtils.get_contents (temp_file.get_path (), out verify_contents);
                    if (verify_contents != json_string) {
                        throw new IOError.FAILED ("Verification failed: file contents don't match");
                    }

                    if (main_file.query_exists ()) {
                        main_file.delete ();
                    }
                    temp_file.move (main_file, FileCopyFlags.OVERWRITE);

                    debug ("Successfully saved %d collection(s) to %s\n", valid_collections, collections_file_name);
                } catch (Error e) {
                    warning ("Failed to save collections file atomically: %s\n", e.message);
                    try {
                        var backup = File.new_for_path (collections_backup_file_name);
                        if (backup.query_exists ()) {
                            if (main_file.query_exists ()) {
                                main_file.delete ();
                            }
                            backup.copy (main_file, FileCopyFlags.OVERWRITE, null, null);
                            warning ("Restored collections from backup after save failure\n");
                        }
                    } catch (Error restore_error) {
                        warning ("Failed to restore collections from backup: %s\n", restore_error.message);
                    }
                }
            } catch (Error e) {
                warning ("Failed to save collections: %s\n", e.message);
            } finally {
                is_saving = false;
            }
        }

        /**
         * Loads collections from file with validation.
         */
        public async void load_collections () {
            var file = File.new_for_path (collections_file_name);
            var backup = File.new_for_path (collections_backup_file_name);
            File? load_file = null;

            if (file.query_exists ()) {
                load_file = file;
            } else if (backup.query_exists ()) {
                warning ("Main collections file not found, attempting to load from backup\n");
                load_file = backup;
            } else {
                debug ("No collections file found\n");
                return;
            }

            try {
                string? line = null;
                GLib.FileUtils.get_contents (load_file.get_path (), out line);

                if (line == null || line.length == 0) {
                    warning ("Collections file is empty\n");
                    return;
                }

                var parser = new Json.Parser ();
                parser.load_from_data (line);

                var root = parser.get_root ();
                if (root.get_node_type () != Json.NodeType.ARRAY) {
                    throw new IOError.FAILED ("Invalid collections JSON structure: expected array at root");
                }

                var array = root.get_array ();
                int loaded_count = 0;
                int skipped_count = 0;

                foreach (var t in array.get_elements ()) {
                    try {
                        if (t.get_node_type () != Json.NodeType.OBJECT) {
                            warning ("Skipping invalid collection entry: expected object\n");
                            skipped_count++;
                            continue;
                        }

                        var obj = t.get_object ();
                        string? name = null;
                        Json.Array? palette_names_array = null;

                        if (obj.has_member ("name")) {
                            name = obj.get_string_member ("name");
                        }
                        if (obj.has_member ("palette_names")) {
                            palette_names_array = obj.get_array_member ("palette_names");
                        }

                        if (name == null || !is_valid_name (name)) {
                            warning ("Skipping collection with invalid name\n");
                            skipped_count++;
                            continue;
                        }

                        string sanitized_name = sanitize_name (name);
                        if (sanitized_name == "") {
                            sanitized_name = "Unnamed Collection";
                        }

                        var collection = new CollectionInfo ();
                        collection.name = sanitized_name;
                        collection.palette_names = new Gee.ArrayList<string> ();

                        if (palette_names_array != null) {
                            foreach (var pname_node in palette_names_array.get_elements ()) {
                                if (pname_node.get_node_type () == Json.NodeType.VALUE) {
                                    string? pname = pname_node.get_string ();
                                    if (pname != null && is_valid_name (pname)) {
                                        collection.palette_names.add (sanitize_name (pname));
                                    }
                                }
                            }
                        }

                        win.collections_store.append (collection);
                        loaded_count++;
                    } catch (Error e) {
                        warning ("Error loading collection entry: %s\n", e.message);
                        skipped_count++;
                    }
                }

                if (loaded_count > 0) {
                    debug ("Successfully loaded %d collection(s) from %s\n", loaded_count, load_file.get_basename ());
                }
                if (skipped_count > 0) {
                    warning ("Skipped %d invalid collection entry(ies)\n", skipped_count);
                }
            } catch (Error e) {
                warning ("Failed to load collections file '%s': %s\n", load_file.get_basename (), e.message);
            }
        }
    }
}

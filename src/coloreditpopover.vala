/*
* Copyright (C) 2021 Lains
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
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
    [GtkTemplate (ui = "/io/github/lainsce/Emulsion/cep.ui")]
    public class ColorEditPopover : Gtk.Popover {
        [GtkChild]
        public unowned Gtk.Scale red_scale;
        [GtkChild]
        public unowned Gtk.Scale green_scale;
        [GtkChild]
        public unowned Gtk.Scale blue_scale;
        [GtkChild]
        public unowned Gtk.Entry red_entry;
        [GtkChild]
        public unowned Gtk.Entry green_entry;
        [GtkChild]
        public unowned Gtk.Entry blue_entry;
        [GtkChild]
        public unowned Gtk.Entry hex_entry;

        public MainWindow win { get; construct; }

        public ColorInfo _color_info;
        public ColorInfo color_info {
            get {
                return _color_info;
            }

            set {
                if(_color_info == value) {
                    return;
                }
                _color_info = value;
            }
        }

        public ColorEditPopover (MainWindow win) {
            Object( win: win );
            this.set_parent (win);
            this.present ();

            Gdk.RGBA color = {};
            color.parse(color_info.color);

            red_entry.set_text ("%f".printf(color.red));
            green_entry.set_text ("%f".printf(color.green));
            blue_entry.set_text ("%f".printf(color.blue));

            red_scale.set_fill_level (color.red);
            green_scale.set_fill_level (color.green);
            blue_scale.set_fill_level (color.blue);

            hex_entry.set_text ("%s".printf(color_info.name));

            print ("%s", color_info.name);
        }
    }
}

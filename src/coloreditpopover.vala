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
        public Gdk.RGBA color = {};

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
                color.parse(_color_info.color);

                red_entry.set_text ("%00.0f".printf(get_srgb(color.red)));
                green_entry.set_text ("%00.0f".printf(get_srgb(color.green)));
                blue_entry.set_text ("%00.0f".printf(get_srgb(color.blue)));

                red_scale.set_value (get_srgb(color.red));
                green_scale.set_value (get_srgb(color.green));
                blue_scale.set_value (get_srgb(color.blue));

                hex_entry.set_text ("%s".printf(make_hex((float)red_scale.get_value (), (float)green_scale.get_value (), (float)blue_scale.get_value ())));
                queue_draw ();
            }
        }

        public ColorEditPopover (MainWindow win) {
            Object( win: win );
            this.set_parent (win);
            this.present ();
            queue_draw ();
        }

        construct {
            red_scale.value_changed.connect (() => {
                red_entry.set_text ("%00.0f".printf(red_scale.get_value ()));
                color.red = (float)(double.parse(red_entry.get_text ()) / 255);
                hex_entry.set_text ("%s".printf(make_hex((float)red_scale.get_value (), (float)green_scale.get_value (), (float)blue_scale.get_value ())));
                _color_info.color = hex_entry.get_text ();
                _color_info.name = hex_entry.get_text ();

                win.m.save_palettes.begin (win.palettestore);
            });

            green_scale.value_changed.connect (() => {
                green_entry.set_text ("%00.0f".printf(green_scale.get_value ()));
                color.green = (float)(double.parse(green_entry.get_text ()) / 255);
                hex_entry.set_text ("%s".printf(make_hex((float)red_scale.get_value (), (float)green_scale.get_value (), (float)blue_scale.get_value ())));
                _color_info.color = hex_entry.get_text ();
                _color_info.name = hex_entry.get_text ();

                win.m.save_palettes.begin (win.palettestore);
            });

            blue_scale.value_changed.connect (() => {
                blue_entry.set_text ("%00.0f".printf(blue_scale.get_value ()));
                color.blue = (float)(double.parse(blue_entry.get_text ()) / 255);
                hex_entry.set_text ("%s".printf(make_hex((float)red_scale.get_value (), (float)green_scale.get_value (), (float)blue_scale.get_value ())));
                _color_info.color = hex_entry.get_text ();
                _color_info.name = hex_entry.get_text ();

                win.m.save_palettes.begin (win.palettestore);
            });
        }

        public double get_srgb(double c) {
            if (c <= 0.03928) {
                c = c / 12.92;
                return c * 255.0;
            } else {
                Math.pow (((c + 0.055) / 1.055), 2.4);
                return c * 255.0;
            }
        }

        public string make_hex (float red, float green, float blue) {
            return "#" + "%01.1x%01.1x%01.1x".printf ((uint)red, (uint)green, (uint)blue);
        }    }
}

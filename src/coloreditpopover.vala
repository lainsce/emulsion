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
        public unowned He.Slider red_scale;
        [GtkChild]
        public unowned He.Slider green_scale;
        [GtkChild]
        public unowned He.Slider blue_scale;
        [GtkChild]
        public unowned He.TextField red_entry;
        [GtkChild]
        public unowned He.TextField green_entry;
        [GtkChild]
        public unowned He.TextField blue_entry;
        [GtkChild]
        public unowned He.TextField hex_entry;
        [GtkChild]
        public unowned He.TextField name_entry;

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

                red_entry.text = "%00.0f".printf(Utils.make_srgb(color.red));
                green_entry.text = "%00.0f".printf(Utils.make_srgb(color.green));
                blue_entry.text = "%00.0f".printf(Utils.make_srgb(color.blue));

                red_scale.scale.set_value (Utils.make_srgb(color.red));
                green_scale.scale.set_value (Utils.make_srgb(color.green));
                blue_scale.scale.set_value (Utils.make_srgb(color.blue));

                hex_entry.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                name_entry.text = _color_info.name;
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            }
        }

        public ColorEditPopover (MainWindow win) {
            Object( win: win );
            this.set_parent (win);
            
            // Set up adjustments for sliders
            var red_adj = new Gtk.Adjustment (0, 0, 255, 1, 1, 0);
            var green_adj = new Gtk.Adjustment (0, 0, 255, 1, 1, 0);
            var blue_adj = new Gtk.Adjustment (0, 0, 255, 1, 1, 0);
            red_scale.set_adjustment (red_adj);
            green_scale.set_adjustment (green_adj);
            blue_scale.set_adjustment (blue_adj);
            
            this.present ();
            win.palette_fb.queue_draw ();
            win.color_fb.queue_draw ();
            queue_draw ();

            red_scale.scale.value_changed.connect (() => {
                red_entry.text = "%00.0f".printf(red_scale.scale.get_value ());
                color.red = (float)(double.parse(red_entry.text ?? "0") / 255);
                hex_entry.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                _color_info.color = hex_entry.text ?? "";

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            green_scale.scale.value_changed.connect (() => {
                green_entry.text = "%00.0f".printf(green_scale.scale.get_value ());
                color.green = (float)(double.parse(green_entry.text ?? "0") / 255);
                hex_entry.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                _color_info.color = hex_entry.text ?? "";

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            blue_scale.scale.value_changed.connect (() => {
                blue_entry.text = "%00.0f".printf(blue_scale.scale.get_value ());
                color.blue = (float)(double.parse(blue_entry.text ?? "0") / 255);
                hex_entry.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                _color_info.color = hex_entry.text ?? "";

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            red_entry.entry.activate.connect (() => {
                color.red = (float)(double.parse(red_entry.text ?? "0") / 255);
                red_scale.scale.set_value (double.parse(red_entry.text ?? "0"));
                hex_entry.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                _color_info.color = hex_entry.text ?? "";

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            green_entry.entry.activate.connect (() => {
                color.green = (float)(double.parse(green_entry.text ?? "0") / 255);
                green_scale.scale.set_value (double.parse(green_entry.text ?? "0"));
                hex_entry.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                _color_info.color = hex_entry.text ?? "";

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            blue_entry.entry.activate.connect (() => {
                color.blue = (float)(double.parse(blue_entry.text ?? "0") / 255);
                blue_scale.scale.set_value (double.parse(blue_entry.text ?? "0"));
                hex_entry.text = "%s".printf(Utils.make_hex((float)red_scale.scale.get_value (), (float)green_scale.scale.get_value (), (float)blue_scale.scale.get_value ()));
                _color_info.color = hex_entry.text ?? "";

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            hex_entry.entry.activate.connect (() => {
                _color_info.color = hex_entry.text ?? "";

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });

            name_entry.entry.activate.connect (() => {
                _color_info.name = name_entry.text ?? "";

                win.m.save_palettes.begin (win.palettestore);
                win.palette_fb.queue_draw ();
                win.color_fb.queue_draw ();
                queue_draw ();
            });
        }
    }
}

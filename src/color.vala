namespace Emulsion {
    public class ColorInfo : Object {
        /*
         * uid : string of the Palette's name e.g. "GNOME";
         * name : string of the Color name, e.g. "White";
         * color : string of the Color color, in hexcode, e.g. "#FFFFFF";
         */
        public string uid { get; set; }
        public string name { get; set; }
        public string color { get; set; }
    }

    public class ColorRenderer : Gtk.Box {
        private Object? _color_obj;
        private string _color_string = "";
        private ulong _notify_handler_id = 0;
        
        private void update_color_string () {
            if (_color_obj is ColorInfo) {
                _color_string = ((ColorInfo)_color_obj).color;
            } else if (_color_obj is RecentColorInfo) {
                _color_string = ((RecentColorInfo)_color_obj).color;
            } else if (_color_obj != null) {
                // Try to get "color" property via GObject
                Value color_val = Value (typeof (string));
                _color_obj.get_property ("color", ref color_val);
                _color_string = color_val.get_string () ?? "";
            } else {
                _color_string = "";
            }
            queue_draw ();
        }
        
        private void on_color_property_changed () {
            update_color_string ();
        }
        
        // Support for ColorInfo
        public ColorInfo? color {
            get {
                return _color_obj as ColorInfo;
            }
            set {
                if (_color_obj == value) {
                    return;
                }
                
                // Disconnect old notify signal
                if (_notify_handler_id != 0 && _color_obj != null) {
                    _color_obj.disconnect (_notify_handler_id);
                    _notify_handler_id = 0;
                }
                
                _color_obj = value;
                
                // Connect to property change notification
                if (value != null) {
                    _notify_handler_id = value.notify["color"].connect (on_color_property_changed);
                }
                
                update_color_string ();
            }
        }

        // Support for RecentColorInfo
        public RecentColorInfo? recent_color {
            get {
                return _color_obj as RecentColorInfo;
            }
            set {
                if (_color_obj == value) {
                    return;
                }
                
                // Disconnect old notify signal
                if (_notify_handler_id != 0 && _color_obj != null) {
                    _color_obj.disconnect (_notify_handler_id);
                    _notify_handler_id = 0;
                }
                
                _color_obj = value;
                
                // Connect to property change notification
                if (value != null) {
                    _notify_handler_id = value.notify["color"].connect (on_color_property_changed);
                }
                
                update_color_string ();
            }
        }

        // Generic binding support - bind to "color" property
        public Object? item {
            get {
                return _color_obj;
            }
            set {
                if (_color_obj == value) {
                    return;
                }
                
                // Disconnect old notify signal
                if (_notify_handler_id != 0 && _color_obj != null) {
                    _color_obj.disconnect (_notify_handler_id);
                    _notify_handler_id = 0;
                }
                
                _color_obj = value;
                
                // Connect to property change notification if object supports it
                if (value != null && value is Object) {
                    _notify_handler_id = ((Object)value).notify["color"].connect (on_color_property_changed);
                }
                
                update_color_string ();
            }
        }

        construct {
            this.add_css_class ("color");
            this.set_overflow(Gtk.Overflow.HIDDEN);
            this.set_orientation (Gtk.Orientation.HORIZONTAL);
            this.set_halign (Gtk.Align.CENTER);
            this.set_margin_start (6);
            this.set_margin_top (6);
            this.set_margin_end (6);
            this.set_size_request (128, 128);
	    }

	    protected override void snapshot (Gtk.Snapshot snapshot) {
            if (_color_string == null || _color_string.length == 0) {
                return;
            }
            Gdk.RGBA gc = {};
            gc.parse (_color_string);
            snapshot.append_color (gc, {{0, 0}, {128, 128}});
        }
    }
}

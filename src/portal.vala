namespace org.freedesktop.portal {
  [DBus(name = "org.freedesktop.portal.Request", timeout = 120000)]
  public interface Request : GLib.Object {

    [DBus(name = "Close")]
    public abstract void close() throws DBusError, IOError;

    [DBus(name = "Response")]
    public signal void response(uint response, GLib.HashTable<string, GLib.Variant> results);
  }

  [DBus(name = "org.freedesktop.portal.Screenshot", timeout = 120000)]
  public interface Screenshot : GLib.Object {

    [DBus(name = "PickColor")]
    public abstract GLib.ObjectPath pick_color (string parent_window, GLib.HashTable<string, GLib.Variant> options) throws DBusError, IOError;
  }
}

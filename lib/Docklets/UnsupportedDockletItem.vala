//
// Copyright (C) 2026 Plank Reloaded Developers
//
// This file is part of Plank.
//
// Plank is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Plank is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Plank {
  public class UnsupportedDockletItem : DockletItem {
    public string DockletName { private get; construct; }
    public string DockletIcon { private get; construct; }

    public UnsupportedDockletItem.with_dockitem_file (GLib.File file, Docklet docklet) {
      GLib.Object (
                   Prefs : new DockItemPreferences.with_file (file),
                   DockletName : docklet.get_name (),
                   DockletIcon : docklet.get_icon ()
      );
    }

    construct
    {
      Icon = (DockletIcon != null && DockletIcon != "") ? DockletIcon : "dialog-warning";
      Text = _("%s (Unavailable)").printf (DockletName);
    }

    protected override AnimationType on_clicked (PopupButton button, Gdk.ModifierType mod, uint32 event_time) {
      return AnimationType.NONE;
    }

    public override Gee.ArrayList<Gtk.MenuItem> get_menu_items () {
      var items = new Gee.ArrayList<Gtk.MenuItem> ();
      var info_item = new Gtk.MenuItem.with_label (_("This docklet is not available in the current session."));
      info_item.sensitive = false;
      items.add (info_item);
      return items;
    }
  }
}

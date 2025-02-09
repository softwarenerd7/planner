/*
* Copyright © 2019 Alain M. (https://github.com/alainm23/planner)
*
* This program is free software; you can redistribute it and/or
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
*
* Authored by: Alain M. <alainmh23@gmail.com>
*/

public class Objects.BaseObject : GLib.Object {
    public int64 id { get; set; default = Constants.INACTIVE; }

    public signal void deleted ();
    public signal void updated ();

    public uint update_timeout_id { get; set; default = Constants.INACTIVE; }

    string _id_string;
    public string id_string {
        get {
            _id_string = id.to_string ();
            return _id_string;
        }
    }

    public string type_delete {
        get {
            if (this is Objects.Item) {
                return "item_delete";
            } else if (this is Objects.Project) {
                return "project_delete";
            } else if (this is Objects.Section) {
                return "section_delete";
            } else if (this is Objects.Label) {
                return "label_delete";
            } else {
                return "";
            }
        }
    }

    public virtual string get_update_json (string uuid, string? temp_id = null) {
        return "";
    }

    public virtual string get_add_json (string temp_id, string uuid) {
        return "";
    }
}

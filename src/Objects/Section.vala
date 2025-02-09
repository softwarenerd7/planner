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

public class Objects.Section : Objects.BaseObject {
    public int64 project_id { get; set; default = 0; }
    public string name { get; set; default = ""; }
    public string archived_at { get; set; default = ""; }
    public string added_at { get; set; default = ""; }
    public int section_order { get; set; default = -1; }
    public bool collapsed { get; set; default = true; }
    public bool is_deleted { get; set; default = true; }
    public bool is_archived { get; set; default = true; }

    string _short_name;
    public string short_name {
        get {
            _short_name = Util.get_default ().get_short_name (name);
            return _short_name;
        }
    }

    Objects.Project? _project;
    public Objects.Project project {
        get {
            _project = Planner.database.get_project (project_id);
            return _project;
        }
    }

    Gee.ArrayList<Objects.Item> _items;
    public Gee.ArrayList<Objects.Item> items {
        get {
            _items = Planner.database.get_item_by_baseobject (this);
            return _items;
        }
    }

    public signal void item_added (Objects.Item item);

    construct {
        deleted.connect (() => {
            Planner.database.section_deleted (this);
        });
    }

    public Section.from_json (Json.Node node) {
        id = node.get_object ().get_int_member ("id");
        update_from_json (node);
    }

    public void update_from_json (Json.Node node) {
        project_id = node.get_object ().get_int_member ("project_id");
        name = node.get_object ().get_string_member ("name");
        added_at = node.get_object ().get_string_member ("added_at");
        section_order = (int32) node.get_object ().get_int_member ("section_order");
        is_deleted = node.get_object ().get_boolean_member ("is_deleted");
        is_archived = node.get_object ().get_boolean_member ("is_archived");
        collapsed = node.get_object ().get_boolean_member ("collapsed");

        if (!node.get_object ().get_null_member ("archived_at")) {
            archived_at = node.get_object ().get_string_member ("archived_at");
        }
    }

    public void set_project (Objects.Project project) {
        this._project = project;
    }

    public Objects.Item add_item_if_not_exists (Objects.Item new_item, bool insert=true) {
        Objects.Item? return_value = null;
        lock (_items) {
            return_value = get_item (new_item.id);
            if (return_value == null) {
                new_item.set_section (this);
                add_item (new_item);
                Planner.database.insert_item (new_item, insert);
                return_value = new_item;
            }
            return return_value;
        }
    }

    public Objects.Item? get_item (int64 id) {
        Objects.Item? return_value = null;
        lock (_items) {
            foreach (var item in items) {
                if (item.id == id) {
                    return_value = item;
                    break;
                }
            }
        }
        return return_value;
    }

    public void add_item (Objects.Item item) {
        this._items.add (item);
    }

    public void update (bool cloud=true) {
        if (update_timeout_id != 0) {
            Source.remove (update_timeout_id);
        }

        update_timeout_id = Timeout.add (Constants.UPDATE_TIMEOUT, () => {
            update_timeout_id = 0;

            Planner.database.update_section (this);
            if (project.todoist && cloud) {
                Planner.todoist.update.begin (this, (obj, res) => {
                    Planner.todoist.update.end (res);
                });
            }

            return GLib.Source.REMOVE;
        });
    }

    public override string get_update_json (string uuid, string? temp_id = null) {
        var builder = new Json.Builder ();
        builder.begin_array ();
        builder.begin_object ();

        // Set type
        builder.set_member_name ("type");
        builder.add_string_value (temp_id == null ? "section_update" : "section_add");

        builder.set_member_name ("uuid");
        builder.add_string_value (uuid);

        if (temp_id != null) {
            builder.set_member_name ("temp_id");
            builder.add_string_value (temp_id);
        }

        builder.set_member_name ("args");
            builder.begin_object ();
            
            if (temp_id == null) {
                builder.set_member_name ("id");
                builder.add_int_value (id);
            }

            builder.set_member_name ("name");
            builder.add_string_value (Util.get_default ().get_encode_text (name));

            builder.end_object ();

        builder.end_object ();
        builder.end_array ();

        Json.Generator generator = new Json.Generator ();
        Json.Node root = builder.get_root ();
        generator.set_root (root);

        return generator.to_data (null);
    }

    public override string get_add_json (string temp_id, string uuid) {
        return get_update_json (uuid, temp_id);
    }

    public void delete (bool confirm = true) {
        if (!confirm) {
            if (project.todoist) {
                Planner.todoist.delete.begin (this, (obj, res) => {
                    Planner.todoist.delete.end (res);
                    Planner.database.delete_section (this);
                });
            } else {
                Planner.database.delete_section (this);
            }

            return;
        }

        int tasks = items.size;
        string message = _("Are you sure you want to delete %s?".printf (Util.get_default ().get_dialog_text (name)));
        if (tasks > 0) {
            message = _("Delete %s with its %d tasks?".printf (Util.get_default ().get_dialog_text (name), tasks));
        }

        var message_dialog = new Granite.MessageDialog.with_image_from_icon_name (
            _("Delete section"),
            message,
            "dialog-warning",
        Gtk.ButtonsType.CANCEL);

        var remove_button = new Widgets.LoadingButton (LoadingButtonType.LABEL, _("Delete"));
        remove_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
        message_dialog.add_action_widget (remove_button, Gtk.ResponseType.ACCEPT);

        message_dialog.show_all ();

        if (message_dialog.run () == Gtk.ResponseType.ACCEPT) {
            if (project.todoist) {
                remove_button.is_loading = true;
                Planner.todoist.delete.begin (this, (obj, res) => {
                    Planner.todoist.delete.end (res);
                    Planner.database.delete_section (this);
                    remove_button.is_loading = false;
                    message_dialog.destroy ();
                });
            } else {
                Planner.database.delete_section (this);
                message_dialog.destroy ();
            }
        } else {
            message_dialog.destroy ();
        }
    }
}

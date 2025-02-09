/*
* Copyright (c) 2017 Daniel Foré (http://danielfore.com)
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
*
*/

public class Planner : Gtk.Application {
    public MainWindow? main_window = null;

    public static GLib.Settings settings;
    public static Services.Database database;
    public static Services.EventBus event_bus;
    public static Services.Todoist todoist;
    
    public static Planner _instance = null;
    public static Planner instance {
        get {
            if (_instance == null) {
                _instance = new Planner ();
            }
            return _instance;
        }
    }

    private static bool silent = false;
    private static bool version = false;
    private static bool clear_database = false;
    private static string lang = "";

    public const OptionEntry[] PLANNER_OPTIONS = {
        { "version", 'v', 0, OptionArg.NONE, ref version,
        "Display version number", null },
        { "reset", 'r', 0, OptionArg.NONE, ref clear_database,
        "Reset Planner", null },
        { "silent", 's', 0, OptionArg.NONE, out silent,
        "Run the Application in background", null },
        { "lang", 'l', 0, OptionArg.STRING, ref lang,
        "Open Planner in a specific language", "LANG" },
        { null }
    };

    construct {
        application_id = "com.github.alainm23.planner";
        flags |= ApplicationFlags.HANDLES_OPEN;

        Intl.setlocale (LocaleCategory.ALL, "");
        string langpack_dir = Path.build_filename (Constants.INSTALL_PREFIX, "share", "locale");
        Intl.bindtextdomain (Constants.GETTEXT_PACKAGE, langpack_dir);
        Intl.bind_textdomain_codeset (Constants.GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (Constants.GETTEXT_PACKAGE);

        create_dir_with_parents ("/com.github.alainm23.planner");

        settings = new Settings ("com.github.alainm23.planner");
        event_bus = new Services.EventBus ();

        add_main_option_entries (PLANNER_OPTIONS);
    }

    protected override void activate () {
        if (lang != "") {
            GLib.Environment.set_variable ("LANGUAGE", lang, true);
        }

        if (main_window != null) {
            int x, y;
            settings.get ("window-position", "(ii)", out x, out y);
            if (x != -1 || y != -1) {
                main_window.move (x, y);
            }

            main_window.present ();

            return;
        }

        if (version) {
            print ("%s\n".printf (Constants.VERSION));
            return;
        }

        if (clear_database) {
            print ("%s\n".printf (_("Are you sure you want to reset all?")));
            print (_("It process removes all stored information without the possibility of undoing it. (y/n): "));
            string input = stdin.read_line ();
            
            if (input == _("y") || input == _("yes") ) {
                string db_path = Environment.get_user_data_dir () + "/com.github.alainm23.planner/database.db";
                File db_file = File.new_for_path (db_path);

                if (db_file.query_exists ()) {
                    try {
                        db_file.delete ();
                    } catch (Error err) {
                        warning (err.message);
                    }
                }

                var schema_source = GLib.SettingsSchemaSource.get_default ();
                SettingsSchema schema = schema_source.lookup ("com.github.alainm23.planner", true);

                foreach (string key in schema.list_keys ()) {
                    Planner.settings.reset (key);
                }
            }

            return;
        }

        main_window = new MainWindow (this);

        int window_x, window_y;
        int width, height;

        settings.get ("window-position", "(ii)", out window_x, out window_y);
        settings.get ("window-size", "(ii)", out width, out height);

        if (window_x != -1 || window_y != -1) {
            main_window.move (window_x, window_y);
        }

        if (width != -1 || height != -1) {
            var rect = Gtk.Allocation ();
            rect.height = height;
            rect.width = width;
            main_window.set_allocation (rect);
        }

        if (settings.get_boolean ("window-maximized")) {
            main_window.maximize ();
        }

        if (!silent) {
            main_window.show_all ();
        }

        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/com/github/alainm23/planner/index.css");
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        
        Util.get_default ().update_theme ();
    }
    
    public void create_dir_with_parents (string dir) {
        string path = Environment.get_user_data_dir () + dir;
        File tmp = File.new_for_path (path);
        if (tmp.query_file_type (0) != FileType.DIRECTORY) {
            GLib.DirUtils.create_with_parents (path, 0775);
        }
    }

    public static int main (string[] args) {
        Planner app = Planner.instance;
        return app.run (args);
    }
}

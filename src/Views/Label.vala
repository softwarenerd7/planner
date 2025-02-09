public class Views.Label : Gtk.EventBox {
    public Objects.Label label { get; set; }

    public Gee.HashMap <string, Layouts.ItemRow> items;
    private Gtk.ListBox listbox;
    private Gtk.Grid widget_color;
    private Gtk.Label title_label;

    construct {
        items = new Gee.HashMap <string, Layouts.ItemRow> ();

        widget_color = new Gtk.Grid () {
            valign = Gtk.Align.CENTER,
            height_request = 16,
            width_request = 16,
            margin_start = 3
        };

        unowned Gtk.StyleContext widget_color_context = widget_color.get_style_context ();
        widget_color_context.add_class ("label-color");

        title_label = new Gtk.Label (null);
        title_label.get_style_context ().add_class ("header-title");

        var menu_image = new Widgets.DynamicIcon ();
        menu_image.size = 19;
        menu_image.update_icon_name ("dots-horizontal");
        
        var menu_button = new Gtk.Button () {
            valign = Gtk.Align.CENTER,
            can_focus = false
        };

        menu_button.add (menu_image);
        menu_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var search_image = new Widgets.DynamicIcon ();
        search_image.size = 19;
        search_image.update_icon_name ("planner-search");
        
        var search_button = new Gtk.Button () {
            valign = Gtk.Align.CENTER,
            can_focus = false
        };
        search_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        search_button.add (search_image);

        var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            valign = Gtk.Align.START,
            hexpand = true,
            margin_start = 2,
            margin_end = 6
        };

        header_box.pack_start (widget_color, false, false, 0);
        header_box.pack_start (title_label, false, false, 9);
        header_box.pack_end (menu_button, false, false, 0);
        header_box.pack_end (search_button, false, false, 0);

        var magic_button = new Widgets.MagicButton ();

        listbox = new Gtk.ListBox () {
            valign = Gtk.Align.START,
            activate_on_single_click = true,
            selection_mode = Gtk.SelectionMode.SINGLE,
            hexpand = true
        };
        listbox.set_placeholder (get_placeholder ());

        unowned Gtk.StyleContext listbox_context = listbox.get_style_context ();
        listbox_context.add_class ("listbox-background");

        var listbox_grid = new Gtk.Grid () {
            margin_top = 12
        };
        listbox_grid.add (listbox);

        var content = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL,
            expand = true,
            margin_start = 36,
            margin_end = 36,
            margin_bottom = 36,
            margin_top = 6
        };
        content.add (header_box);
        content.add (listbox_grid);

        var content_clamp = new Hdy.Clamp () {
            maximum_size = 720
        };

        content_clamp.add (content);

        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            expand = true
        };
        scrolled_window.add (content_clamp);

        var overlay = new Gtk.Overlay () {
            expand = true
        };
        overlay.add_overlay (magic_button);
        overlay.add (scrolled_window);

        add (overlay);
        show_all ();

        notify ["label"].connect (() => {
            if (label != null) {
                update_request ();
                add_items ();
            }
        });

        magic_button.clicked.connect (() => {
            
        });

        Planner.database.item_added.connect (valid_add_item);
        Planner.database.item_deleted.connect (valid_delete_item);
        Planner.database.item_updated.connect (valid_update_item);
    }

    private void valid_add_item (Objects.Item item, bool insert = true) {
        if (!items.has_key (item.id_string) && item.labels.has_key (label.id_string)
            && insert) {
            add_item (item);   
        }
    }

    private void valid_delete_item (Objects.Item item) {
        if (items.has_key (item.id_string)) {
            items[item.id_string].hide_destroy ();
            items.unset (item.id_string);
        }
    }

    private void valid_update_item (Objects.Item item) {
        if (items.has_key (item.id_string) && !item.labels.has_key (label.id_string)) {
            items[item.id_string].hide_destroy ();
            items.unset (item.id_string);
        }

        valid_add_item (item);
    }

    private void add_items () {
        items.clear ();
        
        foreach (unowned Gtk.Widget child in listbox.get_children ()) {
            child.destroy ();
        }

        foreach (Objects.Item item in Planner.database.get_items_by_label (label, false)) {
            add_item (item);
        }
    }

    private void add_item (Objects.Item item) {
        items [item.id_string] = new Layouts.ItemRow (item);
        listbox.add (items [item.id_string]);
        listbox.show_all ();
    }

    private Gtk.Widget get_placeholder () {
        var calendar_image = new Widgets.DynamicIcon () {
            opacity = 0.1
        };
        calendar_image.size = 96;

        calendar_image.update_icon_name ("planner-pinned");

        var grid = new Gtk.Grid () {
            margin_top = 128,
            halign = Gtk.Align.CENTER
        };
        grid.add (calendar_image);
        grid.show_all ();

        return grid;
    }

    public void update_request () {
        title_label.label = label.name;
        Util.get_default ().set_widget_color (Util.get_default ().get_color (label.color), widget_color);
    }
}

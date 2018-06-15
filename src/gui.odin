/*
 *  @Name:     gui
 *  
 *  @Author:   Mikkel Hjortshoej
 *  @Email:    fyoucon@gmail.com
 *  @Creation: 21-05-2018 15:57:17 UTC+1
 *
 *  @Last By:   Mikkel Hjortshoej
 *  @Last Time: 16-06-2018 00:48:47 UTC+1
 *  
 *  @Description:
 *  
 */

package main;


import       "core:fmt";
import       "core:mem";
import       "core:strings";

import sys  "shared:libbrew/sys";
import cel  "shared:odin-cel";
import      "shared:libbrew/imgui";
import      "shared:odin-imgui";
import      "shared:libbrew/gl";
import util "shared:libbrew/util";

set_proc :: inline proc(lib_ : rawptr, p: rawptr, name: string) {
    lib := sys.LibHandle(lib_);
    res := sys.wgl_get_proc_address(name);
    if res == nil {
        res = sys.get_proc_address(lib, name);
    }
    if res == nil {
        fmt.println("Couldn't load:", name);
    }

    (^rawptr)(p)^ = rawptr(res);
}

load_lib :: proc(str : string) -> rawptr {
    return rawptr(sys.load_library(str));
}

free_lib :: proc(lib : rawptr) {
    sys.free_library(sys.LibHandle(lib));
}

setup_window :: proc(w, h : int) -> sys.WndHandle {
    app_handle := sys.get_app_handle();
    buf : [1024]byte;
    title := fmt.bprintf(buf[..], "Gungnir %s", VERSION_STR);
    wnd_handle := sys.create_window(app_handle, title, w, h, 
                                       sys.Window_Style.NonresizeableWindow);
    gl_ctx     := sys.create_gl_context(wnd_handle, 3, 3);

    gl.load_functions(set_proc, load_lib, free_lib);
    //wgl.swap_interval(-1);
    gl.clear_color(0.10, 0.10, 0.10, 1);
    gl.viewport(0, 0, i32(w), i32(h));
    gl.scissor (0, 0, i32(w), i32(h));

    return wnd_handle;
}

style :: proc() {
    style := imgui.get_style();

    style.window_padding        = imgui.Vec2{6, 6};
    style.window_rounding       = 0;
    style.child_rounding        = 2;
    style.frame_padding         = imgui.Vec2{4 ,2};
    style.frame_rounding        = 2;
    style.frame_border_size     = 1;
    style.item_spacing          = imgui.Vec2{8, 4};
    style.item_inner_spacing    = imgui.Vec2{4, 4};
    style.touch_extra_padding   = imgui.Vec2{0, 0};
    style.indent_spacing        = 20;
    style.scrollbar_size        = 12;
    style.scrollbar_rounding    = 9;
    style.grab_min_size         = 9;
    style.grab_rounding         = 1;
    style.window_title_align    = imgui.Vec2{0.48, 0.5};
    style.button_text_align     = imgui.Vec2{0.5, 0.5};

    style.colors[imgui.Color.Text]                  = imgui.Vec4{1.00, 1.00, 1.00, 1.00};
    style.colors[imgui.Color.TextDisabled]          = imgui.Vec4{0.63, 0.63, 0.63, 1.00};
    style.colors[imgui.Color.WindowBg]              = imgui.Vec4{0.23, 0.23, 0.23, 0.98};
    style.colors[imgui.Color.ChildBg]               = imgui.Vec4{0.20, 0.20, 0.20, 1.00};
    style.colors[imgui.Color.PopupBg]               = imgui.Vec4{0.25, 0.25, 0.25, 0.96};
    style.colors[imgui.Color.Border]                = imgui.Vec4{0.18, 0.18, 0.18, 0.98};
    style.colors[imgui.Color.BorderShadow]          = imgui.Vec4{0.00, 0.00, 0.00, 0.04};
    style.colors[imgui.Color.FrameBg]               = imgui.Vec4{0.00, 0.00, 0.00, 0.29};
    style.colors[imgui.Color.TitleBg]               = imgui.Vec4{32.0/255.00, 32.0/255.00, 32.0/255.00, 1};
    style.colors[imgui.Color.TitleBgCollapsed]      = imgui.Vec4{0.12, 0.12, 0.12, 0.49};
    style.colors[imgui.Color.TitleBgActive]         = imgui.Vec4{32.0/255.00, 32.0/255.00, 32.0/255.00, 1};
    style.colors[imgui.Color.MenuBarBg]             = imgui.Vec4{0.11, 0.11, 0.11, 0.42};
    style.colors[imgui.Color.ScrollbarBg]           = imgui.Vec4{0.00, 0.00, 0.00, 0.08};
    style.colors[imgui.Color.ScrollbarGrab]         = imgui.Vec4{0.27, 0.27, 0.27, 1.00};
    style.colors[imgui.Color.ScrollbarGrabHovered]  = imgui.Vec4{0.78, 0.78, 0.78, 0.40};
    style.colors[imgui.Color.CheckMark]             = imgui.Vec4{0.78, 0.78, 0.78, 0.94};
    style.colors[imgui.Color.SliderGrab]            = imgui.Vec4{0.78, 0.78, 0.78, 0.94};
    style.colors[imgui.Color.Button]                = imgui.Vec4{0.42, 0.42, 0.42, 0.60};
    style.colors[imgui.Color.ButtonHovered]         = imgui.Vec4{0.78, 0.78, 0.78, 0.40};
    style.colors[imgui.Color.Header]                = imgui.Vec4{0.31, 0.31, 0.31, 0.98};
    style.colors[imgui.Color.HeaderHovered]         = imgui.Vec4{0.78, 0.78, 0.78, 0.40};
    style.colors[imgui.Color.HeaderActive]          = imgui.Vec4{0.80, 0.50, 0.50, 1.00};
    style.colors[imgui.Color.TextSelectedBg]        = imgui.Vec4{0.65, 0.35, 0.35, 0.26};
    style.colors[imgui.Color.ModalWindowDarkening]  = imgui.Vec4{0.20, 0.20, 0.20, 0.35};
}

String_Buffers :: struct {
    main_file_buf  : [1024]byte,
    app_name_buf   : [1024]byte,
    resource_buf   : [1024]byte,
    otime_file_buf : [256]byte,

    move_buf       : [1024]byte,
    delete_buf     : [1024]byte,

    collection_name_buf : [1024]byte,
    collection_path_buf : [1024]byte,
}

gui_run :: proc(settings : ^Settings, transient : ^Transient) {
    WND_WIDTH  :: 500;
    WND_HEIGHT :: 600;

    wnd_handle := setup_window(WND_WIDTH, WND_HEIGHT);
    dear_state := new(brew_imgui.State);
    brew_imgui.init(dear_state, wnd_handle, style);
   
    
    time_data := sys.create_time_data();
    new_frame_state := brew_imgui.FrameState{};
    new_frame_state.window_width  = WND_WIDTH;
    new_frame_state.window_height = WND_HEIGHT;
    new_frame_state.right_mouse = false;
    message := sys.Msg{};
    running := true;
    shift_down := false;
    dt := 0.0;

    str_bufs := String_Buffers{};
    fmt.bprintf(str_bufs.main_file_buf[..], settings.main_file);
    fmt.bprintf(str_bufs.app_name_buf[..], settings.app_name);
    fmt.bprintf(str_bufs.resource_buf[..], settings.resource_path);
    fmt.bprintf(str_bufs.otime_file_buf[..], transient.otime_file);

    add_new_collection  := false;
    editing_collection  := false;
    editing_index       := -1;
    modal_open          := false;

    add_new_move := false;
    add_new_delete := false;

    
    for running {
        new_frame_state.mouse_wheel = 0;

        for sys.poll_message(&message) {
            switch msg in message {
                case sys.MsgQuitMessage : {
                    running = false;
                }

                case sys.MsgChar : {
                    imgui.gui_io_add_input_character(u16(msg.char));
                }

                case sys.MsgKey : {
                    switch msg.key {
                        case sys.VirtualKey.Escape : {
                            if msg.down == true && shift_down {
                                running = false;
                            }
                        }

                        case sys.VirtualKey.Lshift : {
                            shift_down = msg.down;
                        }
                    }
                }

                case sys.MsgMouseButton : {
                    switch msg.key {
                        case sys.VirtualKey.LMouse : {
                            new_frame_state.left_mouse = msg.down;
                        }

                        case sys.VirtualKey.RMouse : {
                            new_frame_state.right_mouse = msg.down;
                        }
                    }
                }

                case sys.MsgWindowFocus : {
                    new_frame_state.window_focus = msg.enter_focus;
                }

                case sys.MsgMouseMove : {
                    new_frame_state.mouse_x = msg.x;
                    new_frame_state.mouse_y = msg.y;
                }

                case sys.MsgMouseWheel : {
                    new_frame_state.mouse_wheel = msg.distance;
                }
            }
        }

        dt = sys.time(&time_data);
        new_frame_state.deltatime     = f32(dt);

        gl.clear(gl.ClearFlags.COLOR_BUFFER | gl.ClearFlags.DEPTH_BUFFER);
        brew_imgui.begin_new_frame(&new_frame_state);
        {
            imgui.set_next_window_pos(imgui.Vec2{0,0}, imgui.Set_Cond.Once);
            imgui.set_next_window_size(imgui.Vec2{WND_WIDTH, WND_HEIGHT}, imgui.Set_Cond.Once);
            imgui.begin("main", nil, imgui.Window_Flags.NoTitleBar |
                                     imgui.Window_Flags.NoResize |
                                     imgui.Window_Flags.NoCollapse | 
                                     imgui.Window_Flags.NoMove /*|
                                     imgui.Window_Flags.MenuBar*/);

           /* p_open := -1;
            if imgui.begin_menu_bar() {
                if imgui.begin_menu("Packages") {
                    defer imgui.end_menu();
                    if imgui.menu_item("List") {
                        p_open = 1;
                    }
                    if imgui.menu_item("Add Package") {
                        p_open = 2;
                    }
                    if imgui.menu_item("Remove Package") {
                        p_open = 3;
                    }
                    imgui.separator();
                    if imgui.menu_item("Download Now") {
                        p_open = 4;
                    }
                }
            }
            imgui.end_menu_bar();

            switch p_open {
                case 1: {
                    imgui.open_popup("List Packages###LIST_PACKAGES");
                    modal_open = true;
                }
            }
            imgui.set_next_window_size(imgui.Vec2{400, 300});
            if imgui.begin_popup_modal("List Packages###LIST_PACKAGES", &modal_open,
                                       imgui.Window_Flags.NoResize | imgui.Window_Flags.NoMove) {

                for i in 0..30 {
                    imgui.text("TEST %v @ v1.2.3.4.5.6", i);
                }
                defer imgui.end_popup();
            }*/

            main_settings(settings, transient, &str_bufs); 

            imgui.push_id("move");
            files_settings(settings, str_bufs.move_buf[..],   &add_new_move, &settings.files_to_move,   "Files to move after building.");
            imgui.pop_id();

            imgui.push_id("delete");
            files_settings(settings, str_bufs.delete_buf[..], &add_new_delete, &settings.files_to_delete, "Files to delete after building.");
            imgui.pop_id();

            collection_settings(settings, transient, 
                                &editing_index, &editing_collection, &add_new_collection,
                                &str_bufs);
        }
        imgui.end();
        brew_imgui.render_proc(dear_state, true, WND_WIDTH, WND_HEIGHT);
        sys.swap_buffers(wnd_handle);
    }
}

main_settings :: proc(settings : ^Settings, transient : ^Transient, str_bufs : ^String_Buffers) {
    levels := []string{"0", "1", "2", "3"};
    if imgui.combo("Opt Level", cast(^i32)&transient.opt_level, levels) {
        cel.marshal_file(TRANSIENT_PATH, transient^);
    }

    if imgui.checkbox("Generate .PDBs?", &transient.generate_debug) {
        cel.marshal_file(TRANSIENT_PATH, transient^);
    }
    if imgui.checkbox("Keep temp files?", &transient.keep_temp_files) {
        cel.marshal_file(TRANSIENT_PATH, transient^);
    }
    if imgui.input_text("Main File Location", str_bufs.main_file_buf[..]) {
        settings.main_file = util.str_from_buf(str_bufs.main_file_buf[..]);
        cel.marshal_file(SETTINGS_PATH, settings^);
    }
    if imgui.input_text("App Name", str_bufs.app_name_buf[..]) {
        settings.app_name = util.str_from_buf(str_bufs.app_name_buf[..]);
        cel.marshal_file(SETTINGS_PATH, settings^);
    }
    if imgui.checkbox("Use Resource File?", &settings.use_resource) {
        cel.marshal_file(SETTINGS_PATH, settings^);
    }
    if settings.use_resource {
        if imgui.input_text("Resource Name", str_bufs.resource_buf[..]) {
            settings.resource_path = util.str_from_buf(str_bufs.resource_buf[..]);
            cel.marshal_file(SETTINGS_PATH, settings^);
        }
    }
    if imgui.checkbox("Use Otime?", &transient.use_otime) {
        cel.marshal_file(TRANSIENT_PATH, transient^);
    }
    if transient.use_otime {
        imgui.indent();
        if imgui.checkbox("Use app name?", &transient.otime_use_app) {
            transient.otime_file = settings.app_name;
            fmt.bprintf(str_bufs.otime_file_buf[..], transient.otime_file);
            cel.marshal_file(TRANSIENT_PATH, transient^);
        }
        if !transient.otime_use_app {
            if imgui.input_text("File name", str_bufs.otime_file_buf[..]) {
                transient.otime_file = util.str_from_buf(str_bufs.otime_file_buf[..]);
                cel.marshal_file(TRANSIENT_PATH, transient^);
            }
        }
        imgui.unindent();
    }
}

files_settings :: proc(settings : ^Settings, temp_buf : []byte, add_new : ^bool, files : ^[dynamic]string, title : string) {
    index_to_remove := -1;

    imgui.text(title);
    if imgui.begin_child("move files", imgui.Vec2{0, 100}) {
        for file, i in files {
            imgui.push_id(i); defer imgui.pop_id();
            imgui.text(file); imgui.same_line();
            if imgui.button("Remove") {
                index_to_remove = i;
            }
        }

        if !add_new^ && imgui.button("Add file") {
            add_new^ = true;
        }
        if add_new^ {
            imgui.input_text("File Name", temp_buf[..]); imgui.same_line();
            if imgui.button("Save") {
                add_new^ = false;
                tmp := util.str_from_buf(temp_buf[..]);
                str := strings.new_string(tmp);
                append(files, str);
                mem.zero(&temp_buf[0], len(temp_buf));
                cel.marshal_file(SETTINGS_PATH, settings^);
            }
            imgui.same_line();
            if imgui.button("Cancel") {
                add_new^ = false;
                mem.zero(&temp_buf[0], len(temp_buf));
            }
        } 
    }
    imgui.end_child();
    
    if index_to_remove > -1 {
        util.remove_ordered(files, index_to_remove);
        cel.marshal_file(SETTINGS_PATH, settings^);
    }
}

collection_settings :: proc(settings : ^Settings, transient : ^Transient, 
                            editing_index : ^int, editing_collection : ^bool, add_new : ^bool, 
                            str_bufs : ^String_Buffers) {

    reset_str_bufs :: proc(str_bufs : ^String_Buffers) {
        mem.zero(&str_bufs.collection_name_buf[0], len(str_bufs.collection_name_buf));
        mem.zero(&str_bufs.collection_path_buf[0], len(str_bufs.collection_path_buf));
    }

    index_to_remove := -1;
    imgui.text("Collections.");
    index_to_remove = -1;
    if imgui.begin_child("Collections") {
        imgui.columns(count = 2, border = false);
        for col_name, i in settings.collection_names {
            if i == editing_index^ do continue;
            imgui.push_id(i); defer imgui.pop_id();
            imgui.set_column_width(width = 150);
            imgui.text(col_name); imgui.same_line();
            imgui.next_column();
            collection : Collection_Entry;
            for col in transient.collections {
                if col_name == col.name {
                    imgui.text(col.path); imgui.same_line();
                    collection = col;
                }
            }

            if imgui.button("Edit") {
                editing_index^ = i;
                fmt.bprintf(str_bufs.collection_name_buf[..], col_name);
                if len(collection.path) > 0 {
                    fmt.bprintf(str_bufs.collection_path_buf[..], collection.path);
                }
                editing_collection^ = true;
            } imgui.same_line();

            if imgui.button("Remove") {
                index_to_remove = i;
            }
            imgui.next_column();
        }
        brew_imgui.columns_reset();

        if editing_collection^ {
            imgui.input_text("Name##collection", str_bufs.collection_name_buf[..]); 
            imgui.input_text("Path##collection", str_bufs.collection_path_buf[..]);

            if imgui.button("Save##edit_collection") {
                editing_collection^ = false;

                new_name := util.str_from_buf(str_bufs.collection_name_buf[..]);
                col_name := settings.collection_names[editing_index^];

                if new_name != col_name {
                    settings.collection_names[editing_index^] = strings.new_string(new_name);
                }

                path := util.str_from_buf(str_bufs.collection_path_buf[..]);
                if new_name != col_name {
                    remove_i := -1; 
                    for old, i in transient.collections {
                        if old.name == col_name {
                            remove_i = i;
                        }
                    }
                    
                    if index_to_remove > -1 {
                        util.remove_ordered(&transient.collections, remove_i);
                    }

                    append(&transient.collections, Collection_Entry{strings.new_string(new_name), 
                                                                    strings.new_string(path)});
                } else {
                    change := -1;
                    for col, i in transient.collections {
                        if col.name == col_name {
                            change = i;
                        }
                    }
                    if change > -1 {
                        col := transient.collections[change];
                        col.path = strings.new_string(path);
                        transient.collections[change] = col;
                    } else {
                        append(&transient.collections, Collection_Entry{strings.new_string(new_name), 
                                                                        strings.new_string(path)});
                    }
                }

                reset_str_bufs(str_bufs);
                editing_index^ = -1;
                cel.marshal_file(SETTINGS_PATH, settings^);
                cel.marshal_file(TRANSIENT_PATH, transient^);
            }
            imgui.same_line();
            if imgui.button("Cancel##edit_collection") {
                editing_collection^ = false;
                reset_str_bufs(str_bufs);
                editing_index^ = -1;
            }
        }

        if !add_new^ && imgui.button("Add collection") {
            add_new^ = true;
        }

        if add_new^ {
            imgui.input_text("Name##collection", str_bufs.collection_name_buf[..]); 
            imgui.input_text("Path##collection", str_bufs.collection_path_buf[..]);

            if imgui.button("Save##collection") {
                add_new^ = false;
                
                tmp  := util.str_from_buf(str_bufs.collection_name_buf[..]);
                name := strings.new_string(tmp);
                append(&settings.collection_names, name);
                
                tmp   = util.str_from_buf(str_bufs.collection_path_buf[..]);
                if len(tmp) > 0 {
                    path := strings.new_string(tmp);
                    append(&transient.collections, Collection_Entry{name, path});
                }

                reset_str_bufs(str_bufs);

                cel.marshal_file(SETTINGS_PATH, settings^);
                cel.marshal_file(TRANSIENT_PATH, transient^);
            }
            imgui.same_line();
            if imgui.button("Cancel##collection") {
                add_new^ = false;
                reset_str_bufs(str_bufs);
            }
        }
    }
    imgui.end_child();

    if index_to_remove > -1 {
        name := settings.collection_names[index_to_remove];
        remove_i := -1;
        for col, i in transient.collections {
            if col.name == name {
                remove_i = i;
            }
        }

        util.remove_ordered(&settings.collection_names, index_to_remove);
        util.remove_ordered(&transient.collections,     remove_i);
        cel.marshal_file(SETTINGS_PATH,  settings^);
        cel.marshal_file(TRANSIENT_PATH, transient^);
    }

}
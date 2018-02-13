/*
 *  @Name:     main
 *  
 *  @Author:   Mikkel Hjortshoej
 *  @Email:    hoej@northwolfprod.com
 *  @Creation: 24-01-2018 04:24:11 UTC+1
 *
 *  @Last By:   Mikkel Hjortshoej
 *  @Last Time: 13-02-2018 13:45:17 UTC+1
 *  
 *  @Description:
 *  
 */

import       "core:fmt.odin";
import       "core:utf16.odin";
import       "core:os.odin";
import       "core:strings.odin";
import       "core:mem.odin";
import       "core:strconv.odin";
import win32 "core:sys/windows.odin";

import       "shared:libbrew/sys/file.odin";
import       "shared:libbrew/sys/window.odin";
import       "shared:libbrew/sys/misc.odin";
import       "shared:libbrew/sys/msg.odin";
import       "shared:libbrew/sys/keys.odin";
import wgl   "shared:libbrew/sys/opengl.odin";

import       "shared:libbrew/cel.odin";
import       "shared:libbrew/string_util.odin";
import imgui "shared:libbrew/brew_imgui.odin";
import gl    "shared:libbrew/gl.odin";
import       "shared:libbrew/dyna_util.odin";

VERSION_STR :: "v1.1.0-dev";

Settings :: struct {
    main_file        : string,
    app_name         : string,


    files_to_move    : [dynamic]string,
    files_to_delete  : [dynamic]string,

    collection_names : [dynamic]string,
}

Transient :: struct {
    opt_level        : int,
    generate_debug   : bool,
    keep_temp_files  : bool,
    use_otime        : bool,

    collections      : [dynamic]Collection_Entry,
}

Collection_Entry :: struct {
    name : string,
    path : string,
}

execute_system_command :: proc(fmt_ : string, args : ...any) -> int {
    exit_code : u32;

    su := win32.Startup_Info{};
    su.cb = size_of(win32.Startup_Info);
    pi := win32.Process_Information{};
    cmd := fmt.aprintf(fmt_, ...args);
    
    if win32.create_process_a(nil, &cmd[0], nil, nil, false, 0, nil, nil, &su, &pi) {
        win32.wait_for_single_object(pi.process, win32.INFINITE);
        win32.get_exit_code_process(pi.process, &exit_code);
        win32.close_handle(pi.process);
        win32.close_handle(pi.thread);
    } else {
        fmt.printf("Failed to execute:\n\t%s\n", cmd);
        return -1;
    }
    

    return int(exit_code);
}

usage :: proc() {
    fmt.fprintf(os.stderr, "Odinbuilder %s by Mikkel Hjortshoej 2018\n", VERSION_STR);
    fmt.fprintf(os.stderr, "Available commands:\n");
    fmt.fprintf(os.stderr, "    setup                  - Use this in a directory setup the files structure for this system\n");
    fmt.fprintf(os.stderr, "    create                 - Create a build settings file and transient file\n");
    fmt.fprintf(os.stderr, "    edit                   - Open a GUI for editing the build-settings.cel\n");
    fmt.fprintf(os.stderr, "    build                  - Build project based on the settings set\n");
    fmt.fprintf(os.stderr, "    set <settings> <value> - Set a value in the build settings. Options;\n");
    fmt.fprintf(os.stderr, "                                 Opt - the optmization level for odin, must be 0, 1, 2 or 3\n");
    fmt.fprintf(os.stderr, "    toggle <settings>      - Toggle values in the build settings. Options;\n");
    fmt.fprintf(os.stderr, "                                 debug      - toggle wether or not to build .pdbs\n");
    fmt.fprintf(os.stderr, "                                 temp-files - toggle wether or not to keep temporary files\n");
}

SETTINGS_PATH  :: "settings.odbs";
TRANSIENT_PATH :: "transient.odbs";

main :: proc() {
    _fix := alloc(1);
    args := os.args[1..];
    argc := len(args);
    if argc == 0 {
        usage();
        os.exit(-1);
    }

    settings := Settings{};
    transient := Transient{};
    if args[0] == "create" {
        settings.app_name = "N/A";
        settings.main_file = "N/A";
        fmt.println("Creating settings.odbs and transient.odbs");
        cel.marshal_file(SETTINGS_PATH, settings);
        cel.marshal_file(TRANSIENT_PATH, transient);
        os.exit(0);
    }

    if !file.is_path_valid(SETTINGS_PATH) {
        fmt.println_err("could not find settings.odbs!");
        os.exit(-1);
    }

    if !file.is_path_valid(TRANSIENT_PATH) {
        fmt.println_err("could not find transiet.odbs, creating...");
        cel.marshal_file(TRANSIENT_PATH, transient);
    }

    ok := cel.unmarshal_file(SETTINGS_PATH, settings);
    if !ok {
        fmt.println_err("Can't parse settings.odbs");
        os.exit(-1);
    }

    ok = cel.unmarshal_file(TRANSIENT_PATH, transient);
    if !ok {
        fmt.println_err("Can't parse transient.odbs");
        os.exit(-1);
    } 

    for i := 0; i < argc; i += 1 {
        arg := args[i];
        switch arg {
            case "set" : {
                i += 1;
                value := args[i];
                switch value {
                    case "opt": {
                        i += 1;
                        level := strconv.parse_int(args[i]);
                        transient.opt_level = level;
                        fmt.printf("Opt level set to %d!\n", transient.opt_level);
                    }

                    case : {
                        fmt.fprintf(os.stderr, "Cannot set %s\n", value);
                    } 

                }
                cel.marshal_file(SETTINGS_PATH, transient);
            }

            case "toggle": {
                i += 1;
                value := args[i]; 
                switch value {
                    case "debug": {
                        transient.generate_debug = !transient.generate_debug;
                        fmt.printf("Now %sgenerating debug info!\n", transient.generate_debug ? "" : "not ");
                    }

                    case "temp-files": {
                        transient.keep_temp_files = !transient.keep_temp_files;
                        fmt.printf("Now %skeeping temp files!\n", transient.keep_temp_files ? "" : "not ");
                    }

                    case : {
                        fmt.fprintf(os.stderr, "Cannot toggle %s\n", value);
                    }
                }
                cel.marshal_file(SETTINGS_PATH, transient);
            }

            case "build" : build(&settings, &transient);

            case "setup" : {
                i += 1;
                name := args[i]; 
                setup(name, &settings);
                cel.marshal_file(SETTINGS_PATH, settings);
                cel.marshal_file(TRANSIENT_PATH, transient);
            }

            case "edit" : {
                gui(&settings, &transient);
            }

            case : {
                fmt.fprintf(os.stderr, "Invalid Command: %s\n", arg);
                usage();
                os.exit(-1);
            }
        }
    }
}

set_proc :: inline proc(lib_ : rawptr, p: rawptr, name: string) {
    lib := misc.LibHandle(lib_);
    res := wgl.get_proc_address(name);
    if res == nil {
        res = misc.get_proc_address(lib, name);
    }
    if res == nil {
        fmt.println("Couldn't load:", name);
    }

    (^rawptr)(p)^ = rawptr(res);
}

load_lib :: proc(str : string) -> rawptr {
    return rawptr(misc.load_library(str));
}

free_lib :: proc(lib : rawptr) {
    misc.free_library(misc.LibHandle(lib));
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

setup_window :: proc(w, h : int) -> window.WndHandle {
    app_handle := misc.get_app_handle();
    buf : [1024]byte;
    title := fmt.bprintf(buf[..], "Odin Builder %s", VERSION_STR);
    wnd_handle := window.create_window(app_handle, title, w, h, 
                                       window.Window_Style.NonresizeableWindow);
    gl_ctx     := wgl.create_gl_context(wnd_handle, 3, 3);

    gl.load_functions(set_proc, load_lib, free_lib);
    wgl.swap_interval(-1);
    gl.clear_color(0.10, 0.10, 0.10, 1);
    gl.viewport(0, 0, i32(w), i32(h));
    gl.scissor (0, 0, i32(w), i32(h));

    return wnd_handle;
}

gui :: proc(settings : ^Settings, transient : ^Transient) {
    WND_WIDTH  :: 500;
    WND_HEIGHT :: 600;

    wnd_handle := setup_window(WND_WIDTH, WND_HEIGHT);
    dear_state := new(imgui.State);
    imgui.init(dear_state, wnd_handle, style);
   
    
    time_data := misc.create_time_data();
    new_frame_state := imgui.FrameState{};
    new_frame_state.window_width  = WND_WIDTH;
    new_frame_state.window_height = WND_HEIGHT;
    new_frame_state.right_mouse = false;
    message := msg.Msg{};
    running := true;
    shift_down := false;
    dt := 0.0;

    main_file_buf : [1024]byte;
    app_name_buf  : [1024]byte;
    fmt.bprintf(main_file_buf[..], settings.main_file);
    fmt.bprintf(app_name_buf[..], settings.app_name);

    move_buf : [1024]byte;
    add_new_move := false;

    delete_buf : [1024]byte;
    add_new_delete := false;
    
    collection_name_buf : [1024]byte;
    collection_path_buf : [1024]byte;
    add_new_collection  := false;
    editing_collection  := false;
    editing_index       := -1;

    for running {
        new_frame_state.mouse_wheel = 0;

        for msg.poll_message(&message) {
            switch msg in message {
                case msg.MsgQuitMessage : {
                    running = false;
                }

                case msg.MsgChar : {
                    imgui.gui_io_add_input_character(u16(msg.char));
                }

                case msg.MsgKey : {
                    switch msg.key {
                        case keys.VirtualKey.Escape : {
                            if msg.down == true && shift_down {
                                running = false;
                            }
                        }

                        case keys.VirtualKey.Lshift : {
                            shift_down = msg.down;
                        }
                    }
                }

                case msg.MsgMouseButton : {
                    switch msg.key {
                        case keys.VirtualKey.LMouse : {
                            new_frame_state.left_mouse = msg.down;
                        }

                        case keys.VirtualKey.RMouse : {
                            new_frame_state.right_mouse = msg.down;
                        }
                    }
                }

                case msg.MsgWindowFocus : {
                    new_frame_state.window_focus = msg.enter_focus;
                }

                case msg.MsgMouseMove : {
                    new_frame_state.mouse_x = msg.x;
                    new_frame_state.mouse_y = msg.y;
                }

                case msg.MsgMouseWheel : {
                    new_frame_state.mouse_wheel = msg.distance;
                }
            }
        }

        dt = misc.time(&time_data);
        new_frame_state.deltatime     = f32(dt);

        gl.clear(gl.ClearFlags.COLOR_BUFFER | gl.ClearFlags.DEPTH_BUFFER);
        imgui.begin_new_frame(&new_frame_state);
        {
            imgui.set_next_window_pos(imgui.Vec2{0,0}, imgui.Set_Cond.Once);
            imgui.set_next_window_size(imgui.Vec2{WND_WIDTH, WND_HEIGHT}, imgui.Set_Cond.Once);
            imgui.begin("main", nil, imgui.Window_Flags.NoTitleBar |
                                     imgui.Window_Flags.NoResize |
                                     imgui.Window_Flags.NoCollapse | 
                                     imgui.Window_Flags.NoMove);


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
            if imgui.input_text("Main File Location", main_file_buf[..]) {
                settings.main_file = string_util.str_from_buf(main_file_buf[..]);
                cel.marshal_file(SETTINGS_PATH, settings^);
            }
            if imgui.input_text("App Name", app_name_buf[..]) {
                settings.app_name = string_util.str_from_buf(app_name_buf[..]);
                cel.marshal_file(SETTINGS_PATH, settings^);
            }
            if imgui.checkbox("Use Otime?", &transient.use_otime) {
                cel.marshal_file(TRANSIENT_PATH, transient^);
            }

            imgui.text("Files to move after building.");
            index_to_remove := -1;
            if imgui.begin_child("move files", imgui.Vec2{0, 125}) {
                for file, i in settings.files_to_move {
                    imgui.push_id(i); defer imgui.pop_id();
                    imgui.text(file); imgui.same_line();
                    if imgui.button("Remove") {
                        index_to_remove = i;
                    }
                }

                if !add_new_move && imgui.button("Add file##move") {
                    add_new_move = true;
                }
                if add_new_move {
                    imgui.input_text("File Name##move", move_buf[..]); imgui.same_line();
                    if imgui.button("Save##move") {
                        add_new_move = false;
                        tmp := string_util.str_from_buf(move_buf[..]);
                        str := strings.new_string(tmp);
                        append(&settings.files_to_move, str);
                        mem.zero(&move_buf[0], len(move_buf));
                        cel.marshal_file(SETTINGS_PATH, settings^);
                    }
                    imgui.same_line();
                    if imgui.button("Cancel##move") {
                        add_new_move = false;
                        mem.zero(&move_buf[0], len(move_buf));
                    }
                } 
            }
            imgui.end_child();
            
            if index_to_remove > -1 {
                dyna_util.remove_ordered(&settings.files_to_move, index_to_remove);
                cel.marshal_file(SETTINGS_PATH, settings^);
            }

            imgui.text("Files to delete after building.");
            index_to_remove = -1;
            if imgui.begin_child("delete files", imgui.Vec2{0, 125}) {
                for file, i in settings.files_to_delete {
                    imgui.push_id(i); defer imgui.pop_id();
                    imgui.text(file); imgui.same_line();
                    if imgui.button("Remove") {
                        index_to_remove = i;
                    }
                }

                if !add_new_delete && imgui.button("Add file##delete") {
                    add_new_delete = true;
                }
                if add_new_delete {
                    imgui.input_text("File Name##delete", delete_buf[..]); imgui.same_line();
                    if imgui.button("Save##delete") {
                        add_new_delete = false;
                        tmp := string_util.str_from_buf(delete_buf[..]);
                        str := strings.new_string(tmp);
                        append(&settings.files_to_delete, str);
                        mem.zero(&delete_buf[0], len(delete_buf));
                        cel.marshal_file(SETTINGS_PATH, settings^);
                    }
                    imgui.same_line();
                    if imgui.button("Cancel##delete") {
                        add_new_delete = false;
                        mem.zero(&delete_buf[0], len(delete_buf));
                    }
                } 
            }
            imgui.end_child();

            if index_to_remove > -1 {
                dyna_util.remove_ordered(&settings.files_to_delete, index_to_remove);
                cel.marshal_file(SETTINGS_PATH, settings^);
            }

            imgui.text("Collections.");
            index_to_remove = -1;
            if imgui.begin_child("Collections") {
                imgui.columns(count = 2, border = false);
                for col_name, i in settings.collection_names {
                    if i == editing_index do continue;
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
                        editing_index = i;;
                        fmt.bprintf(collection_name_buf[..], col_name);
                        if len(collection.path) > 0 {
                            fmt.bprintf(collection_path_buf[..], collection.path);
                        }
                        editing_collection = true;
                    } imgui.same_line();

                    if imgui.button("Remove") {
                        index_to_remove = i;
                    }
                    imgui.next_column();
                }
                imgui.columns_reset();

                if editing_collection {
                    imgui.input_text("Name##collection", collection_name_buf[..]); 
                    imgui.input_text("Path##collection", collection_path_buf[..]);

                    if imgui.button("Save##edit_collection") {
                        editing_collection = false;

                        new_name := string_util.str_from_buf(collection_name_buf[..]);
                        col_name := settings.collection_names[editing_index];

                        if new_name != col_name {
                            settings.collection_names[editing_index] = strings.new_string(new_name);
                        }

                        path := string_util.str_from_buf(collection_path_buf[..]);
                        if new_name != col_name {
                            remove_i := -1; 
                            for old, i in transient.collections {
                                if old.name == col_name {
                                    remove_i = i;
                                }
                            }
                            
                            if index_to_remove > -1 {
                                dyna_util.remove_ordered(&transient.collections, remove_i);
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

                        mem.zero(&collection_name_buf[0], len(collection_name_buf));
                        mem.zero(&collection_path_buf[0], len(collection_path_buf));
                        editing_index = -1;
                        cel.marshal_file(SETTINGS_PATH, settings^);
                        cel.marshal_file(TRANSIENT_PATH, transient^);
                    }
                    imgui.same_line();
                    if imgui.button("Cancel##edit_collection") {
                        editing_collection = false;
                        mem.zero(&collection_name_buf[0], len(collection_name_buf));
                        mem.zero(&collection_path_buf[0], len(collection_path_buf));
                        editing_index = -1;
                    }
                }

                if !add_new_collection && imgui.button("Add collection") {
                    add_new_collection = true;
                }

                if add_new_collection {
                    imgui.input_text("Name##collection", collection_name_buf[..]); 
                    imgui.input_text("Path##collection", collection_path_buf[..]);

                    if imgui.button("Save##collection") {
                        add_new_collection = false;
                        
                        tmp  := string_util.str_from_buf(collection_name_buf[..]);
                        name := strings.new_string(tmp);
                        append(&settings.collection_names, name);
                        
                        tmp   = string_util.str_from_buf(collection_path_buf[..]);
                        if len(tmp) > 0 {
                            path := strings.new_string(tmp);
                            append(&transient.collections, Collection_Entry{name, path});
                        }

                        mem.zero(&collection_name_buf[0], len(collection_name_buf));
                        mem.zero(&collection_path_buf[0], len(collection_path_buf));

                        cel.marshal_file(SETTINGS_PATH, settings^);
                        cel.marshal_file(TRANSIENT_PATH, transient^);
                    }
                    imgui.same_line();
                    if imgui.button("Cancel##collection") {
                        add_new_collection = false;
                        mem.zero(&collection_name_buf[0], len(collection_name_buf));
                        mem.zero(&collection_path_buf[0], len(collection_path_buf));
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

                dyna_util.remove_ordered(&settings.collection_names, index_to_remove);
                dyna_util.remove_ordered(&transient.collections,     remove_i);
                cel.marshal_file(SETTINGS_PATH,  settings^);
                cel.marshal_file(TRANSIENT_PATH, transient^);
            }

        }
        imgui.end();
        imgui.render_proc(dear_state, true, WND_WIDTH, WND_HEIGHT);
        window.swap_buffers(wnd_handle);
    }
}

build :: proc(settings : ^Settings, transient : ^Transient) {
    if len(settings.collection_names) != len(transient.collections) {
        fmt.println_err("You're missing some collection paths");
        return;
    }

    fmt.printf("Building %s", settings.main_file);
    if transient.opt_level != 0 {
        fmt.printf(" on opt level %d", transient.opt_level);
    }
    if transient.generate_debug {
        fmt.print(" with debug info");
    }
    if transient.keep_temp_files {
        fmt.print(" and keeping temp files");
    }
    fmt.print("\n");
    if transient.use_otime do execute_system_command("otime -begin %s.otm", settings.app_name);

    collection_string := "";

    buf        : [4096]byte;
    buf_offset := 0;
    for col_name in settings.collection_names {
        for col in transient.collections {
            if col.name == col_name {
                str := fmt.bprintf(buf[buf_offset..], "-collection=%s=%s ", col.name, col.path);
                buf_offset += len(str);
            }
        }
    }

    if len(settings.collection_names) > 0 {
        collection_string = string_util.str_from_buf(buf[..]);
    }

    exit_code := execute_system_command("odin build %s -opt=%d %s %s %s", 
                                        settings.main_file,
                                        transient.opt_level,
                                        transient.generate_debug ? "-debug" : "",
                                        transient.keep_temp_files ? "-keep-temp-files" : "",
                                        collection_string);
    move :: proc(e, n : string) -> bool {
        return cast(bool)win32.move_file_ex_a(&e[0], &n[0], win32.MOVEFILE_REPLACE_EXISTING | win32.MOVEFILE_WRITE_THROUGH | win32.MOVEFILE_COPY_ALLOWED);
    }
    copy :: proc(e, n : string, f : bool) -> bool {
        return cast(bool)win32.copy_file_a(&e[0], &n[0], cast(win32.Bool)f);
    }

    if exit_code == 0 {
        file_name := settings.main_file[..len(settings.main_file)-5];
        e_buf : [2048]byte;
        n_buf : [2048]byte;
        ok := move(fmt.bprintf(e_buf[..], "%s.exe\x00", file_name),
                   fmt.bprintf(n_buf[..], "build/%s.exe\x00", settings.app_name));
        if ok {
            fmt.println("Moved executable.");
        } else {
            fmt.println_err("Could not move executable!");
        }
        if transient.generate_debug {
            ok = move(fmt.bprintf(e_buf[..], "%s.pdb\x00", file_name),
                      fmt.bprintf(n_buf[..], "build/%s.pdb\x00", string_util.remove_path_from_file(file_name)));
            if ok {
                fmt.println("Moved pdb.");
            } else {
                fmt.println_err("Could not move pdb!");
            }
        }
        success := 0;
        for str in settings.files_to_move {
            ok = copy(fmt.bprintf(e_buf[..], "%s\x00", str),
                      fmt.bprintf(n_buf[..], "build/%s\x00", string_util.remove_path_from_file(str)),
                      false);
            if !ok {
                fmt.fprintf(os.stderr, "Could not move %s\n", str);            
            } else {
                success += 1;
            }
        }
        if len(settings.files_to_move) > 0 && success > 0 {
            fmt.println("Done moving extra files.");
        }

        for str in settings.files_to_delete {
            cstr := fmt.bprintf(e_buf[..], "%s\x00", str);
            ok := win32.delete_file_a(&cstr[0]);
            if !ok {
                ERROR_FILE_NOT_FOUND :: 2;
                err := win32.get_last_error();
                if err != ERROR_FILE_NOT_FOUND {
                    fmt.fprintf(os.stderr, "Could not delete %s\n", str);
                }
            }
        }

        fmt.println("Done Building!");
    } else {
        fmt.println("Build Failed!");
    }

    if transient.use_otime do execute_system_command("otime -end %s.otm %d", settings.app_name, exit_code);
}

setup :: proc(app_name : string, settings : ^Settings) {
    settings.app_name = app_name;
    settings.main_file = "src/main.odin";
    
    create_dir :: proc(name : string) {
        win32.create_directory_a(&name[0], nil);
    }
    create_dir("build");
    create_dir("src");
    create_dir("misc");
    create_misc_files();
    create_dir("run_tree");
    create_run(settings.app_name);
    create_sublime_project(settings.app_name);

    h, ok := os.open(settings.main_file, os.O_CREATE);
    if ok != os.ERROR_NONE {
        fmt.println_err(ok);
        fmt.println_err("Could not create main.odin");
    }
    os.close(h);
}

create_run :: proc(name : string) {
    tmpl := `
@echo off
pushd run_tree
..\build\%s.exe build
popd`;
    actual := fmt.aprintf(tmpl, name); defer free(actual);
    os.write_entire_file("run.bat", cast([]byte)actual);

}

create_sublime_project :: proc(name : string) {
    tmpl := `
{
    "folders":
    [
        {
            "name": "%s: Source",
            "path": "./src",
            "file_exclude_patterns": [ "*.ll", "*.bc" ],
        },
        {
            "name": "%s: Main",
            "path": ".",
            "file_exclude_patterns": [ "nohup.out", "*.ll", "*.bc", "*.otm" ],
            "folder_exclude_patterns": [ "build", "src"],
        },
        {
            "name": "%s: Build",
            "path": "./build",
            "folder_exclude_patterns": [ ".vs"],
        },
        {
            "name": "Shared",
            "path": "E:/Odin/Shared",
        },
        {
            "name": "Odin Compiler: Core",
            "path": "../../Odin/core",
        },
    ]
}`;

    actual := fmt.aprintf(tmpl, name, name, name); defer free(actual);
    os.write_entire_file("subl-proj.sublime-project", cast([]byte)actual);
}

create_misc_files :: proc() {
    dev_data := "#!/bin/bash\nnohup sublime_text.exe ../subl-proj.sublime-project &";
    os.write_entire_file("misc/dev.sh", cast([]byte)dev_data);

    loc_data := "#!/bin/bash\nfind ../src/ -name '*.odin' | xargs wc -l";
    os.write_entire_file("misc/loc.sh", cast([]byte)dev_data);

    dbg_data := "#!/bin/bash\ncd ../build\nnohup devenv.exe main.sln &";
    os.write_entire_file("misc/dbg.sh", cast([]byte)dbg_data);
}
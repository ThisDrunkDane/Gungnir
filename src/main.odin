/*
 *  @Name:     main
 *  
 *  @Author:   Mikkel Hjortshoej
 *  @Email:    hoej@northwolfprod.com
 *  @Creation: 24-01-2018 04:24:11 UTC+1
 *
 *  @Last By:   Mikkel Hjortshoej
 *  @Last Time: 24-01-2018 07:04:15 UTC+1
 *  
 *  @Description:
 *  
 */

import       "core:fmt.odin";
import       "core:utf16.odin";
import       "core:os.odin";
import       "core:strconv.odin";
import win32 "core:sys/windows.odin";

import "shared:libbrew/cel.odin";
import "shared:libbrew/string_util.odin";
import "shared:libbrew/win/file.odin";

Settings :: struct {
    opt_level       : int,
    generate_debug  : bool,
    keep_temp_files : bool,
    main_file       : string,
    app_name        : string,
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
    fmt.println("USAGE");
}

main :: proc() {
    settings := Settings{};
    settings_path := "build-settings.cel";
    if !file.does_file_or_dir_exists(settings_path) {
        fmt.println_err("settings.cel does not exist, creating...");
        cel.marshal_file(settings_path, settings);
    }

    ok := cel.unmarshal_file(settings_path, settings);
    if !ok {
        fmt.println_err("Can't parse settings.cel");
        return;
    }

    args := os.args[1..];
    argc := len(args);
    if argc == 0 {
        usage();
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
                        settings.opt_level = level;
                        fmt.printf("Opt level set to %d!\n", settings.opt_level);
                    }

                    case : {
                        fmt.fprintf(os.stderr, "Cannot set %s\n", value);
                    } 

                }
                cel.marshal_file(settings_path, settings);
            }
            case "toggle": 
                i += 1;
                value := args[i]; 
                switch value {
                    case "debug": {
                        settings.generate_debug = !settings.generate_debug;
                        fmt.printf("Now %sgenerating debug info!\n", settings.generate_debug ? "" : "not ");
                    }

                    case "temp-files": {
                        settings.keep_temp_files = !settings.keep_temp_files;
                        fmt.printf("Now %skeeping temp files!\n", settings.keep_temp_files ? "" : "not ");
                    }

                    case : {
                        fmt.fprintf(os.stderr, "Cannot toggle %s\n", value);
                    }
                }
                cel.marshal_file(settings_path, settings);

            case "build" : 
                build(&settings);
                cel.marshal_file(settings_path, settings);

            case "setup" : 
                i += 1;
                name := args[i]; 
                setup(name, &settings);
                cel.marshal_file(settings_path, settings);

            case : 
                fmt.fprintf(os.stderr, "Invalid Command: %s\n", arg);
                usage();
                os.exit(-1);
        }
    }
}

build :: proc(settings : ^Settings) {
    fmt.printf("Building %s", settings.main_file);
    if settings.opt_level != 0 {
        fmt.printf(" on opt level %d", settings.opt_level);
    }
    if settings.generate_debug {
        fmt.print(" with debug info");
    }
    if settings.keep_temp_files {
        fmt.print(" and keeping temp files");
    }
    fmt.print("\n");
    execute_system_command("otime -begin %s.otm", settings.app_name);
    exit_code := execute_system_command("odin build %s -opt=%d %s %s", 
                                        settings.main_file,
                                        settings.opt_level,
                                        settings.generate_debug ? "-debug" : "",
                                        settings.keep_temp_files ? "-keep-temp-files" : "");
    move :: proc(e, n : string) -> bool {
        return cast(bool)win32.move_file_ex_a(&e[0], &n[0], win32.MOVEFILE_REPLACE_EXISTING | win32.MOVEFILE_WRITE_THROUGH | win32.MOVEFILE_COPY_ALLOWED);
    }

    if exit_code == 0 {
        file_name := settings.main_file[..len(settings.main_file)-5];
        e_buf : [2048]byte;
        n_buf : [2048]byte;
        ok := move(fmt.bprintf(e_buf[..], "%s.exe", file_name),
                   fmt.bprintf(n_buf[..], "build/%s.exe", settings.app_name));
        if ok {
            fmt.println("Moved executable.");
        } else {
            fmt.println_err("Could not move executable!");
        }
        if settings.generate_debug {
            ok = move(fmt.bprintf(e_buf[..], "%s.pdb", file_name),
                      fmt.bprintf(n_buf[..], "build/%s.pdb", string_util.remove_path_from_file(file_name)));
            if ok {
                fmt.println("Moved pdb.");
            } else {
                fmt.println_err("Could not move pdb!");
            }
        }

        fmt.println("Done Building!");
    } else {
        fmt.println("Build Failed!");
    }

    execute_system_command("otime -end %s.otm %d", settings.app_name, exit_code);
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
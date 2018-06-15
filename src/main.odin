/*
 *  @Name:     main
 *  
 *  @Author:   Mikkel Hjortshoej
 *  @Email:    hoej@northwolfprod.com
 *  @Creation: 24-01-2018 04:24:11 UTC+1
 *
 *  @Last By:   Mikkel Hjortshoej
 *  @Last Time: 16-06-2018 00:39:45 UTC+1
 *  
 *  @Description:
 *      Main file for Gungnir
 */

package main;

import "core:fmt";
import "core:unicode/utf16";
import "core:os";
import "core:strings";
import "core:mem";
import "core:strconv";

import sys  "shared:libbrew/sys";
import cel  "shared:odin-cel";
import util "shared:libbrew/util";

VERSION_STR :: "v1.4.0-dev";

usage :: proc() {
    fmt.fprintf(os.stderr, "Gungnir %s by Mikkel Hjortshoej 2018\n", VERSION_STR);
    fmt.fprintf(os.stderr, "Available commands:\n");
    fmt.fprintf(os.stderr, "    create                 - Create a build settings file and transient file\n");
    fmt.fprintf(os.stderr, "    edit                   - Open a GUI for editing the build-settings.cel\n");
    fmt.fprintf(os.stderr, "    check                  - Check project based on the settings set\n");
    fmt.fprintf(os.stderr, "    build                  - Build project based on the settings set\n");
    fmt.fprintf(os.stderr, "    set <settings> <value> - Set a value in the build settings. Options;\n");
    fmt.fprintf(os.stderr, "                                 Opt - the optmization level for odin, must be 0, 1, 2 or 3\n");
    fmt.fprintf(os.stderr, "    toggle <settings>      - Toggle values in the build settings. Options;\n");
    fmt.fprintf(os.stderr, "                                 debug      - toggle wether or not to build .pdbs\n");
    fmt.fprintf(os.stderr, "                                 temp-files - toggle wether or not to keep temporary files\n");
}

main :: proc() {
    args := os.args[1..];
    argc := len(args);
    if argc == 0 {
        usage();
        os.exit(-1);
    }

    settings  := Settings{};
    transient := Transient{};

    if args[0] == "create" {
        settings.app_name = "main";
        settings.main_file = "src/main.odin";
        transient.otime_file = settings.app_name;
        fmt.println("Creating settings.odbs and transient.odbs");
        cel.marshal_file(SETTINGS_PATH, settings);
        cel.marshal_file(TRANSIENT_PATH, transient);
        os.exit(0);
    }

    if !sys.is_path_valid(SETTINGS_PATH) {
        fmt.println_err("No settings.odbs found! Please run 'create' before using Gungir...");
        os.exit(-1);
    }

    if !sys.is_path_valid(TRANSIENT_PATH) {
        fmt.println_err("Could not find transient.odbs, creating...");
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
                cel.marshal_file(TRANSIENT_PATH, transient);
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
                        fmt.fprintf(os.stderr, "%s is not a recoginzed toogleable setting!\n", value);
                    }
                }
                cel.marshal_file(TRANSIENT_PATH, transient);
            }

            case "build" : build(&settings, &transient, true);
            case "check" : build(&settings, &transient, false);

            case "edit" : {
                gui_run(&settings, &transient);
            }

            case "add" : {
                fmt.fprintln(os.stderr, "Adding packages are not implemented yet...");
                usage();
                os.exit(-1);

                i += 1;
                value := args[i];
                if(value == "package") {
                    i += 1;
                    pkg_name := args[i];
                } else {
                    fmt.fprintf(os.stderr, "Adding %s is not supported...\n", value);
                    usage();
                    os.exit(-1);
                }
            }

            case : {
                fmt.fprintf(os.stderr, "Invalid Command: %s\n", arg);
                usage();
                os.exit(-1);
            }
        }
    }
}

Otime_Usage :: enum {
    Begin,
    End
}

do_otime :: proc(settings : ^Settings, transient : ^Transient, usage : Otime_Usage, exit_code := 0) {
    switch usage {
        case Otime_Usage.Begin : sys.execute_system_command("otime -begin %s.otm",  transient.otime_file);
        case Otime_Usage.End   : sys.execute_system_command("otime -end %s.otm %d", transient.otime_file, exit_code);
    }
}

build :: proc(settings : ^Settings, transient : ^Transient, true_build : bool) {
    if len(settings.collection_names) != len(transient.collections) {
        fmt.println_err("You're missing setting some collection paths");
        return;
    }

    if !sys.is_path_valid("build") {
        fmt.println_err("build directory does not exist! Creating...");
        sys.create_directory("build");
    }

    fmt.printf("%s %s", true_build ? "Building" : "Checking", settings.main_file);
    if true_build {
        if transient.opt_level != 0 {
            fmt.printf(" on opt level %d", transient.opt_level);
        }
        if transient.generate_debug {
            fmt.print(" with debug info");
        }
        if transient.keep_temp_files {
            fmt.print(" and keeping temp files");
        }
        if transient.use_otime {
            do_otime(settings, transient, Otime_Usage.Begin);
        }
    }
    fmt.print("\n");
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
        collection_string = util.str_from_buf(buf[..]);
    }

    resource_string := "";
    if settings.use_resource {
        resource_string = fmt.aprintf("-resource=%s", settings.resource_path);
    }

    exit_code := sys.execute_system_command("odin %s %s -opt=%d %s %s -out=build/%s %s %s", 
                                        true_build ? "build" : "check",
                                        settings.main_file,
                                        transient.opt_level,
                                        transient.generate_debug ? "-debug" : "",
                                        transient.keep_temp_files ? "-keep-temp-files" : "",
                                        settings.app_name,
                                        collection_string,
                                        resource_string);

    if(!true_build) {
        fmt.println("Done Checking!");
        return;
    }

    if exit_code == 0 {
        e_buf : [2048]byte;
        n_buf : [2048]byte;

        success := 0;
        for str in settings.files_to_move {
            ok := sys.copy_file(str,
                      fmt.bprintf(n_buf[..], "build/%s", util.remove_path_from_file(str)),
                      true);
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
            if(!sys.is_path_valid(str)) {
                continue;
            }
            ok := sys.delete_file(str);
            if !ok {
                fmt.fprintf(os.stderr, "Could not delete %s\n", str);
            }
        }

        fmt.println("Done Building!");
    } else {
        fmt.println("Build Failed!");
    }

    if transient.use_otime {
        do_otime(settings, transient, Otime_Usage.Begin, exit_code);
    }
}
/*
 *  @Name:     state
 *  
 *  @Author:   Mikkel Hjortshoej
 *  @Email:    fyoucon@gmail.com
 *  @Creation: 21-05-2018 16:05:04 UTC+1
 *
 *  @Last By:   Mikkel Hjortshoej
 *  @Last Time: 15-06-2018 19:19:14 UTC+1
 *  
 *  @Description:
 *  
 */

package main;

SETTINGS_PATH  :: "settings.odbs";
TRANSIENT_PATH :: "transient.odbs";

Settings :: struct {
    main_file        : string,
    app_name         : string,
    use_resource     : bool,
    resource_path    : string,

    files_to_move    : [dynamic]string,
    files_to_delete  : [dynamic]string,

    collection_names : [dynamic]string,
}

Transient :: struct {
    opt_level        : int,
    generate_debug   : bool,
    keep_temp_files  : bool,
    use_otime        : bool,
    otime_use_app    : bool,
    otime_file       : string,

    collections      : [dynamic]Collection_Entry,
}

Collection_Entry :: struct {
    name : string,
    path : string,
}

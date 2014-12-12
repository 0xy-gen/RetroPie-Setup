#!/usr/bin/env bash

#
#  (c) Copyright 2012-2014  Florian Müller (contact@petrockblock.com)
#
#  RetroPie-Setup homepage: https://github.com/petrockblog/RetroPie-Setup
#
#  Permission to use, copy, modify and distribute this work in both binary and
#  source form, for non-commercial purposes, is hereby granted without fee,
#  providing that this license information and copyright notice appear with
#  all copies and any derived work.
#
#  This software is provided 'as-is', without any express or implied
#  warranty. In no event shall the authors be held liable for any damages
#  arising from the use of this software.
#
#  RetroPie-Setup is freeware for PERSONAL USE only. Commercial users should
#  seek permission of the copyright holders first. Commercial use includes
#  charging money for RetroPie-Setup or software derived from RetroPie-Setup.
#
#  The copyright holders request that bug fixes and improvements to the code
#  should be forwarded to them so everyone can benefit from the modifications
#  in future versions.
#
#  Many, many thanks go to all people that provide the individual packages!!!
#

__mod_idx=()
__mod_id=()
__mod_desc=()
__mod_type=()
__mod_menus=()
__doPackages=0

# params: $1=index, $2=id, $3=description, $4=menus
function rp_registerFunction() {
    __mod_idx+=($1)
    __mod_id[$1]=$2
    __mod_desc[$1]=$3
    __mod_menus[$1]=$4
    __mod_type[$1]=$5
}

function rp_listFunctions() {
    local idx
    local mod_id
    local desc
    local mode
    local func

    echo -e "Index/ID:                 Description:                       List of available actions [sources|build|install|configure|package]"
    echo "-----------------------------------------------------------------------------------------------------------------------------------"
    echo ${__mod_id[1]}
    for (( i = 0; i < ${#__mod_idx[@]}; i++ )); do
        idx=${__mod_idx[$i]};
        mod_id=${__mod_id[$idx]};
        printf "%d/%-20s: %-32s : " "$idx" "$mod_id" "${__mod_desc[$idx]}"
        for mode in depends sources build install configure remove; do
            func="${mode}_${mod_id}"
            fn_exists $func && echo -e "$mode \c"
        done
        echo ""
    done
    echo "==================================================================================================================================="
}

function rp_printUsageinfo() {
    echo -e "Usage:\n$0 <Index # or ID>\nThis will run the actions depends, sources, build, install, configure, package and remove automatically.\n"
    echo -e "Alternatively, $0 can be called as\n$0 <Index # or ID [depends|sources|build|install|configure|package|remove]\n"
    echo -e "This is a list of valid commands:\n"
    rp_listFunctions
}

function rp_callModule() {
    local idx="$1"
    local func="$2"
    local type="$3"
    local desc
    local mod_id
    local mode

    if [[ "$func" == "" ]]; then
        for mode in depends sources build install configure; do
            rp_callModule $idx $mode
        done
    fi
    
    # if index get mod_id from ass array
    if [[ "$idx" =~ ^[0-9]+$ ]]; then
        mod_id=${__mod_id[$1]}
    else
        mod_id="$idx"
        for idx in "${!__mod_id[@]}"; do
            [[ "$mod_id" == "${__mod_id[$idx]}" ]] && break 
        done
    fi

    # create function name and check if it exists
    func_call="${func}_${mod_id}"
    fn_exists $func_call || return

    # create variables that can be used in modules
    local md_id="$mod_id"
    local md_desc="${__mod_desc[$idx]}"
    local md_type="$type"
    local md_build="$builddir/$mod_id"
    local md_inst="$rootdir/$type/$mod_id"

    case "$func" in
        depends)
            desc="Installing dependencies for"
            ;;
        sources)
            desc="Getting sources for"
            rmDirExists "$md_build"
            mkdir -p "$md_build"
            pushd "$md_build"
            ;;
        build)
            desc="Building"
            pushd "$md_build"
            ;;
        install)
            desc="Installing"
            mkdir -p "$md_build" "$md_inst" 
            pushd "$md_build"
            ;;
        configure)
            desc="Configuring"
            pushd "$md_inst"
            ;;
        remove)
            desc="Removing"
            ;;
    esac

    printMsg "$desc ${__mod_desc[$idx]}"
    require=""
    files=""
    $func_call

    if [ "$require" != "" ] && [ ! -f "$require" ]; then
        __ERRMSGS="$__ERRMSGS Could not successfully $func ${__mod_desc[$idx]} ($require not found)."
    fi

    if [ "$files" != "" ]; then
        for file in "${files[@]}"; do
            if [ ! -e "$builddir/$mod_id/$file" ]; then
                __ERRMSGS+="$__ERRMSGS Could not successfully install ${__mod_desc[$idx]} ($builddir/$mod_id/$file not found)."
                break
            fi
            cp -Rv "$builddir/$mod_id/$file" "$emudir/$mod_id"
        done
    fi

    case "$func" in
        sources|build|install|configure)
            popd
            ;;
    esac
}

function registerModule() {
    local module_idx="$1"
    local module_path="$2"
    local module_type="$3"
    local rp_module_id=""
    local rp_module_desc=""
    local rp_module_menus=""
    local var
    local error=0
    source $module_path
    for var in rp_module_id rp_module_desc rp_module_menus; do
        if [[ "${!var}" == "" ]]; then
            echo "Module $module_path is missing valid $var"
            error=1
        fi
    done
    [[ $error -eq 1 ]] && exit 1
    rp_registerFunction "$module_idx" "$rp_module_id" "$rp_module_desc" "$rp_module_menus" "$module_type"
}

function registerModuleDir() {
    local module_idx="$1"
    local module_dir="$2"
    for module in `find "$scriptdir/scriptmodules/$2" -maxdepth 1 -name "*.sh" | sort`; do
        registerModule $module_idx "$module" "$module_dir"
        ((module_idx++))
    done
}

function registerAllModules() {
    registerModuleDir 100 "emulators" 
    registerModuleDir 200 "libretrocores" 
    registerModuleDir 300 "supplementary"
}
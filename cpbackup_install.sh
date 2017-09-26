#!/usr/bin/env bash

function get_module_dir() {
    local -a module_paths=( $(perl -e 'print join " ", @INC;') )
    local module_dir
    for each in ${module_paths[@]}
    do
        [[ -d ${each} && -O ${each} && -G ${each} ]] && {
            module_dir=${each}
            break
        }
    done
    unset each
    printf "%s" "${module_dir}"
}

function __install() {
    local url="${1}"; shift
    local path="${1}"
    curl -s --url ${url} -o ${path}
}

function install_cpanel_auto_backup() {
    local -A installation=(
        ['script_url']='https://raw.githubusercontent.com/PlasticVader/cPanelAutoBackup/master/cpbackup.pl'
        ['module_url']='https://raw.githubusercontent.com/PlasticVader/cPanelAutoBackup/master/AutoBackup.pm'
        ['script_path']="$HOME/cPanelAutoBackup/cpbackup.pl"
        ['module_path']="$(get_module_dir)/AutoBackup.pm"
    )
    local installdir=${installation[script_path]%/*}

    [[ ! -d ${installdir} ]] && {
        mkdir ${installdir}
    }

    __install ${installation[module_url]} ${installation[module_path]}
    __install ${installation[script_url]} ${installation[script_path]}
}

install_cpanel_auto_backup

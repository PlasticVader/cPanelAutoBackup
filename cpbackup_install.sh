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
    printf "%s" "${module_dir}/AutoBackup.pm"
}

function __download() {
    local url="${1}"; shift
    local path="${1}"
    curl -s --url ${url} -o ${path}
}

function check_cpanel_auto_backup() {
    local module_path=$(find $HOME -type f -name "AutoBackup.pm")
    [[ -f ${module_path} ]] && {
        printf "%s" "${module_path}"
    } || {
        printf "%d" "1"
    }
}

function install_cpanel_auto_backup() {
    local -A installation=(
        ['script_url']='https://raw.githubusercontent.com/PlasticVader/cPanelAutoBackup/master/cpbackup.pl'
        ['module_url']='https://raw.githubusercontent.com/PlasticVader/cPanelAutoBackup/master/AutoBackup.pm'
        ['script_path']="$HOME/cPanelAutoBackup/cpbackup.pl"
    )

    local module_path=$(check_cpanel_auto_backup)

    [[ ${module_path} != '1' ]] && {
        installation[module_path]=${module_path}
    } || {
        installation[module_path]=$(get_module_dir)
    }

    local installdir=${installation[script_path]%/*}
    local backupdir=${installdir}/backups

    [[ ! -d ${installdir} ]] && {
        mkdir ${installdir}
    }

    [[ ! -d ${backupdir} ]] && {
        mkdir ${backupdir}
    }

    __download ${installation[module_url]} ${installation[module_path]}
    __download ${installation[script_url]} ${installation[script_path]}
}

install_cpanel_auto_backup

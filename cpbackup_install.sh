#!/usr/bin/env bash

_thisfile="$0"

trap "__finish $_thisfile" EXIT

function __finish() {
    local file="${1}"
    shred -u "${file}"
}

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
    local module_path=$(find $HOME -type f -name "AutoBackup.pm" 2>/dev/null)
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

    local format='%s\n'
    local mode='installation'

    local module_path=$(check_cpanel_auto_backup)
    printf "${format}" "Checking whether the module has been already installed..."

    [[ ${module_path} != '1' ]] && {
        installation[module_path]=${module_path}
        printf "${format}" "Module already present, path to the INC has been defined, will perform an update..."
        mode='update'
    } || {
        installation[module_path]=$(get_module_dir)
        printf "${format}" "Module has not been installed yet, checking Perl INC array, defining module path..."
    }

    local  installdir=${installation[script_path]%/*}
    local config_file=${installdir}/.cpbackup.conf
    local   backupdir=${installdir}/backups
    printf "${format}" "Preparing the ${mode}..."

    [[ ! -d ${installdir} ]] && {
        printf "${format}" "The installation directory does not exist, creating [ ${installdir} ]..."
        mkdir -m 755 ${installdir}
    }

    [[ ! -d ${backupdir} ]] && {
        printf "${format}" "The default backup directory does not exist, creating [ ${backupdir} ]..."
        mkdir -m 755 ${backupdir}
    }

    [[ ! -f ${config_file} ]] && {
        printf "${format}" "The configuration file does not exist, creating [ ${config_file} ]..."
        cat /dev/null >${config_file}
        chmod 600 ${config_file}
    }

    printf "${format}" "Downloading the module [ ${installation[module_url]} ] to [ ${installation[module_path]} ]..."
    __download ${installation[module_url]} ${installation[module_path]}
    printf "${format}" "Downloading the script [ ${installation[script_url]} ] to [ ${installation[script_path]} ]..."
    __download ${installation[script_url]} ${installation[script_path]}

    printf "${format}" "The ${mode} has been successfully finished!"
}

install_cpanel_auto_backup

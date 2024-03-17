#!/usr/bin/env bash
# Cf. fix-hostfiles-sh.1 manpage for detail. 

# Globals
DNS_FLUSH=FALSE
ADD_DNS=FALSE 
ACTION=NULL

usage() {
    local program=$(basename "$0")
    echo "Usage: $program [OPTIONS] <ACTION>"
    echo
    echo "Options:"
    echo "  -h             Display this help message and exit."
    echo "  -f             Flush DNS cache and restart mDNSResponder daemon."
    echo "  -a             Add a DNS entry to allow list and remove from /etc/hosts."
    echo
    echo "Actions:"
    echo "  prep           Backup hosts file and run hblock to create a new hosts file."
    echo "  restore        Reinstate original hosts file."
    echo
    echo "Examples:"
    echo "  $program prep"
    echo "  $program restore"
    echo "  $program -a example.domain.com"
    echo "  $program -f" 
    echo
    echo "Restrictions:"
    echo "  This script requires privileged actions. User must know sudo(1) password." 
    echo
    echo "  The flush action is specific to macOS only."
    echo
    echo "Notes:" 
    echo "  When adding a DNS entry (-a) or flushing the cache (-f), the arguments <prep | restore> are not required."
    echo 
    exit 1
}

handleError() {
    echo "Error: "$1"" >&2
    exit 1
}

booleanQuery() {
    local question="$1"  

    while true; do
        printf "%s [y/n]: " "$question"
        read -r response

        case "$response" in
            [yY][eE][sS]|[yY])
                return 0  # True
                ;;
            [nN][oO]|[nN])
                return 1  # False
                ;;
            *)
                echo "Invalid response. Please enter 'y' or 'n'."
                ;;
        esac
    done
}

validateDNSname() {
# Name must start & end with a letter or a number and can only contain letters, numbers, and hyphens.
    local dns_name=$1
    local dns_regex='^([a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'

    if [[ $dns_name =~ $dns_regex ]]; then
        return 0  # Valid DNS name
    else
        return 1  # Invalid DNS name
    fi
}

processArguments() {
    while getopts ":fha:" opt; do
        case $opt in
        h)  usage ;; 
        f)  DNS_FLUSH=TRUE ;;
        a)  DNS_NAME="$OPTARG"
            # echo "DNS name set to: $DNS_NAME" 
            ADD_DNS=TRUE ;;
        \?) echo "Invalid option: -$OPTARG" >&2
            usage ;;
        :)  echo "Option -$OPTARG requires an argument." >&2
            usage ;;
        esac
    done
    
    # Shift positional arguments to exclude already processed options
    shift $((OPTIND-1))

    # When flushing the cache, 
    # there are no additional positional arguments available or required. 
    if [[ $# -lt 1 && $ADD_DNS != "TRUE" && $DNS_FLUSH != "TRUE" ]]; then
        echo "error: no argument provided" >&2
        usage
    fi 

    if [[ $1 = "prep" || $1 = "restore" ]]; then
        ACTION=$1
    elif [[ $ADD_DNS != "TRUE" &&  $DNS_FLUSH != "TRUE" ]]; then
        echo "error: invalid argument." >&2
        usage
    fi 
}

# Copy existing HOSTS file before executing hblock [prep]
copyHostsFile() {
    # echo "In function: copyHostsFile"
    pushd /etc > /dev/null 

    if [[ ! -f hosts ]]; then 
        handleError "no hosts file found" 
    fi 
    echo "Existing hosts files" ; echo 
    ls -las hosts*

    # If files hosts-ORIG already exists, this will be destuctive
    if [[ -f hosts-ORIG ]]; then
        echo; echo "WARNING: File hosts-ORIG already exists. This action will overwrite that file"; echo
        if ! booleanQuery "Do you want to continue? (y/n)"; then
            echo "Exiting..."
            exit 0
        fi
    fi 

    sudo cp hosts{,-ORIG}

    echo "Running hblock to update hosts file"
    hblock
    local hblock_exit_status=$?
    if [[ $hblock_exit_status -ne 0 ]]; then
         handleError "hblock execution failed with exit status $hblock_exit_status"
    fi 

    echo ; echo "Hosts file updated. New host files"
    ls -las hosts*
    popd > /dev/null 
}

# Restore HOSTS to original file [restore]
restoreHostsFile() {
    # echo "In function: restoreHostsFile"  
    pushd /etc > /dev/null 

    if [[ ! -f hosts-ORIG ]]; then 
        handleError "no original hosts file (hosts-ORIG) found" 
    fi 
    echo "Existing hosts files" ; echo 
    ls -las hosts*

    # If  hosts already exists, this will be destuctive
    if [[ -f hosts ]]; then
        echo; echo "WARNING: File /etc/hosts already exists. This action will overwrite that file"; echo
        if ! booleanQuery "Do you want to continue? (y/n)"; then
            echo "Exiting..."
            exit 0
        fi
    fi 

    sudo cp hosts{-ORIG,}

    echo "Hosts file updated."
    echo "New host files" ; echo 
    ls -las hosts*
    popd > /dev/null 
}

# Add a DNS entry to allow list and remove this entry from the hosts file
addDNSname() {
    # echo "In fucntion: addDNSname"
    local allow=allow.list
    local hblock_dir=/etc/hblock

    echo "Adding $DNS_NAME to $allow"

    # Verify we have a valid DNS name
    if ! validateDNSname "$DNS_NAME"; then
        handleError "invalid DNS name format: $DNS_NAME"
    fi

    # On first run, will need to create hblock directory 
    if [[ ! -d "$hblock_dir" ]]; then
        sudo mkdir -p $hblock_dir
        local sudo_exit_status=$?
        if [[ $sudo_exit_status -ne 0 ]]; then
            handleError "sudo(1) failed with exit status $sudo_exit_status"
        fi 
    fi 

    pushd $hblock_dir > /dev/null 

    # Check to see if DNS entry already exists in allow.list
    if grep -qFx "$DNS_NAME" "$allow" ; then
        echo "DNS entry "$DNS_NAME" already exists in $allow"
    else    
        echo "$DNS_NAME" >> $allow 
    fi 

    echo "Contents of $allow"
    cat $allow

    # Now remove this entry from /etc/hosts
    echo "Removing $DNS_NAME from /etc/hosts"
    cd ..
    sudo sed -i.bak "/$DNS_NAME/d" hosts
    local sed_exit_status=$?
    if [[ $sed_exit_status -ne 0 ]]; then
        handleError "sed execution failed with exit status $sed_exit_status"
    fi 

    # Verify entry was removed
    if grep -Fqx "$DNS_NAME" hosts; then
        echo "error: $DNS_NAME is still present in /etc/hosts."
    fi

    popd > /dev/null 
}

# Flush DNS cache and restart mDNSResponder
flushDNScache() {
    # echo "In function: flushDNScache"
    if [[ "$(uname)" != "Darwin" ]]; then
        handleError "flush action is specific to macOS"
    fi 

    echo "Flushing DNS cache…"
    sudo dscacheutil -flushcache
    sleep 4
    
    echo "Restarting the mDNSResponder service…"
    sudo killall -HUP mDNSResponder
    sleep 4

    if ! pgrep mDNSResponder > /dev/null; then
        echo "Warning: the mDNSResponder process is not running." >&2
    else
        echo "The mDNSResponder process is running with PID(s): $(pgrep mDNSResponder | xargs)"
    fi

    ps aux | grep mDNSResponder | grep -v grep
}

main() {
    # Verify hblock(1) is loaded on this system
    if ! command -v hblock > /dev/null 2>&1; then
        handleError "hblock(1) does not exist on this path."
    fi

    processArguments "$@"

    case $ACTION in
        "prep")
            copyHostsFile
            ;;
        "restore")
            restoreHostsFile
            ;;
        *)
            if [[ $ADD_DNS = "TRUE" ]]; then
                addDNSname
            elif [[ $DNS_FLUSH = "TRUE" ]]; then
                flushDNScache
            else
                handleError "no valid action specified"
            fi
            ;;
    esac
}

main "$@" 

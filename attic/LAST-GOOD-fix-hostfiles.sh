#!/usr/bin/env bash

# hblock(1) is a shell script available on homebrew that blocks ads, beacons and malware sites. 
# It does this by editing /etc/hosts and setting the IP address for such sites to 0.0.0.0
# The issue is that hblock sometimes adds sites to /etc/hots that are needed.
# This script fixes such issues by adding good DNS hosts to the exclustion list /etc/hblock/allow.list
# and removing the entry from /etc/hosts. It will also optionally flush the DNS cache and restart the daemon.
# Cf. fix-hostfile manpage and design spec for detail. 

# Globals
DNS_FLUSH=FALSE
ADD_DNS=FALSE 
ACTION=NULL
ALLOW_LIST=allow.list

usage() {
    echo "Usage: $(basename "$0") [OPTIONS] <ACTION>"
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
    echo "Example:"
    echo "  $(basename "$0") --add example.com prep"
    echo
    echo "Note: When adding a DNS entry or flushing the cache, no additional positional arguments are required."
    exit 1
}

handleError() {
    echo "Error: $1" >&2
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

    # Note: when adding a DNS entry or flushing the cache, 
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

# Copy existing HOSTS file before executing hblock
copyHostsFile() {
	# echo "In function: copyHostsFile"
	pushd /etc > /dev/null 

	if [[ ! -f hosts ]]; then 
		handleError "error: no hosts file found" 
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

# Restore HOSTS to original file
restoreHostsFile() {
	# echo "In function: restoreHostsFile"	
	pushd /etc > /dev/null 

	if [[ ! -f hosts-ORIG ]]; then 
		handleError "error: no original hosts file (hosts-ORIG) found" 
	fi 
	echo "Existing hosts files" ; echo 
	ls -las hosts*

	# If files hosts already exists, this will be destuctive
	if [[ -f hosts ]]; then
		echo; echo "WARNING: File hosts already exists. This action will overwrite that file"; echo
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

	echo "Adding $DNS_NAME to $ALLOW_LIST"

	# Verify we have a valid DNS name
    if ! validateDNSname "$DNS_NAME"; then
        handleError "Invalid DNS name format: $DNS_NAME"
    fi

	pushd /etc/hblock > /dev/null 

	# Check to see if DNS entry already exists in allow.list
	if grep -qFx "$DNS_NAME" "$ALLOW_LIST" ; then
		echo "DNS entry "$DNS_NAME" already exists in $ALLOW_LIST"
	else	
		echo "$DNS_NAME" >> $ALLOW_LIST 
	fi 

	echo "Contents of $ALLOW_LIST"
	cat $ALLOW_LIST

	# Now remove this entry from /etc/hosts
	echo "Removing $DNS_NAME from /etc/hosts"
	cd ..
	sed -i.bak "/$DNS_NAME/d" hosts
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
	if ! command -v hblock >/dev/null 2>&1; then
	    handleError "error: hblock(1) does not exist on this system."
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
                handleError "error: No valid action specified"
            fi
            ;;
    esac
}

main "$@"

#!/usr/bin/env bash
#===============================================================================
#          FILE: samba.sh
#
#         USAGE: ./samba.sh
#
#   DESCRIPTION: Entrypoint for samba docker container
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: David Personette (dperson@gmail.com),
#  ORGANIZATION:
#       CREATED: 09/28/2014 12:11
#      REVISION: 1.0
#===============================================================================

set -o nounset                              # Treat unset variables as an error

### charmap: setup character mapping for file/directory names
# Arguments:
#   chars) from:to character mappings separated by ','
# Return: configured character mapings
charmap() { local chars="$1" file=/etc/samba/smb.conf
    grep -q catia $file || sed -i '/TCP_NODELAY/a \
\
    vfs objects = catia\
    catia:mappings =\

                ' $file

    sed -i '/catia:mappings/s/ =.*/ = '"$chars" $file
}

### global: set a global config option
# Arguments:
#   option) raw option
# Return: line added to smb.conf (replaces existing line with same key)
global() { local key="${1%%=*}" value="${1#*=}" file=/etc/samba/smb.conf
    if grep -qE '^;*\s*'"$key" "$file"; then
        sed -i 's|^;*\s*'"$key"'.*|   '"${key% } = ${value# }"'|' "$file"
    else
        sed -i '/\[global\]/a \   '"${key% } = ${value# }" "$file"
    fi
}

### import: import a smbpasswd file
# Arguments:
#   file) file to import
# Return: user(s) added to container
import() { local name id file="$1"
    while read name id; do
        adduser -D -H -u "$id" "$name"
    done < <(cut -d: -f1,2 $file | sed 's/:/ /')
    pdbedit -i smbpasswd:$file
}

### perms: fix ownership and permissions of share paths
# Arguments:
#   none)
# Return: result
perms() { local i file=/etc/samba/smb.conf
    for i in $(awk -F ' = ' '/   path = / {print $2}' $file); do
        chown -Rh smbuser. $i
        find $i -type d -exec chmod 775 {} \;
        find $i -type f -exec chmod 664 {} \;
    done
}

### recycle: disable recycle bin
# Arguments:
#   none)
# Return: result
recycle() { local file=/etc/samba/smb.conf
    sed -i '/recycle/d; /vfs/d' $file
}

### share: Add share
# Arguments:
#   share) share name
#   path) path to share
#   browsable) 'yes' or 'no'
#   readonly) 'yes' or 'no'
#   guest) 'yes' or 'no'
#   users) list of allowed users
#   admins) list of admin users
#   writelist) list of users that can write to a RO share
# Return: result
share() { local share="$1" path="$2" browsable=${3:-yes} ro=${4:-yes} \
                guest=${5:-yes} users=${6:-""} admins=${7:-""} \
                writelist=${8:-""} file=/etc/samba/smb.conf
    sed -i "/\\[$share\\]/,/^\$/d" $file
    echo "[$share]" >>$file
    echo "   path = $path" >>$file
    echo "   browsable = $browsable" >>$file
    echo "   read only = $ro" >>$file
    echo "   guest ok = $guest" >>$file
    echo -n "   veto files = /._*/.apdisk/.AppleDouble/.DS_Store/" >>$file
    echo -n ".TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/" >>$file
    echo "Network Trash Folder/Temporary Items/Thumbs.db/" >>$file
    echo "   delete veto files = yes" >>$file
    [[ ${users:-""} && ! ${users:-""} =~ all ]] &&
        echo "   valid users = $(tr ',' ' ' <<< $users)" >>$file
    [[ ${admins:-""} && ! ${admins:-""} =~ none ]] &&
        echo "   admin users = $(tr ',' ' ' <<< $admins)" >>$file
    [[ ${writelist:-""} && ! ${writelist:-""} =~ none ]] &&
        echo "   write list = $(tr ',' ' ' <<< $writelist)" >>$file
    echo "" >>$file
}

### smb: disable SMB2 minimum
# Arguments:
#   none)
# Return: result
smb() { local file=/etc/samba/smb.conf
    sed -i '/min protocol/d' $file
}

### user: add a user
# Arguments:
#   name) for user
#   password) for user
#   id) for user
#   group) for user
# Return: user added to container
user() { local name="${1}" passwd="${2}" id="${3:-""}" group="${4:-""}"
    [[ "$group" ]] && { grep -q "^$group:" /etc/group || addgroup "$group"; }
    adduser -D -H ${group:+-G $group} ${id:+-u $id} "$name"
    echo -e "$passwd\n$passwd" | smbpasswd -s -a "$name"
}

### workgroup: set the workgroup
# Arguments:
#   workgroup) the name to set
# Return: configure the correct workgroup
workgroup() { local workgroup="${1}" file=/etc/samba/smb.conf
    sed -i 's|^\( *workgroup = \).*|\1'"$workgroup"'|' $file
}

### widelinks: allow access wide symbolic links
# Arguments:
#   none)
# Return: result
widelinks() { local file=/etc/samba/smb.conf \
            replace='\1\n   wide links = yes\n   unix extensions = no'
    sed -i 's/\(follow symlinks = yes\)/'"$replace"'/' $file
}

### usage: Help
# Arguments:
#   none)
# Return: Help text
usage() { local RC=${1:-0}
    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -c \"<from:to>\" setup character mapping for file/directory names
                required arg: \"<from:to>\" character mappings separated by ','
    -g \"<parameter>\" Provide global option for smb.conf
                    required arg: \"<parameter>\" - IE: -g \"log level = 2\"
    -i \"<path>\" Import smbpassword
                required arg: \"<path>\" - full file path in container
    -n          Start the 'nmbd' daemon to advertise the shares
    -p          Set ownership and permissions on the shares
    -r          Disable recycle bin for shares
    -S          Disable SMB2 minimum version
    -s \"<name;/path>[;browse;readonly;guest;users;admins;wl]\" Config a share
                required arg: \"<name>;</path>\"
                <name> is how it's called for clients
                <path> path to share
                NOTE: for the default value, just leave blank
                [browsable] default:'yes' or 'no'
                [readonly] default:'yes' or 'no'
                [guest] allowed default:'yes' or 'no'
                [users] allowed default:'all' or list of allowed users
                [admins] allowed default:'none' or list of admin users
                [writelist] list of users that can write to a RO share
    -u \"<username;password>[;ID;group]\"       Add a user
                required arg: \"<username>;<passwd>\"
                <username> for user
                <password> for user
                [ID] for user
                [group] for user
    -w \"<workgroup>\"       Configure the workgroup (domain) samba should use
                required arg: \"<workgroup>\"
                <workgroup> for samba
    -W          Allow access wide symbolic links

The 'command' (if provided and valid) will be run instead of samba
" >&2
    exit $RC
}

[[ "${USERID:-""}" =~ ^[0-9]+$ ]] && usermod -u $USERID -o smbuser
[[ "${GROUPID:-""}" =~ ^[0-9]+$ ]] && groupmod -g $GROUPID -o users

while getopts ":hc:g:i:nprs:Su:Ww:" opt; do
    case "$opt" in
        h) usage ;;
        c) charmap "$OPTARG" ;;
        g) global "$OPTARG" ;;
        i) import "$OPTARG" ;;
        n) NMBD="true" ;;
        p) PERMISSIONS="true" ;;
        r) recycle ;;
        s) eval share $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $OPTARG) ;;
        S) smb ;;
        u) eval user $(sed 's|;| |g' <<< $OPTARG) ;;
        w) workgroup "$OPTARG" ;;
        W) widelinks ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

[[ "${CHARMAP:-""}" ]] && charmap "$CHARMAP"
[[ "${PERMISSIONS:-""}" ]] && perms
[[ "${RECYCLE:-""}" ]] && recycle
[[ "${SMB:-""}" ]] && smb
[[ "${WORKGROUP:-""}" ]] && workgroup "$WORKGROUP"
[[ "${WIDELINKS:-""}" ]] && widelinks

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v grep | grep -q smbd; then
    echo "Service already running, please restart container to apply changes"
else
    [[ ${NMBD:-""} ]] && ionice -c 3 nmbd -D
    exec ionice -c 3 smbd -FS </dev/null
fi
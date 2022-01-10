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

    sed -i '/catia:mappings/s| =.*| = '"$chars"'|' $file
}

### generic: set a generic config option in a section
# Arguments:
#   section) section of config file
#   option) raw option
# Return: line added to smb.conf (replaces existing line with same key)
generic() { local section="$1" key="$(sed 's| *=.*||' <<< $2)" \
            value="$(sed 's|[^=]*= *||' <<< $2)" file=/etc/samba/smb.conf
    if sed -n '/^\['"$section"'\]/,/^\[/p' $file | grep -qE '^;*\s*'"$key"; then
        sed -i '/^\['"$1"'\]/,/^\[/s|^;*\s*\('"$key"' = \).*|   \1'"$value"'|' \
                    "$file"
    else
        sed -i '/\['"$section"'\]/a \   '"$key = $value" "$file"
    fi
}

### global: set a global config option
# Arguments:
#   option) raw option
# Return: line added to smb.conf (replaces existing line with same key)
global() { local key="$(sed 's| *=.*||' <<< $1)" \
            value="$(sed 's|[^=]*= *||' <<< $1)" file=/etc/samba/smb.conf
    if sed -n '/^\[global\]/,/^\[/p' $file | grep -qE '^;*\s*'"$key"; then
        sed -i '/^\[global\]/,/^\[/s|^;*\s*\('"$key"' = \).*|   \1'"$value"'|' \
                    "$file"
    else
        sed -i '/\[global\]/a \   '"$key = $value" "$file"
    fi
}

### include: add a samba config file include
# Arguments:
#   file) file to import
include() { local includefile="$1" file=/etc/samba/smb.conf
    sed -i "\\|include = $includefile|d" "$file"
    echo "include = $includefile" >> "$file"
}

### import: import a smbpasswd file
# Arguments:
#   file) file to import
# Return: user(s) added to container
import() { local file="$1" name id
    while read name id; do
        grep -q "^$name:" /etc/passwd || adduser -D -H -u "$id" "$name"
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
        find $i -type d ! -perm 775 -exec chmod 775 {} \;
        find $i -type f ! -perm 0664 -exec chmod 0664 {} \;
    done
}
export -f perms

### recycle: disable recycle bin
# Arguments:
#   none)
# Return: result
recycle() { local file=/etc/samba/smb.conf
    sed -i '/recycle:/d; /vfs objects/s/ recycle / /' $file
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
#   comment) description of share
# Return: result
share() { local share="$1" path="$2" browsable="${3:-yes}" ro="${4:-yes}" \
                guest="${5:-yes}" users="${6:-""}" admins="${7:-""}" \
                writelist="${8:-""}" comment="${9:-""}" file=/etc/samba/smb.conf
    sed -i "/\\[$share\\]/,/^\$/d" $file
    echo "[$share]" >>$file
    echo "   path = $path" >>$file
    echo "   browsable = $browsable" >>$file
    echo "   read only = $ro" >>$file
    echo "   guest ok = $guest" >>$file
    [[ ${VETO:-yes} == no ]] || {
        echo -n "   veto files = /.apdisk/.DS_Store/.TemporaryItems/" >>$file
        echo -n ".Trashes/desktop.ini/ehthumbs.db/Network Trash Folder/" >>$file
        echo "Temporary Items/Thumbs.db/" >>$file
        echo "   delete veto files = yes" >>$file
    }
    [[ ${users:-""} && ! ${users:-""} == all ]] &&
        echo "   valid users = $(tr ',' ' ' <<< $users)" >>$file
    [[ ${admins:-""} && ! ${admins:-""} =~ none ]] &&
        echo "   admin users = $(tr ',' ' ' <<< $admins)" >>$file
    [[ ${writelist:-""} && ! ${writelist:-""} =~ none ]] &&
        echo "   write list = $(tr ',' ' ' <<< $writelist)" >>$file
    [[ ${comment:-""} && ! ${comment:-""} =~ none ]] &&
        echo "   comment = $(tr ',' ' ' <<< $comment)" >>$file
    echo "" >>$file
    [[ -d $path ]] || mkdir -p $path
}

### smb: disable SMB2 minimum
# Arguments:
#   none)
# Return: result
smb() { local file=/etc/samba/smb.conf
    sed -i 's/\([^#]*min protocol *=\).*/\1 LANMAN1/' $file
}

### user: add a user
# Arguments:
#   name) for user
#   password) for user
#   id) for user
#   group) for user
#   gid) for group
# Return: user added to container
user() { local name="$1" passwd="$2" id="${3:-""}" group="${4:-""}" \
                gid="${5:-""}"
    [[ "$group" ]] && { grep -q "^$group:" /etc/group ||
                addgroup ${gid:+--gid $gid }"$group"; }
    grep -q "^$name:" /etc/passwd ||
        adduser -D -H ${group:+-G $group} ${id:+-u $id} "$name"
    echo -e "$passwd\n$passwd" | smbpasswd -s -a "$name"
}

### workgroup: set the workgroup
# Arguments:
#   workgroup) the name to set
# Return: configure the correct workgroup
workgroup() { local workgroup="$1" file=/etc/samba/smb.conf
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
usage() { local RC="${1:-0}"
    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -c \"<from:to>\" setup character mapping for file/directory names
                required arg: \"<from:to>\" character mappings separated by ','
    -G \"<section;parameter>\" Provide generic section option for smb.conf
                required arg: \"<section>\" - IE: \"share\"
                required arg: \"<parameter>\" - IE: \"log level = 2\"
    -g \"<parameter>\" Provide global option for smb.conf
                required arg: \"<parameter>\" - IE: \"log level = 2\"
    -i \"<path>\" Import smbpassword
                required arg: \"<path>\" - full file path in container
    -n          Start the 'nmbd' daemon to advertise the shares
    -p          Set ownership and permissions on the shares
    -r          Disable recycle bin for shares
    -S          Disable SMB2 minimum version
    -s \"<name;/path>[;browse;readonly;guest;users;admins;writelist;comment]\"
                Configure a share
                required arg: \"<name>;</path>\"
                <name> is how it's called for clients
                <path> path to share
                NOTE: for the default value, just leave blank
                [browsable] default:'yes' or 'no'
                [readonly] default:'yes' or 'no'
                [guest] allowed default:'yes' or 'no'
                NOTE: for user lists below, usernames are separated by ','
                [users] allowed default:'all' or list of allowed users
                [admins] allowed default:'none' or list of admin users
                [writelist] list of users that can write to a RO share
                [comment] description of share
    -u \"<username;password>[;ID;group;GID]\"       Add a user
                required arg: \"<username>;<passwd>\"
                <username> for user
                <password> for user
                [ID] for user
                [group] for user
                [GID] for group
    -w \"<workgroup>\"       Configure the workgroup (domain) samba should use
                required arg: \"<workgroup>\"
                <workgroup> for samba
    -W          Allow access wide symbolic links
    -I          Add an include option at the end of the smb.conf
                required arg: \"<include file path>\"
                <include file path> in the container, e.g. a bind mount

The 'command' (if provided and valid) will be run instead of samba
" >&2
    exit $RC
}

[[ "${USERID:-""}" =~ ^[0-9]+$ ]] && usermod -u $USERID -o smbuser
[[ "${GROUPID:-""}" =~ ^[0-9]+$ ]] && groupmod -g $GROUPID -o smb

while getopts ":hc:G:g:i:nprs:Su:Ww:I:" opt; do
    case "$opt" in
        h) usage ;;
        c) charmap "$OPTARG" ;;
        G) eval generic $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $OPTARG) ;;
        g) global "$OPTARG" ;;
        i) import "$OPTARG" ;;
        n) NMBD="true" ;;
        p) PERMISSIONS="true" ;;
        r) recycle ;;
        s) eval share $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $OPTARG) ;;
        S) smb ;;
        u) eval user $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $OPTARG) ;;
        w) workgroup "$OPTARG" ;;
        W) widelinks ;;
        I) include "$OPTARG" ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

[[ "${CHARMAP:-""}" ]] && charmap "$CHARMAP"
while read i; do
    eval generic $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $i)
done < <(env | awk '/^GENERIC[0-9=_]/ {sub (/^[^=]*=/, "", $0); print}')
while read i; do
    global "$i"
done < <(env | awk '/^GLOBAL[0-9=_]/ {sub (/^[^=]*=/, "", $0); print}')
[[ "${IMPORT:-""}" ]] && import "$IMPORT"
[[ "${RECYCLE:-""}" ]] && recycle
while read i; do
    eval share $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $i)
done < <(env | awk '/^SHARE[0-9=_]/ {sub (/^[^=]*=/, "", $0); print}')
[[ "${SMB:-""}" ]] && smb
while read i; do
    eval user $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $i)
done < <(env | awk '/^USER[0-9=_]/ {sub (/^[^=]*=/, "", $0); print}')
[[ "${WORKGROUP:-""}" ]] && workgroup "$WORKGROUP"
[[ "${WIDELINKS:-""}" ]] && widelinks
[[ "${INCLUDE:-""}" ]] && include "$INCLUDE"
[[ "${PERMISSIONS:-""}" ]] && perms &

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v grep | grep -q smbd; then
    echo "Service already running, please restart container to apply changes"
else
    [[ ${NMBD:-""} ]] && ionice -c 3 nmbd -D
    exec ionice -c 3 smbd -F --debug-stdout --no-process-group </dev/null
fi
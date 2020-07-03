[![logo](https://raw.githubusercontent.com/dperson/samba/master/logo.jpg)](https://www.samba.org)

# Samba

Samba docker container

# What is Samba?

Since 1992, Samba has provided secure, stable and fast file and print services
for all clients using the SMB/CIFS protocol, such as all versions of DOS and
Windows, OS/2, Linux and many others.

# How to use this image

By default there are no shares configured, additional ones can be added.

## Hosting a Samba instance

    sudo docker run -it -p 139:139 -p 445:445 -d dperson/samba -p

OR set local storage:

    sudo docker run -it --name samba -p 139:139 -p 445:445 \
                -v /path/to/directory:/mount \
                -d dperson/samba -p

## Configuration

    sudo docker run -it --rm dperson/samba -h
    Usage: samba.sh [-opt] [command]
    Options (fields in '[]' are optional, '<>' are required):
        -h          This help
        -c "<from:to>" setup character mapping for file/directory names
                    required arg: "<from:to>" character mappings separated by ','
        -G "<section;parameter>" Provide generic section option for smb.conf
                    required arg: "<section>" - IE: "share"
                    required arg: "<parameter>" - IE: "log level = 2"
        -g "<parameter>" Provide global option for smb.conf
                    required arg: "<parameter>" - IE: "log level = 2"
        -i "<path>" Import smbpassword
                    required arg: "<path>" - full file path in container
        -n          Start the 'nmbd' daemon to advertise the shares
        -p          Set ownership and permissions on the shares
        -r          Disable recycle bin for shares
        -S          Disable SMB2 minimum version
        -s "<name;/path>[;browse;readonly;guest;users;admins;writelist;comment]"
                    Configure a share
                    required arg: "<name>;</path>"
                    <name> is how it's called for clients
                    <path> path to share
                    NOTE: for the default values, just leave blank
                    [browsable] default:'yes' or 'no'
                    [readonly] default:'yes' or 'no'
                    [guest] allowed default:'yes' or 'no'
                    NOTE: for user lists below, usernames are separated by ','
                    [users] allowed default:'all' or list of allowed users
                    [admins] allowed default:'none' or list of admin users
                    [writelist] list of users that can write to a RO share
                    [comment] description of share
        -u "<username;password>[;ID;group;GID]"       Add a user
                    required arg: "<username>;<passwd>"
                    <username> for user
                    <password> for user
                    [ID] for user
                    [group] for user
                    [GID] for group
        -w "<workgroup>"       Configure the workgroup (domain) samba should use
                    required arg: "<workgroup>"
                    <workgroup> for samba
        -W          Allow access wide symbolic links
        -I          Add an include option at the end of the smb.conf
                    required arg: "<include file path>"
                    <include file path> in the container, e.g. a bind mount

    The 'command' (if provided and valid) will be run instead of samba

ENVIRONMENT VARIABLES

 * `CHARMAP` - As above, configure character mapping
 * `GENERIC` - As above, configure a generic section option (See NOTE3 below)
 * `GLOBAL` - As above, configure a global option (See NOTE3 below)
 * `IMPORT` - As above, import a smbpassword file
 * `NMBD` - As above, enable nmbd
 * `PERMISSIONS` - As above, set file permissions on all shares
 * `RECYCLE` - As above, disable recycle bin
 * `SHARE` - As above, setup a share (See NOTE3 below)
 * `SMB` - As above, disable SMB2 minimum version
 * `TZ` - Set a timezone, IE `EST5EDT`
 * `USER` - As above, setup a user (See NOTE3 below)
 * `WIDELINKS` - As above, allow access wide symbolic links
 * `WORKGROUP` - As above, set workgroup
 * `USERID` - Set the UID for the samba server's default user (smbuser)
 * `GROUPID` - Set the GID for the samba server's default user (smbuser)
 * `INCLUDE` - As above, add a smb.conf include

**NOTE**: if you enable nmbd (via `-n` or the `NMBD` environment variable), you
will also want to expose port 137 and 138 with `-p 137:137/udp -p 138:138/udp`.

**NOTE2**: there are reports that `-n` and `NMBD` only work if you have the
container configured to use the hosts network stack.

**NOTE3**: optionally supports additional variables starting with the same name,
IE `SHARE` also will work for `SHARE2`, `SHARE3`... `SHAREx`, etc.

## Examples

Any of the commands can be run at creation with `docker run` or later with
`docker exec -it samba samba.sh` (as of version 1.3 of docker).

### Setting the Timezone

    sudo docker run -it -e TZ=EST5EDT -p 139:139 -p 445:445 -d dperson/samba -p

### Start an instance creating users and shares:

    sudo docker run -it -p 139:139 -p 445:445 -d dperson/samba -p \
                -u "example1;badpass" \
                -u "example2;badpass" \
                -s "public;/share" \
                -s "users;/srv;no;no;no;example1,example2" \
                -s "example1 private share;/example1;no;no;no;example1" \
                -s "example2 private share;/example2;no;no;no;example2"

# User Feedback

## Troubleshooting

* You get the error `Access is denied` (or similar) on the client and/or see
`change_to_user_internal: chdir_current_service() failed!` in the container
logs.

Add the `-p` option to the end of your options to the container, or set the
`PERMISSIONS` environment variable.

    sudo docker run -it --name samba -p 139:139 -p 445:445 \
                -v /path/to/directory:/mount \
                -d dperson/samba -p

If changing the permissions of your files is not possible in your setup you
can instead set the environment variables `USERID` and `GROUPID` to the
values of the owner of your files.

* High memory usage by samba. Multiple people have reported high memory usage
that's never freed by the samba processes. Recommended work around below:

Add the `-m 512m` option to docker run command, or `mem_limit:` in
docker_compose.yml files, IE:

    sudo docker run -it --name samba -m 512m -p 139:139 -p 445:445 \
                -v /path/to/directory:/mount \
                -d dperson/samba -p

* Attempting to connect with the `smbclient` commandline tool. By default samba
still tries to use SMB1, which is depriciated and has security issues. This
container defaults to SMB2, which for no decernable reason even though it's
supported is disabled by default so run the command as `smbclient -m SMB3`, then
any other options you would specify.

## Issues

If you have any problems with or questions about this image, please contact me
through a [GitHub issue](https://github.com/dperson/samba/issues).
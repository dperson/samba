[![logo](http://www.samba.org/samba/style/2010/grey/headerPrint.jpg)](https://www.samba.org)

# Samba

Samba docker container

# What is Samba?

Since 1992, Samba has provided secure, stable and fast file and print services
for all clients using the SMB/CIFS protocol, such as all versions of DOS and
Windows, OS/2, Linux and many others.

# How to use this image

By default there are no shares configured, additional ones can be added.

## Hosting a Samba instance

    sudo docker run -p 139:139 -p 445:445 -d dperson/samba

OR set local storage:

    sudo docker run --name samba -p 139:139 -p 445:445 \
                -v /path/to/directory:/mount \
                -d dperson/samba

## Configuration

    sudo docker run -it --rm dperson/samba -h
    Usage: samba.sh [-opt] [command]
    Options (fields in '[]' are optional, '<>' are required):
        -h          This help
        -i "<path>" Import smbpassword
                    required arg: "<path>" - full file path in container to import
        -s "<name;/path>[;browse;readonly;guest;users]" Configure a share
                    required arg: "<name>;<comment>;</path>"
                    <name> is how it's called for clients
                    <path> path to share
                    [browseable] default:'yes' or 'no'
                    [readonly] default:'yes' or 'no'
                    [guest] allowed default:'yes' or 'no'
                    [users] allowed default:'' or list of allowed users
        -t ""       Configure timezone
                    possible arg: "[timezone]" - zoneinfo timezone for container
        -u "<username;password>"       Add a user
                    required arg: "<username>;<passwd>"
                    <username> for user
                    <password> for user

    The 'command' (if provided and valid) will be run instead of samba

ENVIROMENT VARIABLES (only available with `docker run`)

 * `TIMEZONE` - As above, set a zoneinfo timezone, IE `EST5EDT`

## Examples

### Start an instance and set the timezone:

Any of the commands can be run at creation with `docker run` or later with
`docker exec samba.sh` (as of version 1.3 of docker).

    sudo docker run -p 139:139 -p 445:445 -d dperson/samba -t EST5EDT

Will get you the same settings as

    sudo docker run --name samba -p 139:139 -p 445:445 -d dperson/samba
    sudo docker exec samba samba.sh -t EST5EDT ls -AlF /etc/localtime
    sudo docker restart samba

### Start an instance creating users and shares:

    sudo docker run -p 139:139 -p 445:445 -d dperson/samba \
                -u "example1;badpass" \
                -u "example2;badpass" \
                -s "public;/share" \
                -s "users;/srv;no;no;no;example1,example2" \
                -s "example1 private;/example1;no;no;no;example1" \
                -s "example2 private;/example2;no;no;no;example2"

# User Feedback

## Issues

If you have any problems with or questions about this image, please contact me
through a [GitHub issue](https://github.com/dperson/samba/issues).

#!/bin/bash

function error() {
    echo error: "$@" 1>&2
    should_die=1
}

function manage_config() {
    # create default config if the file doesn't exist
    if [ ! -f aem-cfg.sh ]; then
        echo "Creating sample aem-cfg.sh in current directory," \
             "don't forget to edit it."

        cat > aem-cfg.sh <<'EOF'
#!/bin/bash

grub_repo=https://github.com/TrenchBoot/grub.git
xen_repo=https://github.com/TrenchBoot/xen.git

grub_branch=intel-txt-aem-2.06
xen_branch=aem

server_prefix=http://10.0.2.2
server_port=8080
server_url=$server_prefix:$server_port

boot_disk=/dev/vda
boot_part=/dev/vda1

# format: {local file under webroot/}:{destination prefix}
files_to_send=(
    grub.cfg:/grub
    bzImage:/grub
    initramfs.cpio:/grub
    xen/xen.gz:/grub
)
EOF
    fi

    # source whatever config is there at the moment
    source aem-cfg.sh

    # do basic sanity checks
    local vars=(
        grub_repo xen_repo
        grub_branch xen_branch
        server_prefix server_port server_url
        boot_disk
        boot_part
    )
    for var in "${vars[@]}"; do
        [ -z "${!var}" ] && error "\$$var is not set in config!"
    done

    if [[ $boot_part != $boot_disk* ]]; then
        error "\$boot_disk ($boot_disk) is not a prefix of" \
              "\$boot_part ($boot_part)!"
    fi

    if [[ $(declare -p files_to_send) != 'declare -a'* ]]; then
        error '$files_to_send is not an array.'
    else
        for entry in "${files_to_send[@]}"; do
            IFS=":" read -r file dest_dir <<< "$entry"
            if [ -z "$file" ] || [ -z "$dest_dir" ]; then
                error "Wrong \$files_to_send entry: '$entry':"
                error "  * don't forget : separator"
                error "  * use / for no destination prefix"
            fi
        done
    fi

    if [ -n "$should_die" ]; then
        error 'Aborting, please fix "aem-cfg.sh" file in current directory.'
        exit 1
    fi
}

function print_usage() {
    echo "Usage: $(basename $0) action [action-args...]"
    echo
    echo 'Actions:'
    echo '  build  builds GRUB and/or Xen in docker'
    echo '         all  -- builds GRUB and Xen (default)'
    echo '         grub -- builds only GRUB'
    echo '         xen  -- builds only Xen'
    echo '  help   print this message'
    echo '  init   clone repositories to current directory'
    echo '         passes its parameters to git'
    echo '  purge  removes directories that the script creates'
    echo '  serve  manages http server'
    echo '         on     -- starts the server (default)'
    echo '         off    -- stops the server'
    echo '         update -- updates served files'
}

function print_banner() {
    local msg=$1

    echo
    echo ========== "$msg" ==========
    echo
}

function action_build() {
    local what=${1:-all}

    # $HOME is used by ccache, which fails without it on trying to create
    # /.ccache

    if [ "$what" != all ] && [ "$what" != grub ] && [ "$what" != xen ]; then
        echo "Unexpected subaction of build: $what"
        return 1
    fi

    if [ "$what" = all ] || [ "$what" = grub ]; then
        print_banner 'Building GRUB'
        docker run --rm -it \
                   -v "$PWD/grub:/home/trenchboot/grub" \
                   -w /home/trenchboot/grub \
                   -e HOME=/home/trenchboot/grub/.home \
                   --user "$(id -u):$(id -g)" \
                   ghcr.io/trenchboot/trenchboot-sdk:master /bin/bash -c '
            set -e
            [ ! -f configure ] && ./bootstrap
            [ ! -d build ] && (
                mkdir build && cd build
                ../configure --disable-werror --prefix=/ --disable-nls
            )
            make -C build -j$(nproc)
            make -C build install DESTDIR=$PWD/build-install
        '
        if [ $? -ne 0 ]; then
            echo 'Failed to build GRUB'
            return 1
        fi
    fi

    if [ "$what" = all ] || [ "$what" = xen ]; then
        print_banner 'Building Xen'
        docker run --rm -it \
                   -v "$PWD/xen:/home/trenchboot/xen" \
                   -w /home/trenchboot/xen \
                   -e HOME=/home/trenchboot/xen/.home \
                   --user "$(id -u):$(id -g)" \
                   ghcr.io/trenchboot/trenchboot-sdk:master \
                   make -j$(nproc) build-xen
        if [ $? -ne 0 ]; then
            echo 'Failed to build Xen'
            return 1
        fi
    fi
}

function action_purge() {
    kill_server

    rm -rf grub xen
    rm -rf webroot/grub webroot/xen
    rm -f webroot/aem-bootstrap.sh webroot/grub.files webroot/index.html
}

function action_help() {
    print_usage
}

function action_init() {
    if ! git clone "$grub_repo" -b "$grub_branch" "$@" grub; then
        echo 'Failed to clone GRUB'
        return 1
    fi
    if ! git clone "$xen_repo" -b "$xen_branch" "$@" xen; then
        echo 'Failed to clone Xen'
        return 1
    fi
}

function esc() {
    printf '%q' "$@"
}

function validate_files_to_send() {
    for entry in "${files_to_send[@]}"; do
        IFS=":" read -r file dest_dir <<< "$entry"
        if [ ! -f "webroot/$file" ]; then
            error "Invalid \$files_to_send entry: '$entry'?"
            error "  Make sure webroot/$file file (not directory!) exists."
        fi
    done

    if [ -n "$should_die" ]; then
        error 'Aborting, adjust "aem-cfg.sh" file in current directory' \
              'or add missing files.'
        exit 1
    fi
}

function build_webroot() {
    local grub_install=$PWD/grub/build-install

    mkdir -p webroot

    rm -rf webroot/grub
    mkdir webroot/grub/
    ln -s \
       "$grub_install"/sbin/grub-install \
       "$grub_install"/lib/grub/i386-pc/* \
       webroot/grub/

    mkdir -p webroot/xen/
    ln -sf "$PWD/xen/xen/xen.gz" webroot/xen

    find webroot/grub -type l |
        sed "s#^webroot/#$server_url/#" > webroot/grub.files

    cat > webroot/aem-bootstrap.sh <<EOF
#!/bin/bash

set -e

mnt=/tmp/aes-mnt
mkdir -p "\$mnt"

# in case previous run of the script hasn't finished for some reason
umount "\$mnt" 2> /dev/null 1>&2 || true

mount $(esc "$boot_part") "\$mnt"
cd "\$mnt"

rm -rf grub i386-pc
mkdir i386-pc
cd i386-pc

wget $(esc "$server_url/grub.files")
wget -q \$(cat grub.files)

chmod +x grub-install
./grub-install --boot-directory="\$mnt" -d . $(esc "$boot_disk")

EOF

    for entry in "${files_to_send[@]}"; do
        IFS=":" read -r file dest_dir <<< "$entry"
        echo "wget -P "\"\$mnt\"$(esc $dest_dir)" $(esc "$server_url/$file")" \
            >> webroot/aem-bootstrap.sh
    done

    cat >> webroot/aem-bootstrap.sh <<EOF

cd /
umount "\$mnt"

echo DONE
EOF

    ln -sf aem-bootstrap.sh webroot/index.html

    # tell the user if any files are missing
    validate_files_to_send
}

function kill_server() {
    local pid=$(cat webroot/.pid 2> /dev/null)
    if [ -z "$pid" ]; then
        return 0
    fi

    if kill "$pid" 2> /dev/null; then
        echo "Stopped the server with PID $pid"
    fi
}

function print_remote_cmd() {
    echo "Run on the remote:"
    echo "    wget -O - $server_url | bash -"
}

function action_serve() {
    local python3=python3
    if ! command -v python3 > /dev/null; then
        python3=python
    fi

    local sub_action=${1:-on}
    shift

    case "$sub_action" in
        on)
            kill_server
            build_webroot
            ( cd webroot &&
              exec $python3 -m http.server "$server_port" 2> .log 1>&2 ) &
            echo $! > webroot/.pid
            echo "Started server on $server_port with PID $!"
            print_remote_cmd
            ;;
        off)
            kill_server
            ;;
        update)
            build_webroot
            print_remote_cmd
            ;;

        *)
            echo "Unexpected subaction of serve: $sub_action"
            echo
            print_usage
            return 1 ;;
    esac
}

manage_config

if [ $# -eq 0 ]; then
    print_usage
    exit 1
fi

action=$1
shift

case "$action" in
    build) action_build "$@" ;;
    help)  action_help  "$@" ;;
    init)  action_init  "$@" ;;
    purge) action_purge "$@" ;;
    serve) action_serve "$@" ;;

    *)
        echo "Unexpected action: $action"
        echo
        print_usage
        exit 1 ;;
esac

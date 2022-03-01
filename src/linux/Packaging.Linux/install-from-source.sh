#!/bin/sh

SUDO_CMD=sudo

# Parse script arguments
for i in "$@"
do
    case "$i" in
        --sudo-cmd=*)
        SUDO_CMD="${i#*=}"
        shift # past argument=value
        ;;
    esac
done

install_shared_packages() {
    pkg_manager=$1
    install_verb=$2

    local shared_packages="git curl apt-transport-https"
    for package in $shared_packages
    do
        if [ $pkg_manager = apk ]; then
            $SUDO_CMD $pkg_manager $install_verb $package
        else
            $SUDO_CMD $pkg_manager $install_verb $package -y
        fi
    done
}

download_dotnet_script() {
    curl -o dotnet-install.sh -L https://dot.net/v1/dotnet-install.sh
    chmod +x ./dotnet-install.sh
}

distribution=$(sed -n '/^ID=/p' /etc/os-release | cut -c 4- | tr -d '"')
case $distribution in
    debian | ubuntu | linuxmint)
        # add dotnet package repository/signing key
        $SUDO_CMD apt update && $SUDO_CMD apt install wget -y
        eval wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
        $SUDO_CMD dpkg -i packages-microsoft-prod.deb
        rm packages-microsoft-prod.deb

        # proactively install tzdata to prevent prompts
        $SUDO_CMD apt update
        export DEBIAN_FRONTEND=noninteractive
        $SUDO_CMD apt-get install -y --no-install-recommends tzdata

        install_shared_packages apt install

        # install dotnet packages
        $SUDO_CMD apt install dotnet-sdk-5.0 dpkg-dev -y
    ;;
    fedora | centos | rhel)
        if [ $distribution = centos ]; then
            sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
            sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*
        fi
        $SUDO_CMD dnf update -y
        install_shared_packages dnf install

        # install dotnet/gcm dependencies
        $SUDO_CMD dnf install krb5-libs libicu openssl-libs zlib findutils which -y

        download_dotnet_script
        source ./dotnet-install.sh
    ;;
    alpine)
        $SUDO_CMD apk update
        install_shared_packages apk add

        # install dotnet/gcm dependencies
        $SUDO_CMD apk add icu-libs krb5-libs libgcc libintl libssl1.1 libstdc++ zlib which bash coreutils gcompat 

        download_dotnet_script
        bash -c "./dotnet-install.sh"

        # since we have to run the script with bash, dotnet isn't added
        # to the process PATH, so we manually add here
        cd ~
        export DOTNET_ROOT=$(pwd)/.dotnet
        export PATH=$PATH:$DOTNET_ROOT:
    ;;
    *)
        echo "ERROR: Unsupported Linux distribution"
        exit
    ;;
esac

# clone and build source
if [ ! -d git-credential-manager ]; then
    git clone https://github.com/ldennington/git-credential-manager.git || exit
fi
cd git-credential-manager
$SUDO_CMD dotnet build ./src/linux/Packaging.Linux/Packaging.Linux.csproj -c Release -p:InstallFromSource=true
export PATH=$PATH:$HOME/usr/local/bin:

# configure gcm
git-credential-manager-core configure

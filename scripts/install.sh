#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

v2bx_repo="phungvanquy/v2bx-new"
script_ref="${V2BX_SCRIPT_REF:-refs/heads/main}"
install_dir="/usr/local/V2bX"
service_file="/etc/systemd/system/V2bX.service"
management_file="/usr/bin/V2bX"
elise_management_file="/usr/bin/V2bX-elise"
install_temp_dir=""

cleanup_install_temp() {
    if [[ -n "${install_temp_dir}" && -d "${install_temp_dir}" ]]; then
        rm -rf "${install_temp_dir}"
    fi
}

download_file() {
    local url=$1
    local destination=$2

    curl --fail --location --silent --show-error \
        --retry 3 --retry-delay 2 --connect-timeout 15 \
        --output "${destination}" "${url}"
}

# Keep the Rust core install path separate from the Go release transaction.
if [[ "${1:-}" == "elise" ]]; then
    shift
    [[ $EUID -eq 0 ]] || { echo "Run as root" >&2; exit 1; }
    helper=$(mktemp /tmp/v2bx-elise-helper.XXXXXX) || exit 1
    trap 'rm -f "$helper"' EXIT
    download_file "https://raw.githubusercontent.com/${v2bx_repo}/${script_ref}/scripts/elise.sh" "$helper" || exit 1
    if [[ ! -s "$helper" ]] || ! bash -n "$helper"; then
        echo "Invalid Elise management script" >&2
        exit 1
    fi
    install -m 0755 "$helper" "$elise_management_file" || exit 1
    if [[ $# -eq 0 ]]; then set -- install; fi
    rm -f "$helper"
    exec "$elise_management_file" "$@"
fi

show_v050_compatibility_notice() {
    local version=${1#v}
    local major=${version%%.*}
    local remainder=${version#*.}
    local minor=${remainder%%.*}

    if [[ "${major}" =~ ^[0-9]+$ && "${minor}" =~ ^[0-9]+$ ]] && \
        (( major > 0 || minor >= 5 )); then
        echo -e "${yellow}Compatibility note for V2bX v0.5.0 and later:${plain}"
        echo "- Xray no longer supports legacy transport-header types named SRTP, TLS, UTP, WeChat, or WireGuard."
        echo "- Xray rejects plaintext Shadowsocks methods (none/plain) and DisableIVCheck=true."
        echo "Review custom or panel-managed node settings before a production rollout."
    fi
}

trap cleanup_install_temp EXIT

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
    echo -e "${red}The script does not support Alpine system!${plain}\n" && exit 1
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact the script author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    echo -e "${red}Unsupported architecture: ${arch}. Supported architectures: amd64, arm64, and s390x.${plain}"
    exit 2
fi

echo "Architecture: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "This software does not support 32-bit systems (x86), please use a 64-bit system (x86_64). If the detection is incorrect, please contact the author."
    exit 2
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher!${plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}Note: CentOS 7 cannot use hysteria1/2 protocol!${plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
        yum install ca-certificates wget -y
        update-ca-trust force-enable
    else
        apt-get update -y
        apt install wget curl unzip tar cron socat -y
        apt-get install ca-certificates wget -y
        update-ca-certificates
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/V2bX.service ]]; then
        return 2
    fi
    temp=$(systemctl status V2bX | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_V2bX() {
    local archive_url
    local archive_path
    local digest_path
    local expected_sha256
    local actual_sha256
    local package_dir
    local downloaded_service
    local downloaded_script
    local downloaded_elise
    local backup_dir="${install_dir}.rollback.$$"
    local service_backup
    local management_backup
    local elise_backup
    local geoip_backup
    local geosite_backup
    local had_install=false
    local had_geoip=false
    local had_geosite=false
    local was_enabled=false
    local was_running=false
    local service_started=false
    local required_file
    local config_file
    local -a created_config_files=()

    if [[ $# -eq 0 || -z "${1:-}" ]]; then
        last_version=$(curl --fail --location --silent --show-error \
            --retry 3 --retry-delay 2 --connect-timeout 15 \
            "https://api.github.com/repos/${v2bx_repo}/releases/latest" |
            sed -nE 's/.*"tag_name": *"([^"]+)".*/\1/p' | head -n 1)
        if [[ -z "${last_version}" ]]; then
            echo -e "${red}Failed to detect V2bX version, possibly exceeding Github API limit. Please try again later or manually specify the V2bX version to install.${plain}"
            return 1
        fi
    else
        last_version=$1
    fi

    if [[ "${last_version}" =~ ^[0-9] ]]; then
        last_version="v${last_version}"
    fi

    echo -e "Detected V2bX ${last_version}; downloading and verifying the release"
    install_temp_dir=$(mktemp -d /tmp/v2bx-install.XXXXXX) || return 1
    archive_path="${install_temp_dir}/V2bX-linux-${arch}.zip"
    digest_path="${archive_path}.dgst"
    package_dir="${install_temp_dir}/package"
    downloaded_service="${install_temp_dir}/V2bX.service"
    downloaded_script="${install_temp_dir}/V2bX.sh"
    downloaded_elise="${install_temp_dir}/elise.sh"
    service_backup="${install_temp_dir}/V2bX.service.previous"
    management_backup="${install_temp_dir}/V2bX.sh.previous"
    elise_backup="${install_temp_dir}/elise.sh.previous"
    geoip_backup="${install_temp_dir}/geoip.dat.previous"
    geosite_backup="${install_temp_dir}/geosite.dat.previous"
    archive_url="https://github.com/${v2bx_repo}/releases/download/${last_version}/V2bX-linux-${arch}.zip"

    if ! download_file "${archive_url}" "${archive_path}" || \
        ! download_file "${archive_url}.dgst" "${digest_path}"; then
        echo -e "${red}Failed to download V2bX ${last_version} and its digest from GitHub.${plain}"
        return 1
    fi

    expected_sha256=$(sed -nE 's/^SHA2-256= ([0-9a-fA-F]{64})$/\1/p' "${digest_path}")
    actual_sha256=$(sha256sum "${archive_path}" | awk '{print $1}')
    if [[ -z "${expected_sha256}" || "${actual_sha256}" != "${expected_sha256,,}" ]]; then
        echo -e "${red}V2bX archive checksum verification failed; the installed version was not changed.${plain}"
        return 1
    fi

    mkdir -p "${package_dir}"
    if ! unzip -q "${archive_path}" -d "${package_dir}"; then
        echo -e "${red}The V2bX release archive is invalid; the installed version was not changed.${plain}"
        return 1
    fi
    for required_file in V2bX config.json dns.json route.json custom_outbound.json \
        custom_inbound.json geoip.dat geosite.dat; do
        if [[ ! -s "${package_dir}/${required_file}" ]]; then
            echo -e "${red}The release archive is missing ${required_file}; the installed version was not changed.${plain}"
            return 1
        fi
    done
    chmod +x "${package_dir}/V2bX"

    if ! download_file \
        "https://raw.githubusercontent.com/${v2bx_repo}/${script_ref}/scripts/V2bX.service" \
        "${downloaded_service}" || \
        ! download_file \
        "https://raw.githubusercontent.com/${v2bx_repo}/${script_ref}/scripts/V2bX.sh" \
        "${downloaded_script}" || \
        ! download_file \
        "https://raw.githubusercontent.com/${v2bx_repo}/${script_ref}/scripts/elise.sh" \
        "${downloaded_elise}"; then
        echo -e "${red}Failed to download the service or management script; the installed version was not changed.${plain}"
        return 1
    fi
    if [[ ! -s "${downloaded_elise}" ]] || ! bash -n "${downloaded_script}" || ! bash -n "${downloaded_elise}" || \
        ! grep -q '^ExecStart=/usr/local/V2bX/V2bX server$' "${downloaded_service}"; then
        echo -e "${red}The downloaded management script or service file is invalid; the installed version was not changed.${plain}"
        return 1
    fi

    if [[ -e "${backup_dir}" ]]; then
        echo -e "${red}Cannot create rollback directory ${backup_dir}; the installed version was not changed.${plain}"
        return 1
    fi
    if [[ -d "${install_dir}" ]]; then
        had_install=true
    fi
    if systemctl is-active --quiet V2bX 2>/dev/null; then
        was_running=true
    fi
    if systemctl is-enabled --quiet V2bX 2>/dev/null; then
        was_enabled=true
    fi
    if [[ -f "${service_file}" ]]; then
        if ! cp -p "${service_file}" "${service_backup}"; then
            echo -e "${red}Failed to back up the existing service file; the installed version was not changed.${plain}"
            return 1
        fi
    fi
    if [[ -f "${management_file}" ]]; then
        if ! cp -p "${management_file}" "${management_backup}"; then
            echo -e "${red}Failed to back up the existing management script; the installed version was not changed.${plain}"
            return 1
        fi
    fi
    if [[ -f "${elise_management_file}" ]]; then
        if ! cp -p "${elise_management_file}" "${elise_backup}"; then
            echo -e "${red}Failed to back up the Elise management script; the installed version was not changed.${plain}"
            return 1
        fi
    fi
    if [[ -f /etc/V2bX/geoip.dat ]]; then
        had_geoip=true
        cp -p /etc/V2bX/geoip.dat "${geoip_backup}" || return 1
    fi
    if [[ -f /etc/V2bX/geosite.dat ]]; then
        had_geosite=true
        cp -p /etc/V2bX/geosite.dat "${geosite_backup}" || return 1
    fi

    rollback_install() {
        systemctl stop V2bX 2>/dev/null || true
        rm -rf "${install_dir}"
        if [[ "${had_install}" == true && -d "${backup_dir}" ]]; then
            mv "${backup_dir}" "${install_dir}"
        fi
        if [[ -f "${service_backup}" ]]; then
            cp -p "${service_backup}" "${service_file}"
        else
            rm -f "${service_file}"
        fi
        if [[ -f "${management_backup}" ]]; then
            cp -p "${management_backup}" "${management_file}"
        else
            rm -f "${management_file}"
        fi
        if [[ -f "${elise_backup}" ]]; then
            cp -p "${elise_backup}" "${elise_management_file}"
        else
            rm -f "${elise_management_file}"
        fi
        if [[ "${had_geoip}" == true ]]; then
            cp -p "${geoip_backup}" /etc/V2bX/geoip.dat 2>/dev/null || true
        else
            rm -f /etc/V2bX/geoip.dat
        fi
        if [[ "${had_geosite}" == true ]]; then
            cp -p "${geosite_backup}" /etc/V2bX/geosite.dat 2>/dev/null || true
        else
            rm -f /etc/V2bX/geosite.dat
        fi
        for config_file in "${created_config_files[@]}"; do
            rm -f "${config_file}"
        done
        systemctl daemon-reload 2>/dev/null || true
        if [[ "${was_enabled}" == true ]]; then
            systemctl enable V2bX >/dev/null 2>&1 || true
        else
            systemctl disable V2bX >/dev/null 2>&1 || true
        fi
        if [[ "${was_running}" == true ]]; then
            systemctl start V2bX 2>/dev/null || true
        fi
    }

    systemctl stop V2bX 2>/dev/null || true
    if [[ "${had_install}" == true ]]; then
        if ! mv "${install_dir}" "${backup_dir}"; then
            echo -e "${red}Failed to prepare the existing installation for upgrade.${plain}"
            if [[ "${was_running}" == true ]]; then
                systemctl start V2bX 2>/dev/null || true
            fi
            return 1
        fi
    fi
    if ! mv "${package_dir}" "${install_dir}"; then
        rollback_install
        echo -e "${red}Failed to activate the downloaded release.${plain}"
        return 1
    fi

    if ! mkdir -p /etc/V2bX/ || \
        ! install -m 0644 "${downloaded_service}" "${service_file}" || \
        ! install -m 0755 "${downloaded_script}" "${management_file}" || \
        ! install -m 0755 "${downloaded_elise}" "${elise_management_file}" || \
        ! systemctl daemon-reload || \
        ! systemctl enable V2bX || \
        ! cp "${install_dir}/geoip.dat" /etc/V2bX/ || \
        ! cp "${install_dir}/geosite.dat" /etc/V2bX/; then
        echo -e "${red}Failed to activate V2bX ${last_version}; restoring the previous installation.${plain}"
        rollback_install
        return 1
    fi

    for config_file in dns.json route.json custom_outbound.json custom_inbound.json; do
        if [[ ! -f "/etc/V2bX/${config_file}" ]]; then
            created_config_files+=("/etc/V2bX/${config_file}")
            if ! cp "${install_dir}/${config_file}" "/etc/V2bX/${config_file}"; then
                echo -e "${red}Failed to install ${config_file}; restoring the previous installation.${plain}"
                rollback_install
                return 1
            fi
        fi
    done

    if [[ ! -f /etc/V2bX/config.json ]]; then
        created_config_files+=("/etc/V2bX/config.json")
        if ! cp "${install_dir}/config.json" /etc/V2bX/; then
            echo -e "${red}Failed to install the default configuration; restoring the previous installation.${plain}"
            rollback_install
            return 1
        fi
        echo -e ""
        echo -e "Fresh installation, please refer to the tutorial: https://v2bx.v-50.me/ and configure the necessary content"
        first_install=true
    else
        if systemctl start V2bX; then
            for _ in 1 2 3 4 5; do
                sleep 2
                if check_status; then
                    service_started=true
                    break
                fi
            done
        fi
        echo -e ""
        if [[ "${service_started}" == true ]]; then
            echo -e "${green}V2bX restarted successfully${plain}"
        else
            echo -e "${red}V2bX ${last_version} failed to start.${plain}"
            echo -e "${yellow}Restoring the previous V2bX installation.${plain}"
            rollback_install
            echo -e "${red}Check the service log and configuration compatibility before trying again.${plain}"
            show_v050_compatibility_notice "${last_version}"
            return 1
        fi
        first_install=false
    fi

    if [ ! -L /usr/bin/v2bx ]; then
        ln -s /usr/bin/V2bX /usr/bin/v2bx
    fi

    if [[ "${had_install}" == true && -d "${backup_dir}" ]]; then
        rm -rf "${backup_dir}"
    fi
    echo -e "${green}V2bX ${last_version}${plain} installation completed and enabled at boot"
    show_v050_compatibility_notice "${last_version}"

    echo -e ""
    echo "V2bX management script usage (compatible with using V2bX, case insensitive): "
    echo "------------------------------------------"
    echo "V2bX              - Show management menu (more features)"
    echo "V2bX start        - Start V2bX"
    echo "V2bX stop         - Stop V2bX"
    echo "V2bX restart      - Restart V2bX"
    echo "V2bX status       - Check V2bX status"
    echo "V2bX enable       - Set V2bX to start on boot"
    echo "V2bX disable      - Cancel V2bX start on boot"
    echo "V2bX log          - View V2bX log"
    echo "V2bX x25519       - Generate x25519 key"
    echo "V2bX generate     - Generate V2bX configuration file"
    echo "V2bX update       - Update V2bX"
    echo "V2bX update x.x.x - Update V2bX to specified version"
    echo "V2bX install      - Install V2bX"
    echo "V2bX uninstall    - Uninstall V2bX"
    echo "V2bX version      - View V2bX version"
    echo "V2bX elise ...    - Install/manage Elise Rust VLESS/VMess/AnyTLS/Hysteria 1/2 nodes"
    echo "------------------------------------------"
    # First installation prompt to generate configuration file
    if [[ $first_install == true ]]; then
        read -rp "Detected that this is your first installation of V2bX, do you want to automatically generate the configuration file? (y/n): " if_generate
        if [[ $if_generate == [Yy] ]]; then
            curl -o ./initconfig.sh -Ls "https://raw.githubusercontent.com/${v2bx_repo}/${script_ref}/scripts/initconfig.sh"
            source initconfig.sh
            rm initconfig.sh -f
            generate_config_file
        fi
    fi
}

echo -e "${green}Starting installation${plain}"
install_base
install_V2bX "${1:-}"

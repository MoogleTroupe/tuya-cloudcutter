#!/usr/bin/env bash

COMBINED_AP_PREAMBLE=$(cat ap_preambles.txt | grep -v '#' | awk '{ print "("$1")" }' | xargs | tr ' ' '|')

AP_MATCHED_NAME=""
FIRST_WIFI=$(nmcli device status | grep " wifi " | head -n1 | awk -F ' ' '{print $1}')

if [ "${WIFI_ADAPTER}" == "" ]; then
  WIFI_ADAPTER="${FIRST_WIFI}"
fi

reset_nm () {

if [ -z ${RESETNM+x} ]; then
    return 0
else
    echo "Wiping NetworkManager configs"
    rm /etc/NetworkManager/system-connections/*.nmconnection*
    service NetworkManager restart
    return 0
fi

}

wifi_connect () {
    AP_SEARCH_STRING=${1:-$COMBINED_AP_PREAMBLE}
    AP_PASS=${2:-""}


    for i in {1..5}
    do
        AP_MATCHED_NAME=""

        # Turn on WiFi, and wait for SSID to show up
        reset_nm
        sleep 1

        nmcli device set ${WIFI_ADAPTER} managed yes  # Make sure we turn on managed mode again in case we didn't recover it in the trap below
        nmcli radio wifi off
        sleep 1
        nmcli radio wifi on
        while [ "${AP_MATCHED_NAME}" == "" ]
        do
            echo "Scanning for \"${AP_SEARCH_STRING}\" SSID..."
	    AP_MATCHED_NAME=$(nmcli -t -f SSID dev wifi list --rescan yes | grep -E "${AP_SEARCH_STRING}" | sort -u)
        done

        echo "Found access point name: \"${AP_MATCHED_NAME}\", trying to connect.."
        nmcli dev wifi connect "${AP_MATCHED_NAME}" ${AP_PASS}

        # Check if successfully connected
        AP_STATUS=$(nmcli -f GENERAL.STATE con show "${AP_MATCHED_NAME}" | awk -F ' ' '{print $2}')
        if [ "${AP_STATUS}" != "activated" ]; then
            if [[ "${i}" == "5" ]]; then
                echo "Error, could not connect to SSID."
                return 1
            fi
        else
            break
        fi

        sleep 1
    done

    echo "Connected to access point."
    return 0
}

build_docker () {
    docker build -q -t cloudcutter .
    if [ ! $? -eq 0 ]; then
        echo "Failed to build Docker image, stopping script"
        exit 1
    fi
}

run_in_docker () {
    docker run --network=host -ti --privileged -v "$(pwd):/work" cloudcutter "${@}"
}

# Docker prep
echo "Building cloudcutter docker image.."
build_docker
echo "Successfully built docker image"

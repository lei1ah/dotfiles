#!/bin/bash

# there is a service called 'battery-monitor.service' for running  this script
# is is enabled with systemctl --user enable batter-monitor.service

X_USER="florian"
X_USERID="1000"

battery_level=$(acpi -b | sed -n 's/.*\ \([[:digit:]]\{1,3\}\)\%.*/\1/;p')
battery_state=$(acpi -b | awk '{print $3}' | tr -d ",")
battery_remaining=$(acpi -b | sed -n '/Discharging/{s/^.*\ \([[:digit:]]\{2\}\)\:\([[:digit:]]\{2\}\).*/\1h \2min/;p}')

backlight_cmd=$(which brightnessctl)
notify_cmd='sudo -u '"$X_USER"' DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/'"$X_USERID"'/bus notify-send'

_battery_threshold_level="20"
_battery_critical_level="10"
_battery_suspend_level="5"

if [ ! -f "/tmp/.battery" ]; then
    echo "${battery_level}" > /tmp/.battery
    echo "${battery_state}" >> /tmp/.battery
    exit
fi

previous_battery_level=$(cat /tmp/.battery | head -n 1)
previous_battery_state=$(cat /tmp/.battery | tail -n 1)
echo "${battery_level}" > /tmp/.battery
echo "${battery_state}" >> /tmp/.battery

checkBatteryLevel() {
    if [ ${battery_state} != "Discharging" ] || [ "${battery_level}" == "${previous_battery_level}" ]; then
        exit
    fi

    if [ ${battery_level} -le ${_battery_suspend_level} ]; then
        i3lock -e -c 000000 && sleep 1 && systemctl suspend
    elif [ ${battery_level} -le ${_battery_critical_level} ]; then
        $notify_cmd "Low Battery" "Your computer will suspend soon unless plugged into a power outlet." -u critical
	    ${backlight_cmd} s 50%
    elif [ ${battery_level} -le ${_battery_threshold_level} ]; then
        $notify_cmd "Low Battery" "${battery_level}% (${battery_remaining}) of battery remaining." -u normal
	    ${backlight_cmd} s 75%
    fi
}

checkBatteryStateChange() {
    if [ "${battery_state}" != "Discharging" ] && [ "${previous_battery_state}" == "Discharging" ]; then
        $notify_cmd "Charging" "Battery is now plugged in." -u low
        echo "should send"
	    ${backlight_cmd} s 100%
    fi

    if [ "${battery_state}" == "Discharging" ] && [ "${previous_battery_state}" != "Discharging" ]; then
        $notify_cmd "Power Unplugged" "Your computer has been disconnected from power." -u low
    fi
}

checkBatteryStateChange
checkBatteryLevel


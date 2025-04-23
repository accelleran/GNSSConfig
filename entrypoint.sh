#!/bin/bash
LOG_FILE="/var/log/ubxtool-config.log"

GREEN="\e[1;32m"
YELLOW="\e[1;33m"
RED="\e[1;31m"
BLUE="\e[1;34m"
RESET="\e[0m"

echo -e "${BLUE}Starting UBX configuration...${RESET}" | tee "$LOG_FILE"


# Perform factory reset
# Create a binary UBX reset message and send it
echo -e "${YELLOW}Performing factory reset...${RESET}" | tee -a "$LOG_FILE"
echo -ne '\xb5\x62\x06\x09\x0d\x00\xff\xff\x00\x00\xff\xff\x00\x00\x00\x00\x00\x00\x17\x31' > /dev/gnss0


sleep 4

# Start gpsd
echo -e "${BLUE}Starting gpsd...${RESET}"
gpsd -n /dev/gnss0 -F /var/run/gpsd.sock

sleep 4
ubxtool -p RESET


ubxtool -P 29.20 -d BEIDOU,1 -w 2 | tee -a "$LOG_FILE"
ubxtool -P 29.20 -d GLONASS,1 -w 2 | tee -a "$LOG_FILE"
ubxtool -P 29.20 -d GPS,1 -w 2 | tee -a "$LOG_FILE"
ubxtool -P 29.20 -d SBAS,1 -w 2 | tee -a "$LOG_FILE"
ubxtool -P 29.20 -d GALILEO,1 -w 2 | tee -a "$LOG_FILE"




echo "Wait for 240 Seconds"
sleep 240


# Send UBX commands with logging
echo -e "${YELLOW}Disabling UART1...${RESET}" | tee -a "$LOG_FILE"
ubxtool -v 1 -w 1 -P 29.20 -z CFG-UART1-ENABLED,0,5 | tee -a "$LOG_FILE"
echo -e "${YELLOW}Disabling UART2...${RESET}" | tee -a "$LOG_FILE"
ubxtool -v 3 -w 1 -P 29.20 -z CFG-UART2-ENABLED,0,5 | tee -a "$LOG_FILE"

echo "Enable NMEA"
ubxtool -p CFG-MSG,10,56,1 -t
ubxtool -p CFG-MSG,1,34,1 -t

sleep 4

echo -e "${BLUE}Return time accuracy to /var/log/ubx-time.txt before applying configuration${RESET}"
ubxtool -p NAV-CLOCK -v 2  > /var/log/ubxtool-time-start.txt

echo -e "${GREEN}Enabling BEIDOU...${RESET}" | tee -a "$LOG_FILE"
ubxtool -P 29.20 -e BEIDOU,1 -w 2 | tee -a "$LOG_FILE"
echo -e "${GREEN}Enabling GLONASS...${RESET}" | tee -a "$LOG_FILE"
ubxtool -P 29.20 -e GLONASS,1 -w 2 | tee -a "$LOG_FILE"
echo -e "${GREEN}Enabling GPS...${RESET}" | tee -a "$LOG_FILE"
ubxtool -P 29.20 -e GPS,1 -w 2 | tee -a "$LOG_FILE"
echo -e "${GREEN}Enabling SBAS...${RESET}" | tee -a "$LOG_FILE"
ubxtool -P 29.20 -e SBAS,1 -w 2 | tee -a "$LOG_FILE"
echo -e "${GREEN}Enabling GALILEO...${RESET}" | tee -a "$LOG_FILE"
ubxtool -P 29.20 -e GALILEO,1 -w 2 | tee -a "$LOG_FILE"
echo -e "${BLUE}Reading CFG-SIGNAL...${RESET}" | tee -a "$LOG_FILE"
ubxtool -v 1 -P 29.20 -g CFG-SIGNAL -v 1 -w 2 | tee -a "$LOG_FILE"

echo "Wait for 240 Seconds"
sleep 240

echo -e "${BLUE}Return time accuracy after applying configuration${RESET}"
ubxtool -p NAV-CLOCK -v 2 > /var/log/ubxtool-time-end.txt

# Disable Bin
echo -e "${YELLOW}Disable Bin${RESET}" | tee -a "$LOG_FILE"
ubxtool -P 29.20 -d BINARY
ubxtool -p CFG-MSG,10,56,0 -t
ubxtool -p CFG-MSG,1,34,0 -t

# Enable RMC
echo -e "${YELLOW}Enable RMC${RESET}" | tee -a "$LOG_FILE"
ubxtool -P 29.20 -p CFG-MSG,240,4,1 | tee -a "$LOG_FILE"

# Enable ZDA
echo -e "${YELLOW}Enable ZDA${RESET}" | tee -a "$LOG_FILE"
ubxtool -P 29.20 -p CFG-MSG,240,8,1 | tee -a "$LOG_FILE"

ubxtool -p SAVE

echo -e "${RED}Kill the gps daemon${RESET}"
pkill gpsd

echo -e "${BLUE}Original results (Without configuration)${RESET}"
cat /var/log/ubxtool-time-start.txt

echo -e "${GREEN}Results${RESET}"
cat /var/log/ubxtool-time-end.txt


echo -e "${GREEN}Time accuracy before configuration${RESET}"
#grep -E 'tAcc' /var/log/ubxtool-time-start.txt | tee -a "$LOG_FILE"
grep 'iTOW' /var/log/ubxtool-time-start.txt | grep 'tAcc' | head -n 1 | tee -a "$LOG_FILE"



echo -e "${GREEN}Constellations before configuration${RESET}"
grep -P 'gnssId \d+ svId \d+.*qualityInd \d+' /var/log/ubxtool-time-start.txt | \
awk '{
    gnssType = ""; quality = "";
    for (i=1; i<=NF; i++) {
        if ($i == "gnssId") {
            id = $(i+1);
            if (id == 0) gnssType = "gps";
            else if (id == 1) gnssType = "glonass";
            else if (id == 2) gnssType = "galileo";
            else if (id == 3) gnssType = "beidou";
            else if (id == 4) gnssType = "imes";
            else if (id == 5) gnssType = "qzss";
            else if (id == 6) gnssType = "navic";
            else gnssType = "other";
        }
        if ($i == "qualityInd") quality = $(i+1);
    }
    if (quality >= 6)
        printf "\033[32m%s,%s\033[0m\n", gnssType, quality;
    else
        printf "\033[31m%s,%s\033[0m\n", gnssType, quality;
}'









echo -e "${GREEN}Time accuracy after configuration${RESET}"
grep 'iTOW' /var/log/ubxtool-time-end.txt | grep 'tAcc' | head -n 1 | tee -a "$LOG_FILE"

echo -e "${GREEN}Constellations after configuration${RESET}"
grep -P 'gnssId \d+ svId \d+.*qualityInd \d+' /var/log/ubxtool-time-end.txt | \
awk '{
    gnssType = ""; quality = "";
    for (i=1; i<=NF; i++) {
        if ($i == "gnssId") {
            id = $(i+1);
            if (id == 0) gnssType = "gps";
            else if (id == 1) gnssType = "glonass";
            else if (id == 2) gnssType = "galileo";
            else if (id == 3) gnssType = "beidou";
            else if (id == 4) gnssType = "imes";
            else if (id == 5) gnssType = "qzss";
            else if (id == 6) gnssType = "navic";
            else gnssType = "other";
        }
        if ($i == "qualityInd") quality = $(i+1);
    }
    if (quality >= 6)
        printf "\033[32m%s,%s\033[0m\n", gnssType, quality;
    else
        printf "\033[31m%s,%s\033[0m\n", gnssType, quality;
}'









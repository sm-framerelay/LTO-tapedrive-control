#!/bin/bash

# ==========================================================
# Script settings
# ==========================================================
DEFAULT_TAPE_DEVICE_PATH="/dev/nst0"
TAPE_BLOCK_SIZE=128 # Tape block size in KB
TAR_BLOCK_SIZE=2048 # Block size 512 x TAR_BLOCK_SIZE. Default: 2048 x 512 = 1 MB
DD_BLOCK_SIZE=512 # Block size for direct read from the device in KB

# ==========================================================
# Global variables
# ==========================================================
TAPE_DEVICE=$DEFAULT_TAPE_DEVICE_PATH

# ==========================================================
# Global definitions
# ==========================================================
PRESS_ANY_KEY_CONTINUE="Press any key to continue ..."

# Define standard color codes
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# Define bright color codes
BRIGHT_BLACK='\033[0;90m'
BRIGHT_RED='\033[0;91m'
BRIGHT_GREEN='\033[0;92m'
BRIGHT_YELLOW='\033[0;93m'
BRIGHT_BLUE='\033[0;94m'
BRIGHT_MAGENTA='\033[0;95m'
BRIGHT_CYAN='\033[0;96m'
BRIGHT_WHITE='\033[0;97m'

# Reset color
NC='\033[0m'

# ==========================================================

# ==========================================================
# Functions definition section
# ==========================================================

# Function to print a message in a specified color, defaulting to NC if the color is not defined
function print_message() {
	local color="$1"
	local message="$2"

	# Check if color is empty or undefined, default to NC
	if [ -z "$color" ]; then
		color=$NC
	fi

	echo -e "${color}${message}${NC}"
}

# Function to print an error message
function print_error() {
	print_message "$RED" "${1}"
}

# Function to print a warning message
function print_warn() {
	print_message "$YELLOW" "${1}"
}
# Function which interrupts flow and ask used to press any key
function press_any_continue() {
	echo -en "\n${PRESS_ANY_KEY_CONTINUE}"
	read -n1 -s
}

# Function to show usage example
function show_usage_info() {
	echo -e "\nusage:\n\t $0 <working directory> [-device <device path>] [-tapeblocksz <tape block size in KB>]\n"
	echo -e "examples:\n \t$0 /usr/files"
	echo -e "\t$0 /usr/files -device /dev/nst0"
	echo -e "\t$0 /usr/files -device /dev/nst0 -tapeblocksz 128\n\n"
	echo -e "${BRIGHT_GREEN}*${NC} By default if not specified the ${CYAN}'${DEFAULT_TAPE_DEVICE_PATH}'${NC} device will be used"
}

# Function which showns content of the chosen working directory
function show_workdir_content(){
	echo -e "Directory: ${BRIGHT_CYAN}'$WORKING_DIR'${NC}\n"
	du -ah "$WORKING_DIR"
	total_size=$(du -sb "$WORKING_DIR" | awk '{print $1}')
	total_size_gb=$(awk "BEGIN {printf \"%.2f\", $total_size/1073741824}")
	
	echo -e "\nThe total size of the directory is: ${BRIGHT_GREEN}$total_size_gb GB${NC}"
}

# Function to show data override warning
function write_warning_and_confirm() {
	clear
	echo -e "${BRIGHT_RED}WARNING${NC}: You are about to write data to the tape."
	echo "This action can cause irreversible changes."
	echo "If the data will be written to the wrong position, it might damage or"
	echo "overwrite the existing data on the tape. Please ensure that you"
	echo -e "carefully select the correct actions before proceeding.\n"
	echo -en "${BRIGHT_WHITE}Are you sure you want to continue? (yes/no)${NC}: "
	read confirm
	
	case $confirm in
		[Yy][Ee][Ss])
			return 0  # Success status
			;;
		[Nn][Oo])
			echo "Returning to the main menu."
			return 1
		 	;;
		*)
			echo "Invalid input, please enter yes or no."
			warning_and_confirm
			;;
	esac
}

# Function which shows warning that all content from the directory will be written on tape
function are_you_sure_to_write_all(){
	echo -e "${BRIGHT_RED}WARNING${NC}: You are about to perform an operation that will write"
	echo "all the data from the current directory to the tape."
	echo "Depends on tape position this action will overwrite an existing data on the tape,"
	echo -e "making any previously stored information irretrievable.\n"
	echo -en "${BRIGHT_WHITE}Are you sure to proceed with this operation? (yes/no)${NC}:"
	
	read confirm
	
	case $confirm in
		[Yy][Ee][Ss])
			return 0  # Success status
			;;
		[Nn][Oo])
			return 1
			;;
		*)
			return -1
			;;
	esac
}

# Function which checks mt exist status and terminates flow if there is an error
function check_terminate_existstatus(){
	# Check if the command execution failed
	if [ "$1" -ne 0 ]; then
		# You could parse the error if needed, but generally checking the exit status suffices
		echo "Error: The mt command failed with exit status $EXIT_STATUS."

		# Optionally, capture and check specific error message
		ERROR_MESSAGE=$(mt -f "$DEVICE" "$ACTION" 2>&1)

		if echo "\n\t$ERROR_MESSAGE" | grep -q "No such file or directory"; then
			echo -e "${BRIGHT_RED}WARNING:${NC} No such file or directory. Please check the device path specified."
		else
			print_error "An unknown error occurred: $ERROR_MESSAGE"
		fi
		
		# terminate execution
		press_any_continue
		
		main_menu_loop
	fi
}

# Function to display binary header
function show_binary_header {
	print_message "$BRIGHT_CYAN" "> Binary header of the current record:"
	dd if=$TAPE_DEVICE bs="${DD_BLOCK_SIZE}K" count=1 2>/dev/null | hexdump -C | head -n 10
}

# Function which checks values validity and set tape block size variable 
function check_set_tapeblocksz(){
	# Check if the provided block size is a valid number
	case "$1" in
		0|64|128|256|512|1024|2048|4096|8192)
			TAPE_BLOCK_SIZE="$1"
			;;
		*)
			print_error "Error: Invalid block size. Please enter 64, 128, 256, 512, etc."
			return 1
			;;
	esac
}

# Function which sets tape block size for chosen operation according to global settings
function set_tape_block_size(){
	mt -f $TAPE_DEVICE setblk $(($TAPE_BLOCK_SIZE * 1024))
	local status=$?
	return $status
}

# Function which asks do we need just to list or read content from the Tape
function read_or_list_content(){
	clear
	
	echo -e "${BRIGHT_GREEN}What would you like to do?${NC}\n"
	echo -e "Are you going to just list the tape's content, or read and save its content to the current working directory?\n"
	echo -e "*\tType [${BRIGHT_WHITE}read${NC}] if you are going to restore content from the tape to disk"
	echo -e "*\tPress [${BRIGHT_WHITE}ENTER${NC}] if you like just to list the conent\n"
	echo -en "${BRIGHT_WHITE}Press ENTER or type 'read' to continue${NC}: "
	
	read confirm
	
	echo ""
	
	case $confirm in
		[Rr][Ee][Aa][Dd])
			echo -e "I want to [${BRIGHT_GREEN}READ${NC}] the tape and save its content\n"
			read_all_content_on_tape
			;;
		*)
			echo -e "I want to [${BRIGHT_GREEN}LIST${NC}] to see what's on the tape\n"
			list_all_content_on_tape
			;;
    esac
}

# Function to list all content on tape
function read_all_content_on_tape() {
	echo -en "${BRIGHT_WHITE}Enter the directory name where the tape's content will be saved (default: 'restore')${NC}: "
	read directory_name
	echo ""
	
	# Set default if no input is given
	directory_name=${directory_name:-restore}
	
	PATH_TO_RESTORE="$WORKING_DIR/$directory_name"
	
	# Create the directory if it does not exist
	if [ ! -d "$PATH_TO_RESTORE" ]; then
	  mkdir -p "$PATH_TO_RESTORE"
	  echo -e "Directory $PATH_TO_RESTORE created.\n"
	else
	  echo -e "${BRIGHT_CYAN}The Directory '$PATH_TO_RESTORE' is already exists. The content will be overriden.${NC}\n"
	fi

	print_message "$BRIGHT_YELLOW" "> Getting tape device ready and rewind the Tape to initial position"
	
	# rewind tape to zero position
	mt -f $TAPE_DEVICE rewind

	# Capture an exit status of the mt command
	check_terminate_existstatus "$?"
	
	# set tape block size for all further operations
	set_tape_block_size
	
	echo "> The Tape is in zero position and ready for content enumeration"
	
	echo -e "> Getting device status...\n"
	# show device status
	mt -f $TAPE_DEVICE status
	
	print_message "$BRIGHT_WHITE" "\n> Loop through all records on the Tape\n"

	file_number=0
	while true; do
		echo -e "> Reading content as TAR archive for record number: ${BRIGHT_CYAN}'$file_number'${NC}"
		
		# Attempt to list the contents of the current tar record
		if ! tar -xvf $TAPE_DEVICE -b "$TAR_BLOCK_SIZE" -C "$PATH_TO_RESTORE"; then
			echo -e "> The record ${BRIGHT_CYAN}'$file_number'${NC} is not a TAR file"
			
			# Show binary header of the failed record
			echo "> Inspecting the binary header of the record."
			show_binary_header
		fi
		
		# Try to move to the next record
		echo -e "> [${BRIGHT_GREEN}OK${NC}]\n"

		# Increment the file number
		((file_number++))
		
		mt -f $TAPE_DEVICE fsf 1
		
		# Check for end of the tape
		if [ $? -ne 0 ]; then
			echo "> Reached the end of the tape or encountered an error moving to the next record."
			echo -e "> Total records on Tape: ${BRIGHT_GREEN}$file_number${NC}"
			break
		fi
	done

	print_message "$BRIGHT_YELLOW" "> Rewinding the Tape to initial position ..."
	mt -f $TAPE_DEVICE rewind
	
	echo -e "> [${BRIGHT_GREEN}Done${NC}]"
	
	press_any_continue
		
	main_menu_loop
}

# Function to list all content on tape
function list_all_content_on_tape() {
	print_message "$BRIGHT_YELLOW" "> Getting tape device ready and rewind the Tape to initial position"
	
	# rewind tape to zero position
	mt -f $TAPE_DEVICE rewind

	# Capture an exit status of the mt command
	check_terminate_existstatus "$?"
	
	# set tape block size for all further operations
	set_tape_block_size
	
	echo "> The Tape is in zero position and ready for content enumeration"
	
	echo -e "> Getting device status...\n"
	# show device status
	mt -f $TAPE_DEVICE status
	
	print_message "$BRIGHT_WHITE" "\n> Loop through all records on the Tape\n"

	file_number=0
	while true; do
		echo -e "> Reading content headers as TAR archive for record number: ${BRIGHT_CYAN}'$file_number'${NC}"
		
		# Attempt to list the contents of the current tar record
		if ! tar -tvf $TAPE_DEVICE -b "$TAR_BLOCK_SIZE"; then
			echo -e "> The record ${BRIGHT_CYAN}'$file_number'${NC} is not a TAR file"
			
			# Show binary header of the failed record
			echo -e "> Inspecting the binary header of the record."
			show_binary_header
		fi
		
		# Try to move to the next record
		echo -e "> [${BRIGHT_GREEN}OK${NC}]\n"

		# Increment the file number
		((file_number++))
		
		mt -f $TAPE_DEVICE fsf 1
		
		# Check for end of the tape
		if [ $? -ne 0 ]; then
			echo "> Reached the end of the tape or encountered an error moving to the next record."
			echo -e "> Total records on Tape: ${BRIGHT_GREEN}$file_number${NC}"
			break
		fi
	done

	print_message "$BRIGHT_YELLOW" "> Rewinding the Tape to initial position ..."
	mt -f $TAPE_DEVICE rewind
	
	echo -e "> [${BRIGHT_GREEN}Done${NC}]"
	
	press_any_continue
		
	main_menu_loop
}

# Function which read content at exact possition
function read_content_at_exact_possition(){
	clear

	echo -en "${BRIGHT_WHITE}Enter the record number (default: '0')${NC}: "
	read RECORD_NUMBER
	echo ""
	
	# Check if the input is a digit
	if ! [[ "$RECORD_NUMBER" =~ ^[0-9]+$ ]]; then
		RECORD_NUMBER=0
	fi

	echo -en "${BRIGHT_WHITE}Enter the directory name where the tape's content will be saved (default: 'restore')${NC}: "
	read directory_name
	echo ""
	
	# Set default if no input is given
	directory_name=${directory_name:-restore}
	
	PATH_TO_RESTORE="$WORKING_DIR/$directory_name"
	
	# Create the directory if it does not exist
	if [ ! -d "$PATH_TO_RESTORE" ]; then
	  mkdir -p "$PATH_TO_RESTORE"
	  echo -e "Directory $PATH_TO_RESTORE created.\n"
	else
	  echo -e "${BRIGHT_CYAN}The Directory '$PATH_TO_RESTORE' is already exists. The content will be overriden.${NC}\n"
	fi

	print_message "$BRIGHT_YELLOW" "> Getting tape device ready and rewind the Tape to initial position"
	
	# rewind tape to zero position
	mt -f $TAPE_DEVICE rewind
	
	# Capture an exit status of the mt command
	check_terminate_existstatus "$?"

	# set tape block size for all further operations
	set_tape_block_size

	echo -e "> Searching record number ${BRIGHT_CYAN}'$RECORD_NUMBER'${NC} on the Tape ..."
	mt -f $TAPE_DEVICE fsf $RECORD_NUMBER
	
	# Capture the exit status of the mt command
	EXIT_STATUS=$?

	# Check if the command failed
	if [ $EXIT_STATUS -ne 0 ]; then
		echo "Error: The mt command failed with exit status $EXIT_STATUS."
	fi
	
	echo -e "> Getting device status...\n"
	# show device status
	mt -f $TAPE_DEVICE status
	
	echo -e "\n> Reading content as TAR archive for record number: ${BRIGHT_CYAN}'$RECORD_NUMBER'${NC}"
		
	# Attempt to list the contents of the current tar record
	if tar -xvf $TAPE_DEVICE -b "$TAR_BLOCK_SIZE" -C "$PATH_TO_RESTORE"; then
		echo -e "> [${BRIGHT_GREEN}OK${NC}]\n"
	else
		echo -e "> The record ${BRIGHT_CYAN}'$RECORD_NUMBER'${NC} is not a TAR file"
			
		# Show binary header of the failed record
		echo "> Inspecting the binary header of the record."
		show_binary_header
	fi
	
	print_message "$BRIGHT_YELLOW" "> Rewinding the Tape to initial position ..."
	mt -f $TAPE_DEVICE rewind
	
	echo -e "> [${BRIGHT_GREEN}Done${NC}]"
	
	press_any_continue
		
	main_menu_loop
}

# Function which shows device status
function show_device_status(){
	clear
	
	print_message "$BRIGHT_YELLOW" "> Getting tape device status"
	
	mt -f $TAPE_DEVICE status
	
	# Capture an exit status of the mt command
	check_terminate_existstatus "$?"
	
	press_any_continue
}

# Function which performs tape retension (winding tape to the end and rewind it back to initial position)
function tape_retension(){
	clear
	
	print_message "$BRIGHT_YELLOW" "> Getting tape device status"
	
	mt -f $TAPE_DEVICE status
	
	## Capture an exit status of the mt command
	check_terminate_existstatus "$?"
	
	print_message "$BRIGHT_YELLOW" "> Rewind tape to the End of Media or Device (EOD)"
	
	mt -f $TAPE_DEVICE eod
	
	mt -f $TAPE_DEVICE status
	
	print_message "$BRIGHT_YELLOW" "> Rewind tape to the initial possition"
	
	mt -f $TAPE_DEVICE rewind
	
	mt -f $TAPE_DEVICE status
	
	echo -e "> [${BRIGHT_GREEN}Done${NC}]"
	
	press_any_continue
}

# Function which uses standard mt method to erase the media
function erase_tape(){
	clear
	
	write_warning_and_confirm
	status=$?
	
	# If the user chose not to proceed.
	if [ $status -ne 0 ]; then
		main_menu_loop
	fi

	print_message "$BRIGHT_YELLOW" "> Getting tape device ready and rewind the Tape to initial position"
	
	# rewind tape to zero position
	mt -f $TAPE_DEVICE rewind

	# Capture an exit status of the mt command
	check_terminate_existstatus "$?"
	
	# set tape block size for all further operations
	set_tape_block_size
	
	print_message "$BRIGHT_GREEN" "> The Tape erasing is in progress..."
	
	# execute tape erasing
	mt -f $TAPE_DEVICE erase
	
	# rewind tape to zero position
	mt -f $TAPE_DEVICE rewind
	
	echo -e "> [${BRIGHT_GREEN}Done${NC}]"
	
	press_any_continue
}

#Function which appends new data at the end of Tape data
function append_on_tape(){
	clear

	write_warning_and_confirm
	status=$?
	
	clear
	
	# If the user chose not to proceed.
	if [ $status -ne 0 ]; then
		main_menu_loop
	fi

	# Show what is in the source directory and its size
	show_workdir_content

	echo -e "\nThe directory ${BRIGHT_CYAN}'$WORKING_DIR'${NC} content will be ${BRIGHT_RED}appended${NC} to the tape."
	echo "Each root file or directory will be placed into a separate TAR archive and"
	echo "will be written as an independent record on the tape. The number of TAR archives"
	echo -e "will be equal to the number of files or folders in the current directory.\n"

	are_you_sure_to_write_all
	status=$?
	
	# If the user chose not to proceed.
	if [ $status -ne 0 ]; then
		main_menu_loop
	fi
	
	print_message "$BRIGHT_YELLOW" "\n> Getting tape device ready and check the status\n"
	
	# rewind tape to zero position
	mt -f $TAPE_DEVICE status

	# Capture an exit status of the mt command
	check_terminate_existstatus "$?"
	
	# set tape block size for all further operations
	set_tape_block_size
	
	# positioning Tape at the end of media
	print_message "$BRIGHT_YELLOW" "\n> Searching the EOM (End of Media) mark.\n"

	# EOM throws an input/output error with no reason, so we are supressing all outputs from it
	mt -f $TAPE_DEVICE eom &>/dev/null
	
	# reposition to EOF mark
	mt -f $TAPE_DEVICE bsf
	
	# skip last record EOF mark in order not to corrupt the record
	mt -f $TAPE_DEVICE fsf
	
	# Loop through each item in the root of WORKING_DIR
	for ITEM in "$WORKING_DIR"/*; do
		if [ -e "$ITEM" ]; then
			# Get the base name of the item
			BASENAME=$(basename "$ITEM")

			# Create a tar archive and write it to the tape
			echo -e "> Archiving ${BRIGHT_CYAN}'$BASENAME'${NC} to the tape..."

			if tar -cvf "$TAPE_DEVICE" -b "$TAR_BLOCK_SIZE" -C "$WORKING_DIR" "$BASENAME"; then
				echo -e "> The '$ITEM' is archived to the tape. [${BRIGHT_GREEN}OK${NC}]\n"
			else
				echo -e "> Error archiving '$ITEM': tar command failed. [${RED}FAIL${NC}]\n"
			fi
		fi
	done

	echo -e "> All files and directories have been archived to tape. [${BRIGHT_GREEN}Done${NC}]\n"

	press_any_continue
		
	main_menu_loop
}

#Function which writes all content from source directory on the Tape
function write_all_on_tape(){
	clear

	write_warning_and_confirm
	status=$?
	
	clear
	
	# If the user chose not to proceed.
	if [ $status -ne 0 ]; then
		main_menu_loop
	fi

	# Show what is in the source directory and its size
	show_workdir_content

	echo -e "\nThe directory ${BRIGHT_CYAN}'$WORKING_DIR'${NC} content will be transferred to the tape."
	echo "Each root file or directory will be placed into a separate TAR archive and"
	echo "will be written as an independent record on the tape. The number of TAR archives"
	echo -e "will be equal to the number of files or folders in the current directory.\n"

	are_you_sure_to_write_all
	status=$?
	
	# If the user chose not to proceed.
	if [ $status -ne 0 ]; then
		main_menu_loop
	fi
	
	print_message "$BRIGHT_YELLOW" "\n> Getting tape device ready and rewind the Tape to initial position\n"
	
	# rewind tape to zero position
	mt -f $TAPE_DEVICE rewind

	# Capture an exit status of the mt command
	check_terminate_existstatus "$?"
	
	# set tape block size for all further operations
	set_tape_block_size

	# Loop through each item in the root of WORKING_DIR
	for ITEM in "$WORKING_DIR"/*; do
		if [ -e "$ITEM" ]; then
			# Get the base name of the item
			BASENAME=$(basename "$ITEM")

			# Create a tar archive and write it to the tape
			echo -e "> Archiving ${BRIGHT_CYAN}'$BASENAME'${NC} to the tape..."

			if tar -cvf "$TAPE_DEVICE" -b "$TAR_BLOCK_SIZE" -C "$WORKING_DIR" "$BASENAME"; then
				echo -e "> The '$ITEM' is archived to the tape. [${BRIGHT_GREEN}OK${NC}]\n"
			else
				echo -e "> Error archiving '$ITEM': tar command failed. [${RED}FAIL${NC}]\n"
			fi
		fi
	done

	echo -e "> All files and directories have been archived to tape. [${BRIGHT_GREEN}Done${NC}]\n"

	press_any_continue
		
	main_menu_loop
}

# Function rewind the Tape and eject it from the device
function rewind_and_eject(){
	clear
	
	print_message "$BRIGHT_YELLOW" "\n> Getting tape device ready and rewind the Tape to initial position\n"
	
	# rewind tape to zero position
	mt -f $TAPE_DEVICE rewind

	# Capture an exit status of the mt command
	check_terminate_existstatus "$?"
	
	echo -e "Ejecting the Tape out of the device"
	mt -f $TAPE_DEVICE offline
	
	echo -e "> [${BRIGHT_GREEN}Done${NC}]"
	
	press_any_continue
		
	main_menu_loop
}

# Function which sets Tape block size.
# Standard block sizes are 64, 128, 256, 512, 1024, 2048 KB
# Also 0 might be used as universal or variable block size, this varian depends on device
function set_tape_block_size_dialogue(){
	clear
	
	echo -e "This function sets the Tape block size (the size of single unit of data)."
	echo -e "Usually for better compatibility use 128 KB as a standard value."
	echo -e "Current Tape block size is: ${BRIGHT_GREEN}$TAPE_BLOCK_SIZE${NC} KB\n"
	echo -e "To change the value you have the following options:\n"
	echo -e "*\tSet [${BRIGHT_WHITE}0${NC}] if you like to have variable block size"
	echo -e "*\tSet [${BRIGHT_WHITE}64, 128, 256, 512, 1024 etc.${NC}] if you need specific block size to be set\n\n"
	echo -en "${BRIGHT_WHITE}Enter tape block size or just press [ENTER] to kept value as is${NC}: "
	
	read tapeblocksize
	
	if [ -n "$tapeblocksize" ]; then
		check_set_tapeblocksz "$tapeblocksize"
		if [ $? -eq 1 ]; then
			echo -e "No or invalid value provided, the Tape block size kept the same"
		fi
	fi
	
	echo -e "Tape block size is: ${BRIGHT_GREEN}$TAPE_BLOCK_SIZE${NC} KB"
	
	print_message "$BRIGHT_YELLOW" "> Setting tape block size on device"
	
	# set tape block size for all further operations
	set_tape_block_size
	
	# Capture an exit status of the mt command
	check_terminate_existstatus "$?"

	print_message "$BRIGHT_YELLOW" "> Getting tape device status"
	
	mt -f $TAPE_DEVICE status

	echo -e "> [${BRIGHT_GREEN}Done${NC}]\n"

	press_any_continue
	main_menu_loop
}

# Function to display the main menu
function show_menu() {
	clear
	echo "|___________________________________________________________"
	echo -e "|       ${BRIGHT_CYAN}LTO tape drive control v1.0${NC}"
	echo "|___________________________________________________________"
	echo "|   device:    '$TAPE_DEVICE' [block size '$TAPE_BLOCK_SIZE' KB"]
	echo "|   directory: '$WORKING_DIR'"
	echo "|___________________________________________________________"
	echo -e "|${BRIGHT_WHITE}MENU:${NC}"
	echo -e "|"
	echo -e "|  [1]. ${GREEN}<READ>${NC}  Read all content on Tape"
	echo -e "|  [2]. ${GREEN}<READ>${NC}  Read content at exact position"
	echo -e "|  [3]. ${RED}<WRITE>${NC} Append to the Tape new files"
	echo -e "|  [4]. ${RED}<WRITE>${NC} Write all files to Tape"
	echo -e "|  [5]. ${RED}<WRITE>${NC} Erase the Tape"
	echo -e "|  [6]. ${CYAN}<UTILS>${NC} Show device status"
	echo -e "|  [7]. ${CYAN}<UTILS>${NC} Set Tape block size"
	echo -e "|  [8]. ${CYAN}<UTILS>${NC} Tape retension (winding to the end and back)"
	echo -e "|  [9]. ${CYAN}<UTILS>${NC} Eject the Tape"
	echo -e "|"
	echo -e "|  [0]. Exit "
	echo "|___________________________________________________________"
	echo -e "\nNOTE:"
	echo -e "    * ${GREEN}<READ>${NC}   Data on tape will be kept as is. Safe operations."
	echo -e "    * ${RED}<WRITE>${NC}  Data on tape will be written at the specified position."
	echo -en "\n\n${BRIGHT_WHITE}Enter your choice [0-9]: ${NC}"
}

# Function to loop though main menu items
function main_menu_loop() {
	# Main program loop
	while true; do
		show_menu
		
		read choice

		case $choice in
			1) read_or_list_content;;
			2) read_content_at_exact_possition;;
			3) append_on_tape;;
			4) write_all_on_tape;;
			5) erase_tape;;
			6) show_device_status;;
			7) set_tape_block_size_dialogue;;
			8) tape_retension;;
			9) rewind_and_eject;;
			0) clear; exit 0;;
			*) echo "Invalid option. Please select a valid option (1-9)."; sleep 1;;
		esac
	done
}

# ==========================================================
# Main flow section
# ==========================================================

# Check if a directory is provided as an argument
WORKING_DIR="$1"

# Path normalization
WORKING_DIR="${WORKING_DIR%/}"

if [ -z "$1" ]; then
	clear
	print_warn "WARNING: No <working directory> provided."
	show_usage_info
	echo -e "${BRIGHT_GREEN}*${NC} By default if working directory not specified the current (${CYAN}'.'${NC}) directly will be used"
	press_any_continue
	WORKING_DIR="."
fi


# Check if the provided directory exists and is a directory
if [ ! -d "$WORKING_DIR" ]; then
	print_error "Error: The specified directory does not exist or is not a directory."
	exit 1
fi

shift # Shift past argument value

# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
	case "$1" in
		-device)
		if [ "$#" -gt 1 ]; then
			TAPE_DEVICE="$2"
			shift # Shift past argument value
		else
			print_error "Error: -device requires a device name."
			show_usage_info
			exit 1
		fi
		;;
		-tapeblocksz)
		if [ "$#" -gt 1 ]; then
			check_set_tapeblocksz "$2"
			if [ $? -eq 1 ]; then
				echo -e "No or invalid value provided, the Tape block is set to ${BRIGHT_GREEN}$TAPE_BLOCK_SIZE${NC} KB"
				show_usage_info
				press_any_continue
			fi
			shift # Shift past argument value
		else
			print_error "Error: -tapeblocksz requires a block size (64, 128, 256, 512, 1024, etc)"
			show_usage_info
			exit 1
		fi
		;;
		*)
		print_error "Error: Unknown option $1."
		show_usage_info
		exit 1
		;;
	esac
	shift # Shift past the argument key
done

main_menu_loop
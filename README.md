# LTO-tapedrive-control

*LTO tape drive control* utility for Windows Cygwin terminal and native Linux environments. The purpose of this utility is to provide users with a simple and standardized way to operate tape drive devices. The focus is on simplicity and providing just enough functionality by utilizing standard Linux utilities such as 'mt', 'tar' and 'dd'. Only standardized methods are used for storing and accessing data on tape drives, ensuring that archived data can be restored in the future without complications from proprietary formats or unsupported backup solutions. I believe this utility can be used with any standard tape drives, not just limited to LTO, but also including those that support LTFS. However, the utility ignores LTFS capabilities and treats the entire tape as a single medium for storing archival records.

> **Note:** This project does not aim to compete with other established backup solutions. It is not intended to replace them. The purpose of this utility is to address common data archival tasks for SOHO (Small Office/Home Office) users. The utility has only been tested with the HPE Ultrium 1760 SAS LTO-4 tape drive, which is the device I use and have access to.

## 1 Getting ready

### 1.1 Windows users

First, download and install the Unix-like environment for Windows, [Cygwin](https://www.cygwin.com/install.html), to access the standard Unix utilities needed for LTO tape drive control operations. There's no need to worry; it's simply another command-line tool designed to make life easier for Windows users.

#### 1.1.1 Run Cygwin

Once Cygwin is installed, run it with **Administrator** rights. This is absolutely necessary; otherwise, you won't be able to access the tape devices.

#### 1.1.2 Locate Tape devices

The utility optinally allows you to specify which exact tape device will be used. By default, it's set to *'/dev/nst0'* if no other device is specified. In Windows, under Cygwin, you can attempt to list all available tape devices in your system by running the following magic command in the Cygwin terminal:

```bash
for F in /dev/s* ; do echo "$F    $(cygpath -w $F)" ; done | grep Tape
```

if you have tape device available it will procude something similar to

```bash
/dev/st0    \\.\Tape0
```

Don't use /dev/st0 devices directly, instead add *'n'* to its name. We need to use nst(x) devices, such as nst0, nst1, etc., which do not automatically rewind the tape (these are called non-rewinding devices). Devices without *'n'* in name such as /dev/st(x), automatically rewind the tape, which is not expected by the utility.

#### 1.1.3 Locate Utility and try it

To work with tape drive you need just the only one file from this repository *tapedrive-control.sh*. To run it in Cygwin just type the following command:

```bash
./tapedrive-control.sh
```

For those who are not experts in Unix basics, the following tips will help you navigate through the disk drives. To change a disk or working directory, you can use the following standard command in the Cygwin terminal:

```bash
# To change current disk to disk d:
cd d:

# To see what is in current directory
ls

# To change current directory to another directory
cd dir1/tools/
```

## 2 Usage

### 2.1 How to run the Utility

The utility requires couple optional argumenents to be in place

```bash
./tapedrive-control.sh <working directory> [-device <device path>] [-tapeblocksz <tape block size in KB>]
```

Utility execution examples
```bash

# to set working directory
./tapedrive-control.sh /usr/files

# to specify device path explicitly
./tapedrive-control.sh /usr/files -device /dev/nst0

# to specify device path and tape block size explicitly
./tapedrive-control.sh /usr/files -device /dev/nst0 -tapeblocksz 128
```

#### working directory

Specifies the path to the local disk drive where files ready to be archived on tape are located. This directory is also used as the output directory for tasks that read from tape. If not specified, the current *'.'* directory will be used for all tasks (using the current directory for write operations is not recommended, as it will write the entire directory content to tape).

#### -device

Optional parameter that allows you to specify the tape device path to be used for utility operations. Note that only non-rewinding devices are supported, so device names must be from the /dev/nst(x) range. If not specified, /dev/nst0 will be used by default.

#### -tapeblocksz

Tape block size in kilobytes. This is the minimum size of a single unit on tape. For better compatibility, it's usually recommended to use 128 KB or 64 KB. Some devices allow you to specify a tape block size of zero '0', which means the device will apply a variable block size for different records. When performing read operations, it is worthwhile to try different standard block sizes, including 64 KB and 128 KB, and to try setting the block size to zero '0'. Acceptable values are: 64, 128, 256, 512, 1024, 2048, 4096, and 8192. The tape block size might be changed from main menu in the utility. Pay attention that the utility executes *'mt setblk'* command which set new tape block size, that might affect other utilities or software behaviour in the system. By default the tape block size is 128 KB.

## 3 Functionality

### 3.1 Overview

When you start the utility, it displays a text menu in the terminal with multiple available options. At the top, you can see information about the current working directory, device path, and tape block size. The available functions are divided into those that modify tape content and those that simply read content from a tape. In addition to the read and write functions, there are a couple of utilities that assist in operating the tape device.

```bash
|___________________________________________________________
|       LTO tape drive control (rev. X)
|___________________________________________________________
|   device:    '/dev/nst0' [block size '128' KB]
|   directory: '/usr/files'
|___________________________________________________________
|MENU:
|
|  [1]. <READ>  Read all content on Tape
|  [2]. <READ>  Read content at exact position
|  [3]. <WRITE> Append to the tape new files
|  [4]. <WRITE> Write all files to Tape
|  [5]. <WRITE> Erase the Tape
|  [6]. <UTILS> Show device status
|  [7]. <UTILS> Set Tape block size
|  [8]. <UTILS> Tape retension (winding to the end and back)
|  [9]. <UTILS> Eject the Tape
|
|  [0]. Exit
|___________________________________________________________

NOTE:
    * <READ>   Data on tape will be kept as is. Safe operations.
    * <WRITE>  Data on tape will be written at the specified position.


Enter your choice [0-9]:
```

### 3.2 Available tape operations

#### 3.2.1 Read all content on Tape

The operation allows you to either list or restore content from a tape. The functions rewind the tape to the initial position (BOT) and then attempt to read data as TAR archives. If reading fails, it attempts to read the data as binary content and prints its header.

#### 3.2.2 Read content at exact position

The operation allows you to specify the exact record number on a tape and restore its content from the tape to the disk. This is useful when you know the position of your archived data on the tape. If the position is not specified, the first record at position '0' will be read and restored to the disk.

#### 3.2.3 Append to the Tape new files

This function allows you to append new records to a tape. The purpose of this operation is to find the end of media (EOM) and place new records after it. All data from the current working directory will be written to the tape. Note that this method is potentially dangerous for tape media that contains custom or non-standard data records without conventional End-Of-File (EOF) marks. However, tapes written by this utility are fully compatible with data appending procedures, as they use standard data separation approaches for tape media.

#### 3.2.4 Append to the Tape new files

The operation writes all data from the current working directory to a tape. The tape will be written from the beginning, as this operation first rewinds the tape to the initial position and then writes each file in the working directory into separate TAR archives. This operation overrides all data on your tape and replaces it with new records from the current working directory.

#### 3.2.5 Erase the Tape

The operation rewinds the tape to the initial position and then runs the standard *'mt'* command *'erase'*. Pay attention that it's rather long operation (up to couple hours) which re-writes the whole tape volume using special binary data pattern (usually *'100 000 000 100 000 000 100 000 000'b*). All information on the tape will be erased.

#### 3.2.6 Show device status

This function is a shortcut for the standard *'mt'* command *'status'*. It prints valuable information about the device status, current tape block size, inserted media type, and its position. For instance, this function can be used to check that the device is available and ready for work. Example of such output is the following:

```bash
> Getting tape device status
STK 9840 tape drive:
File number=0, block number=0, partition=0
Tape block size 0 bytes. Density code 0x46 (LTO-4).
Soft error count since last status=0
General status bits on (410b0000):
 BOT ONLINE IM_REP_EN

Press any key to continue ...
```

#### 3.2.7 Set Tape block size

The operation allows you to change the tape block size and set it to any available standard block size. This function may be necessary when a tape has been written with an unknown block size, and you need to find the correct one to read its content. Typically, a block size of zero '0' forces the device to use a variable block size, which can sometimes allow data to be read from the tape. Note that an incorrectly set block size may reduce reading speed and cause read errors, making it impossible to read the data from the tape. For better compatibility, stick to 128 KB and 64 KB, as these sizes are fairly universal and work on most LTO devices.

#### 3.2.8 Tape retension

This function works only for non-empty LTO cartridges. Unfortunately, the standard *'mt'* command *'retension'* doesn't work, at least for my LTO device, which is why there was an attempt to emulate retension behavior by scanning the tape until the End-Of-Device (EOD).

#### 3.2.9 Eject the Tape

The function rewinds the tape to the initial position and then executes the standard *'mt'* command *'offline'*, which results in ejecting the tape.

## 4 Data formats and patterns

The purpose of this utility is to use only standard Unix/Linux components, formats, and approaches to ensure archived data is compatible across a wide variety of systems from different generations. Therefore, the simplest operations and formats are utilized in this utility.

### 4.1 TAR archives

Data records are archived using TAR without data compression. Each file or folder in the current working directory is put into a separate TAR archive, so you will see as many TAR archives on the tape as there are files and folders in the root of your working directory. Records are created using the following TAR archive creation command.:

```bash
tar -cvf "$TAPE_DEVICE" -b "$TAR_BLOCK_SIZE" -C "$WORKING_DIR"
```

### 4.1 Records separation pattern

The utility does not explicitly add any additional End-Of-File (EOF) records after the TAR records. Instead, it relies on TAR to create separation between records with just one EOF mark at the end of each TAR archive. At the end of all records there is usually End-Of-Media (EOM) mark which is set automatically by a device, the utility does not set EOM mark explicitly. The overall data pattern on a tape is as follows:

```bash
[ARCHIVE 1][EOF][ARCHIVE 2][EOF][ARCHIVE N][EOF][EOM]
```

## 5 Troubleshooting

### 5.1 Incorrectly specified device path

The most common mistake is incorrectly specifying a device path. Ensure that the device is present in your system and can be physically seen among the tape devices. Make sure you are using a non-rewinding device, as the same physical device is usually available with two options: with (*'/dev/st(x)'*) and without automatic rewinding (*'/dev/nst(x)'*). The utility uses non-rewinding devices and assumes this is specified. If there are any errors with the device, the utility will throw an error indicating something is wrong with the device path. To check the device's operation, the simplest way is to use the device status function of the utility.
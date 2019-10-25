***********************************************************************
***                                                                 ***
***                          R o m W B W                            ***
***                                                                 ***
***                    Z80/Z180 System Software                     ***
***                                                                 ***
***********************************************************************

This directory ("Binary") is part of the RomWBW System Software 
distribution archive.  It contains the completed binary outputs of 
the build process.  As described below, these files are used to 
assemble a working RetroBrew Computers system.

The files in this directory are created by the build process that is 
documented in the ReadMe.txt file in the Source directory.  When 
released the directory is populated with the default output files.  
However, the output of custom builds will be placed in this directory 
as well.

If you only see a few files in this directory, then you downloaded 
just the source from GitHub.  To retrieve the full release download 
package, go to https://github.com/wwarthen/RomWBW.  On this page, 
look for the text "XX releases" where XX is a number. Click on this 
text to go to the releases page.  On this page, you will see the 
latest releases listed.  For each release, you will see a package 
file called something like "RomWBW-2.9.0-Package.zip".  Click on the 
package file for the release you want to download.

ROM Firmware Images (<plt>_<cfg>.rom)
-------------------------------------

The files with a ".rom" extension are binary images ready to program 
into an appropriate PROM.  These files are named with the format 
<plt>_<cfg>.rom. <plt> refers to the primary platform such as Zeta, 
N8, Mark IV, etc.  <cfg> refers to the specific configuration.  In 
general, there will be a standard configuration ("std") for each 
platform.  So, for example, the file called MK4_std.rom is a ROM 
image for the Mark IV with the standard configuration. If a custom 
configuration called "custom" is created and built, a new file called 
MK4_custom.rom will be added to this directory.

Documentation of the pre-built ROM Images is contained in the 
RomList.txt file in this directory.

ROM Executable Images (<plt>_<cfg>.com)
---------------------------------------

When a ROM image (".rom") is created, an executable version of the 
ROM is also created.  These files have the same naming convention as 
the ROM Image files, but have the extension ".com".  These files can 
be copied to a working system and run like a normal application.

When run on the target system, they install in RAM just like they had 
been programmed into the ROM.  This allows a new ROM build to be 
tested without reprogramming the actual ROM.

WARNING: In a few cases the .com file is too big to load.  If you get 
a message like "Full" or "BAD LOAD" when trying to load one of the 
.com files, it is too big.  In these cases, you will not be able to 
test the ROM prior to programming it.

ROM Binary Images (<plt>_<cfg>.img)
-----------------------------------

Also when a ROM image is created, a third variation of the ROM is 
created again with the same naming convention, but with the extension 
of .img.  These files are similar to the .com files in that they can 
be used to test a ROM build without actually programming a new ROM.  
The .img files are specifically for loading via UNA from a FAT file 
system.  The functionality of the UNA FAT file system loader is 
beyond the scope of this document.

VDU ROM Image (vdu.rom)
-----------------------

The VDU video board requires a dedicated onboard ROM containing the 
font data.  The "vdu.rom" file contains the binary data to program 
onto that chip.

Disk Images (fd*.img, hd*.img)
------------------------------

RomWBW includes a mechanism for generating floppy disk and hard disk 
binary images that are ready to copy directly to a floppy, hard disk, 
CF Card, or SD Card which will then be ready for use in any 
RomWBW-based system.

Essentially, these files contain prepared floppy and hard disk images 
with a large set of programs and related files.  By copying the 
contents of these files to appropriate media as described below, you 
can quickly create ready-to-use media.  Win32DiskImager or
RawWriteWin can be used to copy images directly to media.  These
programs are included in the RomWBW Tools directory.

The fd*.img files are floppy disk images.  They are sized for 1.44MB 
floppy media and can be copied to actual floppy disks using 
RawWriteWin (as long as you have access to a floppy drive on your 
Windows computer).  The resulting floppy disks will be usable on any 
RomWBW-based system with floppy drive(s).

Likewise, the hd*.img files are hard disk images.  Each file is 
intended to be copied to the start of any type of hard disk media 
(typically a CF Card or SD Card). The resulting media will be usable 
on any RomWBW-based system that accepts the corresponding media type.

Note that the contents of the floppy/hard disk images are created by 
the BuildImages.cmd script in the Source directory.  Additional 
information on how to generate custom disk images is found in the 
Source\Images directory.

Propeller ROM Images (*.eeprom)
-------------------------------

The files with and extension of ".eeprom" contain the binary images 
to be programmed into the Propeller-based boards.  The list below 
indicates which file targets each of the Propeller board variants:

	ParPortProp	ParPortProp.eeprom
	PropIO V1	PropIO.eeprom
	PropIO V2	PropIO2.eeprom

Refer to the board documentation of the boards for more information 
on how to program the EEPROMs on these boards.

Apps Directory
--------------

The Apps subdirectory contains the executable application files that
are specific to RomWBW.  The source for these applications is found
in the Source\Apps directory of the distribution.
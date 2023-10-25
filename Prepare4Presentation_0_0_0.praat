##
#	This script prepares all mono sound files in a directory for a presentation:
#		• sets the amplitude to maximum
#		• adds (weak) noise at the beginning and end to 'wake up' audio equipment.
#
#	Version 0.0.0, Henning Reetz, 25-oct-2023	Modified copy of PreProcess_4_0_0
#
#@@ can be speeded up by avoiding repetetive generation of noises by checking for smapling rate and channel change
#
#	Tested with Praat 6.3.09
#
##

clearinfo
version = 0
revision = 0
bugfix = 0

# clear feedback window, check Praat version (gets OS too to define orientation of
# 'slash' ('/' or '\') in paths) and get date_time$ to make file names unique
clearinfo
call CheckPraatVersion
call GetDateTime

#
## 1) Inquire some parameters
#	! Note that 'form' may only be used once in a script!
#

form Prepare4Process parameters:
	comment Leave the directory path empty if you want to use the current directory.
		word directory
	comment What is the extension of the files you want to prepare?
		word Extension wav
	comment __________________________________________________________________________________________________
	comment Crop to zero-crossings?
		boolean Crop_to_zero_crossings 1
endform

feedback = 1
scale = 0.99
noise_length = 0.1
noise_amp = 0.01
presentation$ = "_presentation"

# check whether the extension needs a dot
dot = startsWith (extension$,".")
if (dot = 0)
	extension$ = "." + extension$
endif

# check whether the path needs a slash
if (directory$ <> "")
	if (!endsWith(directory$,slash$))
		directory$ = directory$ + slash$
	endif
else
	directory$ = ".'slash$'"
endif

# create list of sound files

list_obj = Create Strings as file list: "file_list", "'directory$'*'extension$'"
nr_files = Get number of strings

#
## Go thru all files
#

intensity_warning = 0

for i_file to nr_files
	selectObject: list_obj
	file_name$ = Get string: 'i_file'
	wav_obj = Read from file: "'directory$''file_name$'"
	file_name$ = selected$("Sound")

	if (feedback)
		print Handling 'file_name$'
	endif

# generate out file name
	out_file_name$ = file_name$ - extension$
	out_file_name$ += presentation$ + ".wav"

# remove DC offset	
	Subtract mean

# crop to zero crossings if required
	if (crop_to_zero_crossings)
		zero_on = Get nearest zero crossing: 1, 0
		end = Get end time
		zero_off = Get nearest zero crossing: 1, end
		help_obj = Extract part: zero_on, zero_off, "rectangular", 1, "no"
		removeObject: wav_obj
		wav_obj = help_obj
	endif

# scale
	Scale peak: scale

# create faint noise
	freq = Get sampling frequency
	nr_chan = Get number of channels
	noise_obj = Create Sound from formula: "WhiteNoise", 1, 0, noise_length, freq, "'noise_amp' * randomGauss(0,0.1)"
	if (nr_chan = 2)
		help_obj = Convert to stereo
		removeObject: noise_obj
		noise_obj = help_obj
	endif

	selectObject: wav_obj
	plusObject: noise_obj
	concat1_obj = Concatenate

	selectObject: noise_obj
	plusObject: concat1_obj
	concat2_obj = Concatenate

# write file
	Write to WAV file: "'directory$''out_file_name$'"
	removeObject: wav_obj, noise_obj, concat1_obj, concat2_obj

	if (feedback)
		perc = (i_file/nr_files) * 100
		print  finished ('perc:2'%).'newline$'
	endif
	
# going thru all files
endfor									

# clean up

removeObject: 'list_obj'

printline 'newline$''nr_files' files processed.
printline Program completed.


##########################################################################################
#
# Procedure to convert Praat's date and time to a date-and-time string
#
##########################################################################################

procedure GetDateTime
# from 6.1.51:
# date# () -> { 2021, 7, 7, 12, 5, 46 }

	help# = date#()

# this does NOT work in praat and it would have no leading zeros):
# 	date_time$ = "'help$#[1]''help#[2]''help#[3]'_'help#[4]''help#[5]''help#[6]'"

	date_time$ = ""
	for i to 6
		x = help#['i']
		if (x < 10)
			date_time$ += "0'x'"
		else
			date_time$ += "'x'"
		endif
		if (i = 3)
			date_time$ += "_"
		endif
	endfor

endproc


##########################################################################################
#
# Procedure to check Praat's program version
#
##########################################################################################

procedure CheckPraatVersion
	lowest_praat_version = 6
	lowest_praat_revision = 1
	lowest_praat_fix = 51

	left_dot = index(praatVersion$,".")
	right_dot = rindex(praatVersion$,".")

	praat_version = number(replace_regex$(praatVersion$,"\..*","",1))
	praat_revision$ = replace_regex$(praatVersion$,"\d+?\.","",1)
	praat_revision = number(replace_regex$(praat_revision$,"\..*","",1))
	if (left_dot = right_dot)
		praat_fix = 0
	else
		praat_fix = number(replace_regex$(praatVersion$,"^\d+?\..+?\.","",1))
	endif

	if (praat_version<lowest_praat_version)
		too_low = 1
	elsif (praat_revision<lowest_praat_revision)
		too_low = 1
	elseif (praat_fix<lowest_praat_fix)
		too_low = 1
	else
		too_low = 0
	endif
	if (too_low)
		printline Please update your Praat version to 'lowest_praat_version'.'lowest_praat_revision'.'lowest_praat_fix' or higher (you have 'praatVersion$').
		printline Downlaod newest Praat version from https://praat.org
		exit
	endif

# find out slash type
	system$ = Report system properties
	mac = index(system$,"macintosh")
	pc = index(system$,"WIN")
	linux = index(system$,"linux")

	if (mac or linux)
		slash$ = "/"
	elsif (pc)
		slash$ = "\"
	else
		printline Unknown system version. Please correct "slash" in CheckPraatVersion.
		printline 'system$'
		exit
	endif

endproc


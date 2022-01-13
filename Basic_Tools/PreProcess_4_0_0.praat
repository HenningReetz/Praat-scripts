##
#	This script can monorize, resample, level and zero-adjust all sound files in a directory.
#
#	Version 1.0, Henning Reetz, 17-sep-2007
#	Version 1.1, Henning Reetz, 13-jun-2009	only minor adaptations
#	Version 2.0, Henning Reetz, 07-dec-2014	adapted to new Praat script syntax
# 	Version 2.1, Henning Reetz, 16-dec-2014	added 'removeObject:'
# 	Version 2.2, Henning Reetz, 06-oct-2016	changed "rate" to rate in resample
# 	Version 3.0, Henning Reetz, 07-dec-2018	included intensity adjustment
# 	Version 3.1, Henning Reetz, 08-dec-2018	new scale form
# 	Version 3.2, Henning Reetz, 24-sep-2019	handle deleting of multiple sounds correctly
# 	Version 3.3, Henning Reetz, 12-may-2020	feedback switch, some cleanup
# 	Version 3.4.0, Henning Reetz, 12-jan-2022	backback switch, correct 'outname$' error
# 	Version 3.5.0, Henning Reetz, 13-jan-2022	added zero-crossing option
# 	Version 4.0.0, Henning Reetz, 13-jan-2022	changed user interface, some cleanup
#
#	Tested with Praat 6.2
#
# @@ To do:
# @@ check for reasonable intensity scale; add mean and median option
##

clearinfo
version = 4
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

form PreProcess parameters:
	comment Leave the directory path empty if you want to use the current directory.
		word directory
	comment What is the extension of the files you want to convert?
		word Extension wav
	comment __________________________________________________________________________________________________
	comment New sampling rate: (type '0' if no resampling is required)
		integer Rate 0
	comment Is a conversion to mono required?
		choice mono_flag 1
			button no change
			button take left channel
			button take right channel
			button mix channels
	comment Scale amplitude (<1), intensity (dB, e.g. 70) or none (0)?
		real Scale 0.99
		boolean Remove_DC_offset 1
		boolean Crop_to_zero_crossings 0
		boolean Keep_backup 1
endform

feedback = 0

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

if (keep_backup)
	backup_dir$ = "'directory$'Backup_'date_time$''slash$'"
	createFolder: backup_dir$
endif

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

	if (keep_backup)
		Write to WAV file: "'backup_dir$''file_name$'.wav"
	endif

# find out whether the file needs to be monorized
	if (mono_flag <> 1) 
# find out whether the file has more than one channel to begin with
		nr_chan = Get number of channels
		if (nr_chan > 1)
			if (mono_flag = 2)
				help_obj = Extract left channel
			elsif (mono_flag = 3)
				help_obj = Extract right channel
			elsif (mono_flag = 4)
				help_obj = Convert to mono
			else
				printline Mono_flag has an unexpected value: 'm ono_flag'.
				printline Program aborted.
				exit
			endif
			removeObject: wav_obj
			wav_obj = help_obj
		endif
	endif

# resample if required (generates new sound object)
	if (rate <> 0) 
		old_rate = Get sampling frequency
		if (old_rate <> rate)
			help_obj = Resample: rate, 50
			removeObject: wav_obj
			wav_obj = help_obj
		endif
	endif

# check for removing DC offset	
	if (remove_DC_offset)
		Subtract mean
	endif

	if (crop_to_zero_crossings)
		zero_on = Get nearest zero crossing: 1, 0
		end = Get end time
		zero_off = Get nearest zero crossing: 1, end
		help_obj = Extract part: zero_on, zero_off, "rectangular", 1, "no"
		removeObject: wav_obj
		wav_obj = help_obj
	endif

# scale (if required)
	if (scale > 1.0)
		Scale intensity: scale
	elsif (scale > 0)
		Scale peak: scale
	endif

# rate change or intensity scaling might lead to clipping; rescale if necessary
	scale_message = 0
	if ((rate <> 0) or (scale > 0))
		max_amplitude = Get absolute extremum: 0, 0, "None"
# force scaling if amplitude is too high
		if (max_amplitude > 1)
			Scale peak: 0.99
			if (feedback)
				print  scaled to avoid clipping
			else
				print 'file_name$' scaled to avoid clipping
			endif
			if (scale > 1.0)
				print , dB-intensities of all files do not match!
				scale_message = 1
				intensity_warning = 1
			endif
			printline
		endif
	endif

# write file
	Write to WAV file: "'directory$''file_name$'.wav"
	removeObject: wav_obj

	if (feedback)
		perc = (i_file/nr_files) * 100
		if (scale_message = 0)
			print  finished ('perc:2'%).'newline$'
		else
			print ('perc:2'%)'newline$'
		endif
	endif
	
# going thru all files
endfor									

# clean up

removeObject: 'list_obj'

printline 'newline$''nr_files' files processed.
if (intensity_warning <> 0)
	printline Run the script again with a lower dB value to have the same intensity for all files.
endif
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


##########################################################################################
#
# Procedure to add a slash to directory names
#
##########################################################################################

procedure AddSlash help$

	if (help$ = "")
#		help$ = "." + slash$
	elsif (help$ = "?")
		help$ = ""
	elsif (not endsWith(help$,slash$))
		help$ += slash$
	endif

endproc


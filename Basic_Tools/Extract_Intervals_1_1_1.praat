##
#	This script extracts all segments of all .wav and .TextGrid files in a directory
#	and saves the labelled TextGrid intervals of the .wav file as a new .wav file with
#	the same name as the label given in the .TextGrid file.
#
#  	Version 0.0, Henning Reetz, 24-sep-2019
#  	Version 1.0, Henning Reetz, 25-sep-2019, improved version
#  	Version 1.1, Henning Reetz, 25-sep-2019, creates unique filenames
#  	Version 1.1.1, Henning Reetz, 27-oct-2021, removed comments after statements
#
#@@ Be more gentle with non-existing TextGrid files and missing interval Grids.
#
#	Tested with Praat 6.0.43
#
##

# code for interval tier type
c_interval_tier = 1

clearinfo

#
## 1) Inquire some parameters
#	! Note that 'form' may only be used once in a script!
# @@ is that still correct?
#

form Resample parameters:
	comment Leave the directory path empty if you want to use the current directory.
		word directory
	comment What is the extension of the files you want to convert?
		word extension wav
	comment Which (interval) tier to use?
		integer tier 1
	comment new wav-file name?
		choice name_flag 1
			button label only (ev. with 1, 2, 3...)
			button source_label
			button label_source
	comment __________________________________________________________________________________________________
	comment Do you want to remove a DC-offset of each interval?
		boolean zero_flag 1
	comment Scaling required?
		choice scale_flag 2
			button no scaling
			button peak amplitude
			button intensity
	comment Scale amplitude (0..1) or intensity (dB, e.g. 70)?
		real scale 0.99
endform

# check whether the extension needs a dot
dot = startsWith (extension$,".")
if (dot = 0)
	extension$ = "." + extension$
endif

# check whether the path needs a slash
if (directory$ <> "")
	slash = endsWith (directory$,"/")
	if (slash = 0)
		directory$ = directory$ + "/"
	endif
endif

# set parameters for users that use separate directories for different files
wav_directory$ = directory$
grid_directory$ = directory$
result_directory$ = directory$


# create list of sound files

Create Strings as file list: "file_list", "'wav_directory$'*'extension$'"
nr_files = Get number of strings

#
## Go thru all files
#

intensity_warning = 0

for i_file to nr_files
	selectObject: "Strings file_list"
	file_name$ = Get string: 'i_file'
	Read from file: "'wav_directory$''file_name$'"
	in_name$ = selected$("Sound")
	print Handling 'in_name$'

# open TextGrid file (make the handling of non-existing files a bit nicer…)
	grid_file$ = "'grid_directory$''in_name$'.TextGrid"
	if !fileReadable (grid_file$)
		printline
		printline  File "'grid_file$'" not found!
		printline  Program aborted.
		exit
	endif
	Read from file: "'grid_directory$''in_name$'.TextGrid"
	tier_type = Is interval tier... 'tier'
	if (tier_type <> c_interval_tier)
		printline
		printline  Tier 'tier' in file "'grid_file$'" is not an interval tier!
		printline  Program aborted.
		exit
	endif

#
## Go thru all intervals
#
	nr_intervals = Get number of intervals: 'tier'
	for i_interval to nr_intervals
		selectObject: "TextGrid 'in_name$'"
		label$ = Get label of interval: 'tier', 'i_interval'

# skip unlabelled intervals
		if (label$ <> "")
			start = Get start time of interval: 'tier', 'i_interval'
			end = Get end time of interval: 'tier', 'i_interval'
			selectObject: "Sound 'in_name$'"
			Extract part: 'start', 'end', "rectangular", 1, "no"

# check for removing DC offset
			if (zero_flag = 1)
				Subtract mean
			endif

# scale (if required)
			if (scale_flag = 2)
				Scale peak: scale
			elsif (scale_flag = 3)
				Scale intensity: scale
			endif

# rate change or intensity scaling might lead to clipping; rescale if necessary
			scale_message = 0
			if (scale_flag <> 1)
				max_amplitude = Get absolute extremum: 0, 0, "None"
# force scaling if amplitude is too high
				if (max_amplitude > 1)
					Scale peak: 0.99
					print  scaled to avoid clipping
					if (scale_flag = 3)
						print , dB-intensities of all files do not match!
						scale_message = 1
						intensity_warning = 1
					endif
				endif
			endif

# generate outfile name
			if (name_flag = 1)
				nn = 0
				out_file$ = "'result_directory$''label$'.wav"

# for a non-unique name; add a number to the name until a new name is found
				while fileReadable (out_file$)
					nn = nn + 1
					out_file$ = "'result_directory$''label$'_'nn'.wav"
				endwhile
			elsif (name_flag = 2)
				out_file$ = "'result_directory$''in_name$'_'label$'.wav"
			elsif (name_flag = 3)
				out_file$ = "'result_directory$''label$'_'in_name$'.wav"
			else
				printline
				printline Illegal value for name_flag: 'name_flag'
				exit
			endif
			Write to WAV file: "'out_file$'"
			Remove
# label is not empty
		endif
# going thru labels
	endfor

	selectObject: "TextGrid 'in_name$'"
	Remove
	selectObject: "Sound 'in_name$'"
	Remove

	perc = (i_file/nr_files) * 100
	if (scale_message = 0)
		print  finished ('perc:2'%).'newline$'
	else
		print ('perc:2'%)'newline$'
	endif
# going thru all files
endfor

# clean up

removeObject: "Strings file_list"

printline 'newline$''nr_files' files processed.
if (intensity_warning <> 0)
	printline Run the script again with a lower dB value to have the same intensity for all files.
endif
printline Program completed.

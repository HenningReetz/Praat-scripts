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
#
#	Tested with Praat 6.1.09
#
##

clearinfo

#
## 1) Inquire some parameters
#	! Note that 'form' may only be used once in a script!
#

form PreProcess parameters:
	comment Leave the directory path empty if you want to use the current directory.
		word directory
	comment What is the extension of the files you want to convert?
		word extension wav
	comment __________________________________________________________________________________________________
	comment New sampling rate: (type '0' if no resampling is required)
		integer rate 0
	comment Is a conversion to mono required?
		choice mono_flag 2
			button no change
			button take left channel
			button take right channel
			button mix channels
	comment Do you want to remove a DC-offset?
		boolean zero_flag 1
	comment Scaling required?
		choice scale_flag 2
			button no scaling
			button peak amplitude
			button intensity
	comment Scale amplitude (0..1) or intensity (dB, e.g. 70)?
		real scale 0.99
endform

feedback = 0

# check whether the extension needs a dot
dot = startsWith (extension$,".")
if (dot = 0)
	extension$ = "." + extension$
endif

# check whether the path needs a slash
if (directory$ <> "")
	if (!endsWith(directory$,"/"))
		directory$ = directory$ + "/"
	endif
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
	in_name$ = selected$("Sound")
	if (feedback)
		print Handling 'in_name$'
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
				printline Mono_flag has an unexpected value: 'mono_flag'.
				printline Program aborted.
				exit
			endif
			out_name$ = selected$("Sound")
			removeObject: wav_obj
			wav_obj = help_obj
		endif
	endif

# resample if required (generates new sound object)
	if (rate <> 0) 
		old_rate = Get sampling frequency
		if (old_rate <> rate)
			help_obj = Resample: rate, 50
			out_name$ = selected$("Sound")
			removeObject: wav_obj
			wav_obj = help_obj
		endif
	endif

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
	if ((rate <> 0) or (scale_flag <> 1))
		max_amplitude = Get absolute extremum: 0, 0, "None"
# force scaling if amplitude is too high
		if (max_amplitude > 1)
			Scale peak: 0.99
			if (feedback)
				print  scaled to avoid clipping
			else
				printline 'file_name$' scaled to avoid clipping
			endif
			if (scale_flag = 3)
				print , dB-intensities of all files do not match!
				scale_message = 1
				intensity_warning = 1
			endif
		endif
	endif

# write file
	Write to WAV file: "'directory$''out_name$'.wav"
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

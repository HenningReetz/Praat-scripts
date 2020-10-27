##
#	This script generates 'Intensity contours' of segments.
#
#	This script opens all sound files in a directory and their associated TextGrids,
#	computes the intensity of segments that can be defined in several ways in steps
#	and writes the results as a percentage of the time of a segment to a text file
#	"intensity_contour_results<date_time>.txt" at the same directory of the sound files.
#
#	There are no version below 4, because I copied it from higher versions of other
#	scripts; with version 4, many new features were added and I wanted to reflect these
#	extended features in the version number
#	Version 4.0, Henning Reetz, 06-sep-2016; modified version of formant_contour_4_2.praat
#
#	Tested with Praat 6.1.12
#
##

version = 4
revision = 0
bugfix = 0

clearinfo

##
# 1) Inquire and check some parameters
# ! Note that 'form' may only be used once in a script!
##

form Intensity contour parameters:
	comment Leave the directory path empty if you want to use the current directory.
		text Directory
		integer Tier_to_be_analysed 1
	comment ______________________________________________________________________________________________________________
	comment <label>, <list>.txt, '.' (= only labelled), or empty (= all)
		sentence Label .
	comment Nr. of measurements per interval. 1: only center, 2: only edges
		integer Number_of_measurements 3
	choice Unit: 3
		button energy
		button sone
		button dB
	comment ______________________________________________________________________________________________________________
	boolean Report_absolute_times 0
	choice Report_skipped_intervals: 2
		button All
		button None
		word Missing_values_symbol .
endform

##
# 2) Change the following settings as you prefer them (and/or add things from the form menu below)
##

# add a slash ("/") to the end of the directory name if necessary
## do this for every directory in case you use different ones
if (directory$ <> "")
	if (!endsWith(directory$,"/"))
		directory$ = directory$ + "/"
	endif
endif

# directories for .wav, .TextGrid, result- and support-files (must end with a slash "/"!
wav_directory$ = directory$
grid_directory$ = directory$
result_directory$ = directory$
support_directory$ = directory$

# Examples (for being one directory above the 4 sub-directories):
# In case you want the path for the .wav file in the output, set 'path_name' to 1
#	wav_directory$ = "./Sound/"
#	grid_directory$ = "./Grid/"
#	result_directory$ = "./Result/"
#	support_directory$ = "./Support/"
path_name = 0

# extension of the audio files
ext$ = ".wav"

# report time of measurement
t_request = report_absolute_times

# should there be minimal user feedback to speed up processing (= 1) or more feedback (= 0)
user_feedback = 1

# should there be no processing information from Praat (= "noprogress") or not (= ""  ; i.e. empty string)
np_string$ = "noprogress"

# should there be a dummy data header to force correct data type in JMP or other tables (= 1) or not (= 0)
dummy_data_header = 0

# intensity computation parameters
step_rate = 0
low_F0 = 50

# report duration in ms (duration_in_ms = 1) or seconds (duration_in_ms = 0)
duration_in_ms = 1

# maximal number of intervals for reporting the contour
max_step = 100


##
# 3) Check input and create result file
##

# check and recode user input
missing_value$ = "'tab$''missing_values_symbol$'"
call CheckParameters

# create result file
call CreateResultFile


##
#  4) Get file names from a directory
#	In case the whole file should be measured, look for all wav files.
##

# nr. of files that have been processed
nr_grid = 0
nr_wav = 0

# total nr. of segments of all files
tot_segments = 0

# create list of sound files
wav_list_obj = Create Strings as file list:  "file_list", "'wav_directory$'*'ext$'"
nr_wav_files = Get number of strings

# Give minimal user feedback
if (!user_feedback)
	print Computing...
endif


##
# 5) Go thru all files
##

for i_file to nr_wav_files
	selectObject: wav_list_obj
	wav_name$ = Get string: i_file
	wav_obj = Read from file: "'wav_directory$''wav_name$'"
# Do not use "selected$("Sound")" go get the sound file name, because PRAAT converts
# many symbols (like a tilde "~") into an underline ("_")
	base_name$ = replace_regex$(wav_name$,"'ext$'$","",1)
	nr_wav += 1

	if (user_feedback)
		print Handling 'base_name$'
	endif

# check whether TextGrid exists; if not: perhaps the user wnats to analyse whole files
	grid_name$ = grid_directory$+base_name$+".TextGrid"
	no_grid = 0
	if (fileReadable(grid_name$))

# TextGrid file exists?
		grid_obj = Read from file: grid_name$
		tier = tier_to_be_analysed
		nr_grid += 1

# if there is no TextGrid file then create fake grid to allow rest of processing assuming whole file
	else
		grid_obj = To TextGrid: "dummy", ""
		tier = 1
		no_grid = 1
	endif

	nr_tiers = Get number of tiers
	if (tier <= nr_tiers)

# check whether tier is an interval tier.
		tier_is_interval = Is interval tier: tier
		if  (tier_is_interval)

# if any of the above attempts to open a file worked, we should be save now
# compute intensity for whole file

			selectObject: wav_obj
			intensity_obj = 'np_string$' To Intensity: low_F0, step_rate, "yes"

##
# 6) Go thru all segments
##

# Use the TextGrid to find all segments.
			selectObject: grid_obj
			nr_segments = Get number of intervals: tier
			nr_measured_segments = 0

# go thru all segments
			for i_segment to nr_segments
				selectObject: grid_obj
				interval_label$ = Get label of interval: tier, i_segment

# find center and measure length
				t_left 	= Get starting point: tier, i_segment
				t_right = Get end point:      tier, i_segment
				duration = t_right - t_left
				duration_ms = duration * 1000

# Get intensity chunks of segment; use 'mid' as guiding time
				if (number_of_measurements = 1)
					mid = (t_right + t_left) / 2
					perc = 50

# compute positions for analysis windows at segment boundaries
				else
					dur = (t_right - t_left) / (number_of_measurements-1)
					mid = t_left
					perc = 0
				endif
#
# check whether this segment should be reported
# (it's a bit of overkill here, but I use the same mechanisme as the other analyses)
#
				l_flag = 0

#
# check whether this data should be reported
#

### check label

# report all intervals
				if ((label_flag = label_none) or no_grid)
					l_flag = 1

# report list of labels
				elsif (label_flag = label_list)
					selectObject: label_list_obj
					l_flag = Has word: interval_label$

# report all labeled segments
				elsif (label_flag = label_any)
					l_flag = (interval_label$ <> "")

# impossible
				else
					printline Impossible label_flag: 'label_flag'. Script aborted.
					exit
				endif


### check whether all conditions are met
				if (l_flag = 1)
					nr_measured_segments += 1

# Get intensity mean of segment

					selectObject: intensity_obj
					intensity_mean = Get mean: t_left, t_right, unit$

# go thru measurements in n steps, starting at the left edge (= 'mid') or at the middle (for 1 measurement)
# make sure not to go beyond borders of recording
# (needed only for first and last segments for median/mean methods, but doesn't hurt otherwise)

					for i_step to number_of_measurements
						time = mid
# prepare output line
						out_line$ = ""
						if (path_name)
							out_line$ += "'wav_directory$''tab$'"
						endif
						out_line$ += "'base_name$''tab$''interval_label$''tab$''t_left:04'"
						if (duration_in_ms)
							out_line$ += "'tab$''duration_ms:01'"
						else
							out_line$ += "'tab$''duration:04'"
						endif
						if (intensity_mean <> undefined)
							out_line$ += "'tab$''intensity_mean:01'"
						else
							outline += missing_value$
						endif
						out_line$ += "'tab$''perc:0'"

# report times of measurement
						if (t_request)
							out_line$ += "'tab$''time:04'"
						endif

### now report intensity
						selectObject: intensity_obj
						intensity = Get value at time: time, "Cubic"
						if (intensity <> undefined)
							out_line$ += "'tab$''intensity:01'"
						else
							outline += missing_value$
						endif

# add a newline for this data set
						fileappend 'result_file_name$' 'out_line$''newline$'

# update positions for next chunk
						mid = mid + dur
						perc = perc + perc_step

# stepping thru one interval
					endfor

# label requirement of the interval is not met
# report interval with missing info depending on 'report_skipped_intervals'
# either all or none
				elsif (report_skipped_intervals = 1)
					out_line$ = ""
					if (path_name)
						out_line$ += "'wav_directory$''tab$'"
					endif
					out_line$ += "'base_name$''tab$''interval_label$''tab$''t_left:04'"
					if (duration_in_ms)
						out_line$ += "'tab$''duration_ms:01'"
					else
						out_line$ += "'tab$''duration:06'"
					endif
					out_line$ += "'missing_value$''missing_value$''missing_value$'"
					if (t_request)
						out_line$ += "'missing_value$'"
					endif
					fileappend 'result_file_name$' 'out_line$''newline$'

# label, duration, pitch and intensity test
				endif

# going thru all segments of a TextGrid
			endfor

# entertain user
			tot_segments += nr_measured_segments
			if (user_feedback)
				perc = (i_file/nr_wav_files) * 100
				printline with 'nr_measured_segments' segments finished ('perc:2'%).
			endif
# clean up
			removeObject: grid_obj, wav_obj, intensity_obj

# tier is not an interval tier
		else
			if (!user_feedback)
				printline File 'base_name$' skipped since tier 'tier_to_be_analysed' is not an interval tier.
			else
				printline skipped since tier 'tier_to_be_analysed' is not an interval tier.
			endif
			removeObject: grid_obj
		endif

# requested tier does not exist
	else
		if (!user_feedback)
			print 'base_name$'
		endif
		printline has only 'nr_tiers' tiers. File skipped. ***
		removeObject: wav_obj
		removeObject: grid_obj
	endif

# going thru all sound files
endfor


# clean up (do not use 'remove all' because the user might have some objects hanging around

removeObject: wav_list_obj
if (label_flag = label_list)
	removeObject: label_list_obj
endif

call ReportAnalysisParameter

# inform user that we are done.
if (!user_feedback)
	print Done.
endif
printline 'newline$''nr_wav' files with a total of 'tot_segments' segments processed.
if ((nr_grid <> nr_wav) and (nr_grid <> 0))
	nr_grid = nr_wav - nr_grid
	printline 'nr_grid' TextGrid files not found.
endif
printline Results are written to 'result_file_name$'. 'newline$'Program completed.


##
# check and recode user input
##

procedure CheckParameters

# recode unit selection for computation
	if (unit = 1)
		unit$ = "energy"
	elsif (unit = 2)
		unit$ = "sone"
	elsif (unit = 3)
		unit$ = "dB"
	else
		printline Impossible unit selection: 'unit'. Program aborted.
		exit
	endif

# set unit symbol for output
	un$ = "dB"

### check which segments are to be analyzed; set constants first:
# <nil> => all
	label_none = 0

# . => only labeled segments
	label_any = 1

# label.txt or label(s)
	label_list = 2

### now recode the request
# lower case string is sometimes needed
	lc_label$ = replace_regex$ (label$, ".", "\L&", 0)

# report all intervals
	if (label$ = "")
		label_flag = label_none

# report only labelled intervals
	elsif (label$ = ".")
		label_flag = label_any

# report labels from a label file
	elsif (endsWith(lc_label$,".txt"))
		label$ = support_directory$+label$
		if (not fileReadable (label$))
			printline File 'label$' not found. Script aborted.
			exit
		endif
		help_obj = Read Strings from raw text file: "'label$'"
		nr_labels = Get number of strings
		if (nr_labels < 1)
			printline File 'label$' has no text lines. Script aborted.
			exit
		endif
		printline 'nr_labels' labels found in file 'label$'.
		label_list_obj = To WordList
		removeObject: help_obj
		label_flag = label_list

# treat input as one or more labels, separated by comma and pretend they come from a label file
	else
		label$ = replace_regex$ (label$, " ", ",", 0)
		help_obj = Create Strings as tokens: "'label$'", " ,"
		nr_labels = Get number of strings
		if (nr_labels < 1)
			printline No valid label information found. Script aborted.
			exit
		endif
		label_list_obj = To WordList
		removeObject: help_obj
		label_flag = label_list
	endif

endproc


##
#	Create resultfile
##

procedure CreateResultFile

# create file name with date and time
	call GetDate date_time$
	result_file_name$ = result_directory$+"intensity_contour_results_"+date_time$+".txt"

# intervals as percentage
	if (number_of_measurements = 1)
		perc_step = 50
	else
		perc_step = 100.0 / (number_of_measurements-1)
	endif

# create header, dummy and missing data lines (first part is always there, so no missing data needed)
	out_line$ = ""
	if (path_name)
		out_line$ += "Path'tab$'"
	endif
	out_line$ += "File'tab$'Label'tab$'Start(s)"
	if (duration_in_ms)
		out_line$ += "'tab$'Duration(ms)"
	else
		out_line$ += "'tab$'Duration(s)"
	endif
	out_line$ += "'tab$'Mean('un$')'tab$'%"
	dummy_line$ = ""
	if (path_name)
		dummy_line$ += "'wav_directory$''tab$'"
	endif
	dummy_line$ += "Dummy'tab$'Dummy'tab$'0.0'tab$'0.0'tab$'0.0'tab$'0.0'tab$'0.0"
	remove_from_dummy$ = ""
	if (path_name)
		remove_from_dummy$ += "'wav_directory$''tab$'"
	endif
	remove_from_dummy$ += "Dummy'tab$'Dummy'tab$'0.0'tab$'0.0'tab$'0.0'tab$'0.0"

	if (t_request)
		out_line$ += "'tab$'Timepoint(s)"
		dummy_line$ += "'tab$'0.0"
	endif

	out_line$ += "'tab$'Intensity('un$')"
	dummy_line$ += "'tab$'0.0"

# write header line
	fileappend 'result_file_name$' 'out_line$''newline$'

# add dummy line (if requested)
	if (dummy_data_header)
		fileappend 'result_file_name$' 'dummy_line$''newline$'
	endif

# create missing-data line for skipped segments
# (use dummy line without first elements and convert 0.0 to missing values)
	skip_line$ = replace_regex$(dummy_line$,remove_from_dummy$,"",1)
	skip_line$ = replace_regex$(skip_line$,"0.0",missing_values_symbol$,0)

endproc


## convert Praat's date and time to a date-and-time string

procedure GetDate date_time$

	date_time$ = date$()
	year$ = right$(date_time$,2)
	month$ = mid$(date_time$,5,3)
	day$ = mid$(date_time$,9,2)
	if (left$(day$,1) = " ")
		hday$ = "0"+right$(day$,1)
	else
		hday$ = day$
	endif
	time$ = mid$(date_time$,12,8)

	if (month$ = "Jan")
		hmonth$ = "01"
	elsif (month$ = "Feb")
		hmonth$ = "02"
	elsif (month$ = "Mar")
		hmonth$ = "03"
	elsif (month$ = "Apr")
		hmonth$ = "04"
	elsif (month$ = "May")
		hmonth$ = "05"
	elsif (month$ = "Jun")
		hmonth$ = "06"
	elsif (month$ = "Jul")
		hmonth$ = "07"
	elsif (month$ = "Aug")
		hmonth$ = "08"
	elsif (month$ = "Sep")
		hmonth$ = "09"
	elsif (month$ = "Oct")
		hmonth$ = "10"
	elsif (month$ = "Nov")
		hmonth$ = "11"
	elsif (month$ = "Dec")
		hmonth$ = "12"
	else
		hmonth$ = "xx"
	endif
	htime$ = replace_regex$(time$,":","",0)
	date_time$ = year$+hmonth$+hday$+"_"+htime$

endproc


### Report analysis parameter

procedure ReportAnalysisParameter
	out_line$ = "'newline$'"
	out_line$ += "Script: intensity_contour_'version'_'revision'_'bugfix'.praat'newline$'"
	out_line$ += "Analysis started: 'day$'-'month$'-'year$' 'time$''newline$'"
	if (path_name)
		out_line$ += "Path for sound files: 'wav_directory$''newline$'"
	endif
	if (no_grid)
		out_line$ += "Whole files analysed (no TextGrids used)'newline$'"
	else
		out_line$ += "Tier: 'tier_to_be_analysed''newline$'"
		out_line$ += "Labels: 'label$''newline$'"
	endif
	out_line$ += "Step rate: 'step_rate' s'newline$'"
	out_line$ += "Low F0: 'low_F0' Hz'newline$'"
	out_line$ += "Computation units: 'unit$''newline$'"
	fileappend 'result_file_name$' 'out_line$'
endproc

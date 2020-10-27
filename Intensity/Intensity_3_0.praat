##
#	This script opens all sound files in a directory and associated TextGrids (if they exist),
#	computes the mean intensity of intervalls or at points according to user-defined specifications
#	(or the whole file) that have a name and writes the results together with the durations
#	of these segments/files into a text file.
#
#	Version 1.0, Henning Reetz, 02-jul-2007
#	Version 1.1, Henning Reetz, 18-jun-2009; select tier number
#	Version 2.0, Henning Reetz, 16-dec-2014; new Praat scripting syntax (5.4)
#	Version 3.0, Henning Reetz, 30-sep-2020; general revision; adaptations taken from Formant_contour.praat
#
#	Tested with Praat 6.1.12
#@@ point tier handling not included
##

clearinfo

##
# 1) Inquire some parameters
# ! Note that 'form' may only be used once in a script and should work on a 480 x 640 screen!
##

form Intensity parameters:
	comment Leave the directory path empty if you want to use the current directory.
		text Directory
		integer Tier_to_be_analysed 1
	comment ______________________________________________________________________________________________________________
	comment <label>, <list>.txt, '.' (= only labelled), or empty (= all)
		sentence Label .
	comment ______________________________________________________________________________________________________________
	choice Unit: 3
		button energy
		button sone
		button dB
	comment ______________________________________________________________________________________________________________
		boolean Center_position 0
		boolean Edges 0
		boolean Means 1
		word Quantiles
	comment ______________________________________________________________________________________________________________
	choice Report_skipped_intervals: 2
		button All
		button None
		word Missing_values_symbol .
endform

##
# 2) Change the following settings as you prefer them (and/or add things from the form menu below)
##

# add a slash ("/") to the end of the directory name if necessary
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

# should there be minimal user feedback to speed up processing (= 1) or not (= 0)
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

# @@ report time of measurement (this function is not tested yet) 
t_request = 0

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

# create list of .wav files
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
		print Handling "'base_name$' "
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

##@@ handle this better in case the user wants always whole files analyzed; i.e., it is no error	
#		if (!user_feedback)
#			print File 'base_name$'
#		endif
#		printline has no TextGrid. Whole file anayzed.

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
			selectObject: wav_obj
			intensity_obj = 'np_string$' To Intensity: low_F0, step_rate, "yes"

##
# 6) Go thru all segments of one file
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
				t1 = Get starting point: tier, i_segment
				t3 = Get end point:      tier, i_segment
				t2 = (t1 + t3) / 2
				duration = t3 - t1
				duration_ms = duration * 1000

#
# check whether this data should be reported
# (Bit of an overkill here, but I want to be compatible with my other scripts.)
#

### check label
				l_flag = 0

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

# prepare output line
					if (path_name)
						fileappend 'result_file_name$' 'wav_directory$''tab$'
					endif
					fileappend 'result_file_name$' 'base_name$''tab$''interval_label$''tab$''t1:04'
					if (duration_in_ms)
						fileappend 'result_file_name$' 'tab$''duration_ms:01'
					else
						fileappend 'result_file_name$' 'tab$''duration:04'
					endif

# select intensity object
					selectObject: intensity_obj

# Get the mean intensity value if required
					if (means)
						rms = Get mean: t1, t3, unit$
						stdev = Get standard deviation: t1, t3
						if (rms <> undefined)
							fileappend 'result_file_name$' 'tab$''rms:2'
						else
							fileappend 'result_file_name$' 'missing_value$'
						endif
						if (stdev <> undefined)
							fileappend 'result_file_name$' 'tab$''stdev:2'
						else
							fileappend 'result_file_name$' 'missing_value$'
						endif
					endif

# Get quantiles if required (if not, nr_quantils is zero and the next loop will be skipped)
					for i_quantile to nr_quantiles
						selectObject: quantile_obj
						quantile_value$ = Get string: i_quantile
						quantile_value = number(quantile_value$) / 100
						selectObject: intensity_obj
						quantile  = Get quantile: t1, t3, quantile_value
						if (quantile <> undefined)
							fileappend 'result_file_name$' 'tab$''quantile:2'
						else
							fileappend 'result_file_name$' 'missing_value$'
						endif
					endfor


# report edges and center if required
					if (edges)
						intensity = Get value at time: t1, "Cubic"
						fileappend 'result_file_name$' 'tab$''intensity:2'
					endif
					if (center_position)
						intensity = Get value at time: t2, "Cubic"
						fileappend 'result_file_name$' 'tab$''intensity:2'
					endif
					if (edges)
						intensity = Get value at time: t3, "Cubic"
						fileappend 'result_file_name$' 'tab$''intensity:2'
					endif

					fileappend 'result_file_name$' 'newline$'
#
# interval should not be reported (l_flag = 0), but the user might want to report skipped intyervals
#
				elsif (report_skipped_intervals = 1)
# prepare output line
					if (path_name)
						fileappend 'result_file_name$' 'wav_directory$''tab$'
					endif
					fileappend 'result_file_name$' 'base_name$''tab$''interval_label$''tab$''t1:04'
					if (duration_in_ms)
						fileappend 'result_file_name$' 'tab$''duration_ms:01'
					else
						fileappend 'result_file_name$' 'tab$''duration:04'
					endif

# Get the mean intensity value if required
					if (means)
						fileappend 'result_file_name$' 'missing_value$''missing_value$'
					endif

# Get quantiles if required (if not, nr_quantils is zero and the next loop will be skipped)
					for i_quantile to nr_quantiles
						fileappend 'result_file_name$' 'missing_value$'
					endfor


# report edges and center if required
					if (edges)
						fileappend 'result_file_name$' 'missing_value$'
					endif
					if (center_position)
						fileappend 'result_file_name$' 'missing_value$'
					endif
					if (edges)
						fileappend 'result_file_name$' 'missing_value$'
					endif
					fileappend 'result_file_name$' 'newline$'

				endif
			endfor

# clean up
			removeObject: intensity_obj
			tot_segments += nr_measured_segments
			if (user_feedback)
				perc = (i_file/nr_wav_files) * 100
				printline with 'nr_measured_segments' segments finished ('perc:2'%).
			endif

# tier is not an interval tier
		else
			if (!user_feedback)
				print File 'base_name$'
			endif
			printline skipped since tier 'tier_to_be_analysed' is not an interval tier.
		endif

# requested tier number if higher than number of tiers
	else
		if (!user_feedback)
			print File 'base_name$'
		endif
		printline has only 'nr_tiers' tiers. File skipped. <***
	endif
# one file processed

	removeObject: wav_obj, grid_obj
endfor

# all files processed now
# clean up

removeObject: wav_list_obj
if (label_flag = label_list)
	removeObject: label_list_obj
endif
if (means)
	removeObject: quantile_obj
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

# check whether anything is selected at all
	if (center_position+edges+means = 0)
		printline Neither Center position, Edges nor Mean are selected: no data computed.
		exit
	endif

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

# quantile information required?
	if (quantiles$ <> "")
		if (!means)
			means = 1
			printline Means processing switched on to get quantile information.
		endif
		quantile_obj = Create Strings as tokens: "'quantiles$'", " ,"
		nr_quantiles = Get number of strings

# convert values into percentage (to reduce rounding errors), add 'symmetrical' quantile and sort them (and remove doublets)
		for i_quantile to nr_quantiles
			quantile_value$ = Get string: i_quantile
			quantile_value = number(quantile_value$)
			if ((quantile_value < 0) or (quantile_value>100))
				printline The quantile value 'quantile_value' is out of range; only numbers between 0 and 100 are allowed.'newline$'Script aborted.
				exit
# convert 0…1 into percentage (and replace string)
			elsif (quantile_value <= 1)
				quantile_value *= 100
				quantile_value = round(quantile_value)
				quantile_value$ = string$(quantile_value)
				Set string: i_quantile, "'quantile_value$'"
			endif

# create symmetrical value (add them at the end of the string); even for median
			new_value = 100 - quantile_value
			new_value = round(new_value)
			new_value$ = string$(new_value)
			Insert string: 0, "'new_value$'"
		endfor
# add median at the end of the string, even if it is already there
		Insert string: 0, "50"
# sort and remove doublets (e.g. in case user gave already symmetrical values)
		Sort
		nr_quantiles = Get number of strings
		last$ = ""
		for i_quantile to nr_quantiles
			quantile_value$ = Get string: i_quantile
			if (quantile_value$ = last$)
				Remove string: i_quantile
				i_quantile -= 1
				nr_quantiles -= 1
			else
				last$ = quantile_value$
			endif
		endfor
		nr_quantiles = Get number of strings

# no quantils required, but if means are required, add median, using the same mechanism as quantiles
	elsif (means)
		quantile_obj = Create Strings as tokens: "50", " ,"
		nr_quantiles = 1
	else
		nr_quantiles = 0
	endif
endproc


##
#	Create resultfile
##

procedure CreateResultFile

# create file name with date and time
	call GetDate date_time$
	result_file_name$ = result_directory$+"intensity_results_"+date_time$+".txt"

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

# create dummy line
	dummy_line$ = ""
	if (path_name)
		dummy_line$ += "'wav_directory$''tab$'"
	endif
	dummy_line$ += "Dummy'tab$'Dummy'tab$'0.0'tab$'0.0'tab$'0.0'tab$'0.0"
	remove_from_dummy$ = dummy_line$

	if (means)
		out_line$ += "'tab$'Mean('un$')'tab$'StDev('un$')"
		dummy_line$ += "'tab$'0.0'tab$'0.0"
	endif

	for i_quantile to nr_quantiles
		quantile_value$ = Get string: i_quantile
		quantile_value = number(quantile_value$)
		if (quantile_value = 50)
			out_line$ += "'tab$'Median('un$')"
		else
			out_line$ += "'tab$''quantile_value:0'%('un$')"
		endif
		dummy_line$ += "'tab$'0.0'"
	endfor

	p1$ = "Left"
	p2$ = "Center"
	p3$ = "Right"
	if (t_request)
		for i_pos to 3
			if (((i_pos<>2) and edges) or ((i_pos=2) and center_position))
				position$ = p'i_pos'$
				out_line$ += "'tab$'t_'position$'(s)"
				dummy_line$ += "'tab$'0.0"
			endif
		endfor
	endif

	for i_pos to 3
		if (((i_pos<>2) and edges) or ((i_pos=2) and center_position))
			position$ = p'i_pos'$
			out_line$ += "'tab$''position$'('un$')"
			dummy_line$ += "'tab$'0.0"
		endif
	endfor

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


##
# convert Praat's date and time to a date-and-time string
##

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


procedure ReportAnalysisParameter
	out_line$ = "'newline$'"
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



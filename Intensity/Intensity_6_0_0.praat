##
#	This script opens all sound files in a directory and associated TextGrids (if they exist),
#	computes the mean intensity of intervalls or at several points (to create 'contours') 
#	according to user-defined specifications (or for the whole files) 
#	and writes the results together with the durations of these intervals/files into a text file.
#
# **> Please read 'intensity_manual.pdf' for a full description of this rather complex script.
# **> Please feel free to use and modify this script to your needs.
# **> But please report errors or give suggestions for improvements to <reetz.phonetics@gmail.com>
#
#	Vers. 1.0, Henning Reetz, 02-jul-2007
#	Vers. 1.1, Henning Reetz, 18-jun-2009; select tier number
#	Vers. 2.0, Henning Reetz, 16-dec-2014; new Praat scripting syntax (5.4)
#	Vers. 3.0, Henning Reetz, 30-sep-2020; general revision; adaptations taken from Formant_contour.praat
#	There is no versions 4. I jump to 5 to synchronise the style with the other scripts
#	Vers. 5.0.0, Henning Reetz, 05-nov-2020; synchronizing with other scripts; correct quantiles sorting
#	Vers. 6.0.0, Henning Reetz, 12-nov-2020; merged with Intensity_contour, subtract mean and z-scores options added
#
#	Tested with Praat 6.1.27
#
#@@ point tier handling not included
#@@ allow spaces in interval labels
##

version = 6
revision = 0
bugfix = 0

clearinfo
nil$ = ""
space$ = " "


##
# 1) Inquire some parameters
# ! Note that 'form' may only be used once in a script and should work on a 480 x 640 screen!
##

form Intensity parameters (Vers. 6.0):
	comment Leave the directory path empty if you want to use the current directory.
		text Directory
		integer Tier 1
	comment ______________________________________________________________________________________________________________
	comment <label>, <list>.txt, '.' (= only labelled), or empty (= all)
		sentence Label .
	comment (m)ean, <list of quantiles in %>
		sentence Measurements m,0,50
	comment Nr. of measurements per interval (for a contour) 1: only center, 2: only edges
		integer Number_of_measurements 3
	comment (t)ime of measurement, mean (s)ubtraction or (z)-scores?
		sentence Contour_parameters t
	comment ______________________________________________________________________________________________________________
	choice Report_skipped_intervals: 2
		button All
		button None
		word Missing_values_symbol .
endform

##
# 2) Change the following settings as you prefer them (and/or add things from the form menu below)
##

## use this in the form window, in case you want to have it there
#	comment ______________________________________________________________________________________________________________
#	choice Unit: 3
#		button energy
#		button sones
#		button dB

# set default unit to 'dB' (i.e. unit = 3 in the choice syntax or the form window)
unit = 3

# position reporting in steps (1, 2, 3,…) or percentage (0%, 25%…) of interval
position_in_percentage = 1

# intensity computation parameters
step_rate = 0.005
low_F0 = 50

# minimal length in ms
minimal_length_ms = 0

# maximal number of intervals for reporting the contour
max_number_of_measurements = 50

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

# should the name of the diectory path be reported (path_name = 1) or not (path_name = 0)
path_name = 0

# extension of the audio files
ext$ = ".wav"

# separator for output list (e.g. = "," for csv files)
sep$ = tab$

# should there be minimal user feedback to speed up processing (= 1) or not (= 0)
user_feedback = 1

# should there be no processing information from Praat (= "noprogress") or not (= ""  ; i.e. empty string)
np_string$ = "noprogress"

# should there be a dummy data header to force correct data type in JMP or other tables (= 1) or not (= 0)
dummy_data_header = 0

# report duration in ms (duration_in_ms = 1) or seconds (duration_in_ms = 0)
duration_in_ms = 1

##
# 3) Check input and create result file
##

# check and recode user input
missing_value$ = "'sep$''missing_values_symbol$'"
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

# total nr. of intervals of all files
tot_intervals = 0

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
		print Handling 'base_name$''space$'
	endif

# create fake grid if whole file should be analyzed (no special handling for whole file needed)
	if (whole_file)
		grid_obj = To TextGrid: "dummy", ""
	else

# check whether TextGrid exists; if not: perhaps the user wnats to analyse whole files
		grid_name$ = grid_directory$+base_name$+".TextGrid"
		no_grid = 0
		if (fileReadable(grid_name$))

# TextGrid file exists?
			grid_obj = Read from file: grid_name$
			nr_grid += 1
		endif
	endif

# perform next steps only if there is a grid object (it is selected at this point)
	if (grid_obj)
		nr_tiers = Get number of tiers
		if (tier <= nr_tiers)

# check whether tier is an interval tier.
			tier_is_interval = Is interval tier: tier
			if  (tier_is_interval)

# if any of the above attempts to open a file worked, we should be save now
# compute pitch and intensity (needed for report and test)
				selectObject: wav_obj
				intensity_obj = 'np_string$' To Intensity: low_F0, step_rate, "yes"

##
# 6) Go thru all intervals of one file
##

# Use the TextGrid to find all intervals.
				selectObject: grid_obj
				nr_intervals = Get number of intervals: tier
				nr_measured_intervals = 0

# go thru all intervals
				for i_interval to nr_intervals
					selectObject: grid_obj
					interval_label$ = Get label of interval: tier, i_interval

# find center and measure length
					t_left = Get starting point: tier, i_interval
					t_right = Get end point:      tier, i_interval
					duration = t_right - t_left
					duration_ms = duration * 1000

#
# check whether this data should be reported
# (Bit of an overkill here, but I want to be compatible with my other scripts.)
#

### check label
					l_flag = 0

# report all intervals
					if ((label_flag = label_none) or whole_file)
						l_flag = 1

# report list of labels
					elsif (label_flag = label_list)
						selectObject: label_list_obj
						l_flag = Has word: interval_label$

# report all labeled intervals
					elsif (label_flag = label_any)
						l_flag = (interval_label$ <> "")

# impossible
					else
						printline Impossible label_flag: 'label_flag'. Script aborted.
						exit
					endif

### check for minimal duration
					d_flag = (duration_ms > minimal_length_ms)

### check whether all conditions are met
					if (l_flag and d_flag)
						nr_measured_intervals += 1

# prepare output line
						if (path_name)
							fileappend 'result_file_name$' 'wav_directory$''sep$'
						endif
						fileappend 'result_file_name$' 'base_name$''sep$''interval_label$''sep$''t_left:04'
						if (duration_in_ms)
							fileappend 'result_file_name$' 'sep$''duration_ms:01'
						else
							fileappend 'result_file_name$' 'sep$''duration:04'
						endif

# select intensity object
						selectObject: intensity_obj

# Get the mean intensity value if required
						if (m_request)
							mean_intensity = Get mean: t_left, t_right, unit$
							stdev_intensity = Get standard deviation: t_left, t_right
							call ReportValue mean_intensity 2
							call ReportValue stdev_intensity 2
						endif

# Get quantiles if required (if not, nr_quantils is zero and the next loop will be skipped)
						for i_quantile to nr_quantiles
							selectObject: quantile_obj
							quantile_value$ = Get string: i_quantile
							quantile_value = number(quantile_value$) / 100
							selectObject: intensity_obj
							quantile  = Get quantile: t_left, t_right, quantile_value
							call ReportValue quantile 2
						endfor

# Use the same mechanisme for contours of times, values, means subtraction, and z-score
						if (number_of_measurements)
							if (t_request)
								call ReportContour t
							endif
							call ReportContour 'nil$'
							if (s_request)
								call ReportContour s
							endif
							if (z_request)
								call ReportContour z
							endif
	 					endif
# line finished
						fileappend 'result_file_name$' 'newline$'

#
# interval should not be reported (l_flag = 0), but the user might want to report skipped intyervals
#
					elsif (report_skipped_intervals = 1)
# prepare output line
						if (path_name)
							fileappend 'result_file_name$' 'wav_directory$''sep$'
						endif
						fileappend 'result_file_name$' 'base_name$''sep$''interval_label$''sep$''t_left:04'
						if (duration_in_ms)
							fileappend 'result_file_name$' 'sep$''duration_ms:01'
						else
							fileappend 'result_file_name$' 'sep$''duration:04'
						endif

# fill columns with missing values
						fileappend 'result_file_name$' 'skip_line$''newline$'

# interval to be reported?
					endif

# going thru intervals
				endfor

# clean up
				removeObject: intensity_obj
				tot_intervals += nr_measured_intervals
				if (user_feedback)
					perc = (i_file/nr_wav_files) * 100
					printline with 'nr_measured_intervals' intervals finished ('perc:2'%).
				endif

# tier is not an interval tier
			else
				if (!user_feedback)
					print File 'base_name$''space$'
				endif
				printline **> skipped since tier 'tier' is not an interval tier. <**
			endif

# requested tier number is higher than number of tiers
		else
			if (!user_feedback)
				print File 'base_name$''space$'
			endif
			printline **> has only 'nr_tiers' tiers. File skipped. <**
		endif

# one file processed (even a tier = 0 or no TextGrid in directory have a dummy TextGrid in the memory)
	removeObject: wav_obj, grid_obj
endfor

# all files processed now
# clean up

removeObject: wav_list_obj
if (label_flag = label_list)
	removeObject: label_list_obj
endif
if (nr_quantiles)
	removeObject: quantile_obj
endif

call ReportAnalysisParameter

# inform user that we are done.
if (!user_feedback)
	print Done.
endif
printline 'newline$''nr_wav' files with a total of 'tot_intervals' intervals processed.
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
		unit$ = "sones"
	elsif (unit = 3)
		unit$ = "dB"
	else
		printline Impossible unit selection: 'unit'. Program aborted.
		exit
	endif

# set unit symbol for output
	un$ = "dB"

# check whether whole file should be analyzed (i.e. whole_file)
	if (tier = 0)
		whole_file = 1
		tier = 1

# check whether there are TextGrid files; if the grid_list is empty, assume whole file treatment
	else
		grid_list_obj = Create Strings as file list:  "grid_list", "'grid_directory$'*.TextGrid"
		nr_grid_files = Get number of strings
		whole_file = (nr_grid_files = 0)
		if (whole_file)
			printline No TextGrids found. Only whole file lengths will be reported.
		endif
		removeObject: grid_list_obj
	endif

# check whether anything is selected at all
	if ((measurements$ = "") and (number_of_measurements = 0))
		printline Neither Mean, Quantiles, or measurement points are selected: no data computed.
		exit

###
# which measurements are required?
###
	else

# preset mean (s)ubtraction, (z)-scores, (t)ime point reporting, (m)eans and quantiles to 'not requested' (= 0)
		m_request = 0
		s_request = 0
		t_request = 0
		z_request = 0
		nr_quantiles = 0

### Check type of measurement field
		measurements$ = replace_regex$ (measurements$, ".", "\L&", 0)
##@@??		measurements$ = replace_regex$ (measurements$, " ", ",", 0)
		item_obj = Create Strings as tokens: measurements$, " ,"
		nr_items = Get number of strings

#  add 'symmetrical' quantile and sort them (and remove doublets)@@ this has changed!!
		for i_item to nr_items
			selectObject: item_obj
			item$ = Get string: i_item
# means requested?
			if (item$ = "m")
				m_request = 1
# time position requested?
			elsif (item$ = "t")
				t_request = 1
# if none of the above, assume numbers, i.e. quantils (in percentages)
# (Illegal measurements$ input captured by generating an 'undefined' numerical value from a string below!)
			else
				quantile_value = number(item$)
				if (quantile_value <> undefined)
					if ((quantile_value < 0) or (quantile_value>100))
						printline The quantile value 'quantile_value' is out of range; only numbers between 0 and 100 are allowed.'newline$'Script aborted.
						exit
					endif
					if (nr_quantiles = 0)
						quantile_obj = Create Strings as tokens: item$, " ,"
						nr_quantiles = 1
					else
						selectObject: quantile_obj
						nr_quantiles += 1
						Insert string: nr_quantiles, item$
					endif

# create symmetrical value (add them at the end of the string); even for median
					new_value = 100 - quantile_value
					new_value$ = string$(new_value)
					nr_quantiles += 1
					Insert string: nr_quantiles, new_value$
				else
					printline Illegal parameter in Measurement definition: "'item$'". Computation aborted."
					exit
				endif
			endif
		endfor
		removeObject: item_obj

# sort quantiles (if required)
		if (nr_quantiles)
			call SortQuantiles
		endif


### Check contour parameters
		contour_parameters$ = replace_regex$ (contour_parameters$,".","\L&",0)
#		contour_parameters$ = replace_regex$ (contour_parameters$, " ", ",", 0)
		item_obj = Create Strings as tokens: contour_parameters$, " ,"
		nr_items = Get number of strings

# check item list
		for i_item to nr_items
			selectObject: item_obj
			item$ = Get string: i_item
# time position requested?
			if (item$ = "t")
				t_request = 1
# mean subtraction requested?
			elsif (item$ = "s")
				if (unit <> 3)
					printline Subtraction of means is only possible with "dB" units for means computation.
					printline Please change setting in the script to    unit = 3
					exit
				endif
				m_request = 1
				s_request = 1
# z-scores requested?
			elsif (item$ = "z")
				if (unit <> 3)
					printline Subtraction of means is only possible with "dB" units for means computation.
					printline Please change setting in the script to    unit = 3
					exit
				endif
				m_request = 1
				z_request = 1

# if none of the above issue error message
			else
				printline Illegal parameter in Contour parameters definition: "'item$'". Computation aborted."
				exit
			endif
		endfor
		removeObject: item_obj

# check for measurement and contour parameters
	endif

###
# check which intervals are to be analyzed; set constants first:
###
# <nil> => all
	label_none = 0

# . => only labeled intervals
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

### warn about too many measurements
	if (number_of_measurements > max_number_of_measurements)
		pause Do you really want 'number_of_measurements' measurements per interval?
	endif

# warn user that unit$ type is only used for means and nowhere else
	if ((unit$ <> "dB") and !m_request)
		pause Be aware that unit "'unit$'" is only used for means computation, which is not requested!
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
		out_line$ += "Path'sep$'"
	endif
	out_line$ += "File'sep$'Label'sep$'Start(s)"
	if (duration_in_ms)
		out_line$ += "'sep$'Duration(ms)"
	else
		out_line$ += "'sep$'Duration(s)"
	endif

# create dummy line
	dummy_line$ = ""
	if (path_name)
		dummy_line$ += "'wav_directory$''sep$'"
	endif
	dummy_line$ += "Dummy'sep$'Dummy'sep$'0.0'sep$'0.0'sep$'0.0'sep$'0.0"
	remove_from_dummy$ = dummy_line$

# add header for mean and st.dev.
	if (m_request)
		out_line$ += "'sep$'Mean('un$')'sep$'StDev(dB)"
		dummy_line$ += "'sep$'0.0'sep$'0.0"
	endif

# add header for quantiles (automatically skipped if nr_quantiles = 0)
	for i_quantile to nr_quantiles
		selectObject: quantile_obj
		quantile_value$ = Get string: i_quantile
		quantile_value = number(quantile_value$)
		if (quantile_value = 0)
			out_line$ += "'sep$'Min('un$')"
		elsif (quantile_value = 50)
			out_line$ += "'sep$'Median('un$')"
		elsif (quantile_value = 100)
			out_line$ += "'sep$'Max('un$')"
		else
			out_line$ += "'sep$''quantile_value:1'%('un$')"
		endif
		dummy_line$ += "'sep$'0.0"
	endfor

# Use the same mechanisme for contours of times, values, means subtraction, and z-score
	if (number_of_measurements)
		if (t_request)
			call ContourHeader t
		endif
		call ContourHeader 'nil$'
		if (s_request)
			call ContourHeader s
		endif
		if (z_request)
			call ContourHeader z
		endif
	endif

# write header line
	fileappend 'result_file_name$' 'out_line$''newline$'

# add dummy line (if requested)
	if (dummy_data_header)
		fileappend 'result_file_name$' 'dummy_line$''newline$'
	endif

# create missing-data line for skipped intervals
# (use dummy line without first elements and convert 0.0 to missing values)
	skip_line$ = replace_regex$(dummy_line$,remove_from_dummy$,"",1)
	skip_line$ = replace_regex$(skip_line$,"0.0",missing_values_symbol$,0)

endproc

###
# add header for contour measurements
###
procedure ContourHeader x$

	p1$ = "left"
	p2$ = "center"
	p3$ = "right"

	perc = 0
# any time point measurement other than center (= 1)?
	if (number_of_measurements <> 1)
		perc_step = 100.0 / (number_of_measurements-1)
	endif

# adjust unit for report
	if (x$ = "")
		prefix$ = "i_"
		pos_unit$ = "dB"
	elsif (x$ = "s")
		prefix$ = "s_"
		pos_unit$ = "dB"
	elsif (x$ = "t")
		prefix$ = "t_"
		pos_unit$ = "s"
	elsif (x$ = "z")
		prefix$ = "z_"
		pos_unit$ = "z"
	else
		printline Illegal parameter for procedure ContourHeader: "'x$'". Computation aborted."
		exit
	endif

# next loop is only enterd if any time point measurements (incl. center and edges ) are requested
	for i_pos to number_of_measurements

# special handling if only 3 or less required
		if (number_of_measurements = 1)
			p$ = p2$
			position$ = "'prefix$''p$'"
		elsif (number_of_measurements <= 3)
			p$ = p'i_pos'$
			position$ = "'prefix$''p$'"
		elsif (position_in_percentage)
			position$ = "'prefix$''perc:2'%"
			perc = i_pos * perc_step
		else
			position$ = "'prefix$''i_pos'"
		endif

		out_line$ += "'sep$''position$'('pos_unit$')"
		dummy_line$ += "'sep$'0.0"
	endfor
endproc

###
# Procedure to report contour values
###

procedure ReportContour x$

### Go thru measurements for a contour (special handling for '1' (center), '2' (edges', '3' (edges and center)
	if (number_of_measurements)

# go thru measurements in n steps, starting at the left edge (= 'mid') or at the middle (for 1 measurement)
#@@@ make sure not to go beyond borders of recording (for 2, 3???

# Get intensity chunks of segment; use 'mid' as guiding time
		if (number_of_measurements = 1)
			dur = (t_right - t_left)
			mid = (t_right + t_left) / 2
			perc = 50

# compute positions for analysis windows at segment boundaries
		else
			dur = (t_right - t_left) / (number_of_measurements-1)
			mid = t_left
			perc = 0
		endif

# report times of measurement
		if (x$ = "t")
			for i_pos to number_of_measurements
				fileappend 'result_file_name$' 'sep$''mid:04'
				mid += dur
			endfor
		endif
		
# report intensity at this point
# (store intensities in variables like intensity1, intensity2…) for subtract mean or z-scores
		if (x$ = "")
			for i_pos to number_of_measurements
				selectObject: intensity_obj
				intensity'i_pos' = Get value at time: mid, "Cubic"
				call ReportValue intensity'i_pos' 2
				mid += dur
			endfor
		endif

# report subtracted mean 
# (intensities are already computed at this time and stored in variables like intensity1, intensity2…)
		if (x$ = "s")
			for i_pos to number_of_measurements
#				selectObject: intensity_obj
#				intensity'i_pos' = Get value at time: mid, "Cubic"
				intensity_s = intensity'i_pos' - mean_intensity
				call ReportValue intensity_s 2
#				mid += dur
			endfor
		endif
		
# report z-scores
# (intensities are already computed at this time and stored in variables like intensity1, intensity2…)
		if (x$ = "z")
			for i_pos to number_of_measurements
#				selectObject: intensity_obj
#				intensity'i_pos' = Get value at time: mid, "Cubic"
				intensity_z = (intensity'i_pos' - mean_intensity) / stdev_intensity
				call ReportValue intensity_z 2
#				mid += dur
			endfor
		endif

# contour measurement required?
	endif
endproc


##
#  Procedure to report one value
##

procedure ReportValue v l
	if (v <> undefined)
		if (l = 0)
			fileappend 'result_file_name$' 'sep$''v:0'
		elsif (l = 1)
			fileappend 'result_file_name$' 'sep$''v:01'
		elsif (l = 2)
			fileappend 'result_file_name$' 'sep$''v:02'
		elsif (l = 3)
			fileappend 'result_file_name$' 'sep$''v:03'
		elsif (l = 4)
			fileappend 'result_file_name$' 'sep$''v:04'
		elsif (l = 5)
			fileappend 'result_file_name$' 'sep$''v:05'
		elsif (l = 6)
			fileappend 'result_file_name$' 'sep$''v:06'
		else
			fileappend 'result_file_name$' 'sep$''v'
		endif
	else
		fileappend 'result_file_name$' 'missing_value$'
	endif
endproc

###
# Procedure to sort quantiles and remove doublets
###

procedure SortQuantiles

# add leading zeros to allow alphabetical sorting (and as preparation for removing doublets)
	selectObject: quantile_obj
	for i_quantile to nr_quantiles
		quantile_value$ = Get string: i_quantile
		quantile_value = number(quantile_value$)
		if (quantile_value < 10)
			quantile_value$ = "00" + quantile_value$
			Set string: i_quantile, quantile_value$
		elsif (quantile_value < 100)
			quantile_value$ = "0" + quantile_value$
			Set string: i_quantile, quantile_value$
		endif
	endfor
	Sort

# sort and remove doublets (e.g. in case user gave already symmetrical values)
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
	out_line$ += "Script: Intensity_'version'_'revision'_'bugfix'.praat'newline$'"
	out_line$ += "Analysis started: 'day$'-'month$'-'year$' 'time$''newline$'"
	if (path_name)
		out_line$ += "Path for sound files: 'wav_directory$''newline$'"
	endif
	if (whole_file)
		out_line$ += "Whole files analysed (no TextGrids used)'newline$'"
	else
		out_line$ += "Tier: 'tier''newline$'"
		out_line$ += "Labels: 'label$''newline$'"
	endif
	out_line$ += "Step rate: 'step_rate' s'newline$'"
	out_line$ += "Low F0: 'low_F0' Hz'newline$'"
	out_line$ += "Computation units: 'unit$''newline$'"
	out_line$ += "Minimal length: 'minimal_length_ms' ms'newline$'"
	fileappend 'result_file_name$' 'out_line$'
endproc



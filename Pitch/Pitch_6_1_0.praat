##
#	This script opens all sound files in a directory and associated TextGrids (if they exist),
#	computes the mean pitch of intervalls (or whole files) 
#	and can provide 'contour' data along time points of an interval.
#	Intervals can be selected in different ways and the results are written into a text file.
#
# **> Please read 'pitch_manual.pdf' for a full description of this rather complex script.
# **> Please feel free to use and modify this script to your needs.
# **> But please report errors or give suggestions for improvements to <reetz.phonetics@gmail.com>
#
#	Vers. 1.0, Henning Reetz, 02-jul-2007
# 	Vers. 1.1, Henning Reetz, 22-jun-2009	'tier' added in form
#	There are no versions 2 or 3. I jump to 4 to synchronise the style with the other scripts
#	Vers. 4.0, Henning Reetz, 09-oct-2020	mayor revsision; adapted from intensity_mean_3_0.praat
#	Vers. 5.0.0, Henning Reetz, 26-oct-2020	new list syntax, tier=0 => whole file, correct quantile sorting
#	Vers. 5.0.1, Henning Reetz, 05-oct-2020	no bugfix, but reporting values generalized
#	Vers. 6.0.0, Henning Reetz, 23-oct-2020	contour included; removed mean/median around position for contour
#	Vers. 6.1.0, Henning Reetz, 15-jan-2021	opening/computinmg files only when needed
#
# Tested with Praat 6.1.33
#
##@@ add cross_interval_boundary handling
##@@ allow points
##@@ allow spaces in interval labels
##@@ add more than 1 tier in selecting and sorting
##

version = 6
revision = 1
bugfix = 0

# clear feedback window
clearinfo
# variable space$ in case we really need a space at the end of a line
space$ = " "

## 1) Inquire some parameters
# (This form fits into screen with 640 pixel vertical resolution)
# ! Note that 'form' may only be used once in a script!

form Pitch parameters (Vers. 6.1):
		word Tier 1
	comment <label>, <list>.txt, '.' (= only labelled), or empty (= all)
		sentence Label .
		real low_F0 75.0
		real high_F0 500.0
	comment Units: either (H)ertz, (s)emitones, (m)el, (E)RB or (l)ogHertz
		sentence Units H
	comment (i)ntensity, (m)ean, <list of quantiles in %> of intervals
		sentence Interval_parameters i,0,50
	comment Nr. of measurements per interval (for a contour) 1: only center, 2: only edges
		word Number_of_measurements 3
	comment (t)ime of measurement, additionally mean (s)ubtraction, (z)-scores?
		sentence Contour_parameters t
	comment ______________________________________________________________________________________________________________
	choice Report_skipped_intervals: 2
		button All
		button Length or Intensity exclusion
		button None
endform

###
# 	2) Adjust the following settings as you prefer them (and/or add things from the form menu below)
###

# units of measurement (in the form above as a string input, because it takes too much space)
# copy the 6 lines below into the form window if you want it there and adjust recoding in
# CheckParamaters!
#	comment ______________________________________________________________________________________________________________
#	choice Unit: 1
#		button Hertz
#		button logHertz
#		button semitones (re 1 Hz)
#		button mel
#		button ERB
#	unit = 1
#

# pitch computation parameters
# real Step_rate 0.005
step_rate = 0.005

# minimal length for an interval to be reported (0 = no restriction)
# real minimal_length_ms 20
minimal_length_ms = 20

# minimal intensity for an interval to be reported (0 = no restriction)
#**> note that this parameter becomes only relevant if ii_request is set!
# real minimal_intensity 40
minimal_intensity = 40

# can the analysis window at the edges of a interval cross the interval boundary (=1) or not (=0)
cross_interval_boundary = 1

# position reporting in steps (1, 2, 3,…) or percentage (0%, 25%…) of interval
position_in_percentage = 1

# maximal number of intervals for reporting the contour
max_number_of_measurements = 50

# type of interpolation (nearest, linear)
interpolation$ = "linear"

# source of data (empty string = directory where the script was called from)
# comment Leave the directory path empty if you want to use the current directory.
#	text Directory
directory$ = ""

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

# Examples (for being one directory above 4 sub-directories ("./" for curent directory):
# In case you want the path for the .wav file in the output, set 'path_name' to 1
#	directroy$ = "./"
#	wav_directory$ = "./Sound/"
#	grid_directory$ = "./Grid/"
#	result_directory$ = "./Result/"
#	support_directory$ = "./Support/"

# should the name of the diectory path be reported (path_name = 1) or not (path_name = 0)
path_name = 0

# extension of the audio files
# word sound_ext .wav
sound_ext$ = ".wav"

# separator for output list (e.g. = "," for csv files)
sep$ = tab$

# should there be user feedback (= 1) or none to speed up processing  (= 0)
# boolean User_feedback 1
user_feedback = 1

# should there be no processing information from Praat (= "noprogress") or not (= ""  ; i.e. empty string)
np_string$ = "noprogress"

# should there be a dummy data header to force correct data type in JMP or other tables (= 1) or not (= 0)
# boolean Dummy_data_header 0
dummy_data_header = 0

# report duration in ms (duration_in_ms = 1) or seconds (duration_in_ms = 0)
duration_in_ms = 1

# missing values symbole (e.g. "NA" for R or "." for JMP)
# word Missing_value_symbol .
missing_value_symbol$ = "NA"


###
#	3) Check input and create result file
###

# check and recode user input
missing_value$ = "'sep$''missing_value_symbol$'"
call CheckParameters

# create result file
call CreateResultFile

###
#	4) Get file names from a directory
#	In case the whole file should be measured, look for all wav files.
###

# nr. of files that have been processed
no_grid = 0
nr_wav = 0

# total nr. of intervals of all files
tot_intervals = 0

# create list of .wav files
wav_list_obj = Create Strings as file list:  "file_list", "'wav_directory$'*'sound_ext$'"
nr_wav_files = Get number of strings

# Give minimal user feedback
if (!user_feedback)
	print Computing...'space$'
endif

###
#	5) go thru all files and compute requested data
#	Compute data for whole file only if at least one interval has been found, i.e.
#	the computations for the whole file are only done once, but they are delayed
#	until it is really needed. This is done in case somebody uses the script to look
#	for a specific label in many files but only few have them actually. The indiacation
#	that a specific data set (e.g. pitch) has not been computed is done by setting the
#	object idebtifier (e.g. pitch_obj) to 0.
###

for i_file to nr_wav_files

# load wav file only if it really needed
# and indicate that no data is computed yet
	wav_obj = 0
	intensity_obj = 0
	pitch_obj = 0
	call OpenFiles

# perform next steps only if there is a grid object (it is selected at this point)
	if (grid_obj)
		nr_tiers = Get number of tiers
		if (tier <= nr_tiers)

# check whether tier is an interval tier.
			tier_is_interval = Is interval tier: tier
			if  (tier_is_interval)

###
#	6) Go thru all intervals and find out whether the interval should be reported
###

# Use the TextGrid to find all intervals.
				selectObject: grid_obj
				nr_intervals = Get number of intervals: tier
				nr_measured_intervals = 0

# go thru all intervals
				for i_interval to nr_intervals

### get interval label, its duration and check whether interval is requested
# This procedure defines and sets the variable l_flag, t_left, t_right
					call CheckLabel

### check for minimal duration
					d_flag = (duration_ms > minimal_length_ms)

### check for intensity if label is okay and minimal intensity is requested
					if (l_flag and minimal_intensity)
						call SelectObject intensity_obj
						intensity_mean = Get mean: t_left, t_right, "energy"
						i_flag = (intensity_mean > minimal_intensity)
# essentially ignore intensity
					else
						intensity_mean = 0
						i_flag = 1
					endif

###
#	7) check whether all conditions are met; if so, start reporting data
#
#	Report in the sequence:
#	Location:
#		(path) file label start duration
#	Interval information:
#		(mean intensity) 
#		for pitch units
#			(mean pitch) (stdev pitch) (quantiles)
#		endfor
#	Contour information (loop thru time points on lower level inside 'ReportContour'):
#		(time) (intensity) 
#		for pitch units
#			pitch (mean subtraction) (z-score)
#		endfor
###
					if (l_flag and d_flag and i_flag)
						nr_measured_intervals += 1
						call PrepareOutputLine
						call SelectObject pitch_obj

# determine always percentange of voiced frames (even if only center is requested)
# (for voicing computation, any unit can be used)
						unit$ = "Hertz"
						call ReportVoicing

# report intensity is requested or needed
						if (ii_request)
							if (!intensity_mean)
								call SelectObject intensity_obj
								intensity_mean = Get mean: t_left, t_right, "energy"
							endif
							call ReportValue intensity_mean 2
						endif

###
#	compute pitch data for all requested units
###
### first for mean and quantile
						for i_unit to nr_units
# get the coding back for this unit
# (and use unit$, unit_stdev$ and un$ locally in this loop, incl. procedures)
							unit$ = unit'i_unit'$
							unit_stdev$ = unit_stdev'i_unit'$
							un$ = un'i_unit'$

# Get the mean pitch value if required (mean and stdev might be used for z-score too!)
							if (im_request or cs_request or cz_request)
								call SelectObject pitch_obj
								mean_pitch = Get mean: t_left, t_right, unit$
								stdev_pitch = Get standard deviation: t_left, t_right, unit_stdev$
								call ReportValue mean_pitch 2
								call ReportValue stdev_pitch 2
							endif

# Get quantiles if required
							if (nr_quantiles)
								for i_quantile to nr_quantiles
									selectObject: quantile_obj
									quantile_value$ = Get string: i_quantile
									quantile_value = number(quantile_value$) / 100
									call SelectObject pitch_obj
									quantile  = Get quantile: t_left, t_right, quantile_value, unit$
									call ReportValue quantile 2
								endfor
							endif
# end of units loop
						endfor

###
# 	report contour data
###

# report times, intensity and pitch at measurement point only once (if requested at all)
						if (number_of_measurements)

# report time data
							if (ct_request)
								call ReportContour t
							endif

# report intensity data
							if (ci_request)
								call ReportContour i
							endif

# Use the same mechanisme for contours of times, values, means subtraction, and z-score

							for i_unit to nr_units
# get the coding back for this unit
# (and use unit$, unit_stdev$ and un$ locally in this loop, incl. procedures)
								unit$ = unit'i_unit'$
								unit_stdev$ = unit_stdev'i_unit'$
								un$ = un'i_unit'$

								call ReportContour p
								
								if (cs_request)
									call ReportContour s
								endif
								if (cz_request)
									call ReportContour z
								endif
# end of units loop
							endfor

# reporting contour data
						endif
# all one interval handled - report data
						fileappend 'result_file_name$' 'out_line$''newline$'

# label, duration, or intensity requirements of the interval are not met
# report interval with missing info depending on 'report_skipped_intervals' and 'l_flag'
# either all, or only if label$ is okay or none
					elsif (report_skipped_intervals = 1) or ((report_skipped_intervals = 2) and l_flag)
						call PrepareOutputLine
# skip reporting of percentages of pitch in this interval						
						out_line$ += missing_value$
						if (ii_request)
							out_line$ += "'sep$''intensity_mean:01'"
						endif
						out_line$ += "'skip_line$'"
						fileappend 'result_file_name$' 'out_line$''newline$'

# label, duration, and intensity test
					endif


# going thru all intervals of a TextGrid
				endfor				

# entertain user
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

# requested tier number if higher than number of tiers
		else
			if (!user_feedback)
				print File 'base_name$''space$'
			endif
			printline **> has only 'nr_tiers' tiers. File skipped. <**
		endif

# grid file does not exist test
	else
		no_grid += 1
		if (!user_feedback)
			print 'base_name$'
		endif
		printline has no TextGrid. File skipped. ***
	endif

# clean up
	call RemoveObjects

# going thru files
endfor

# clean up (do not use 'remove all' because the user might have some objects hanging around

removeObject: wav_list_obj
if (label_flag = label_list)
	removeObject: label_list_obj
elsif (label_flag > 10)
	removeObject: vowel_obj
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

if (!whole_file and no_grid)
	printline 'no_grid' TextGrid files not found.
endif
printline Results are written to 'result_file_name$'. 'newline$'Program completed.


#########################################################################################
#
# Procedure to check and recode user input
#
#########################################################################################

procedure CheckParameters

# get tier number (an integer field in the from window cannot be left empty,
# so we used a 'word' and convert it to a number here)
	tier = number(tier$)
	if (tier = undefined)
		tier = 0
	endif

# get number of measurements (an integer field in the from window cannot be left empty,
# so we used a 'word' and convert it to a number here)
	number_of_measurements = number(number_of_measurements$)
	if (number_of_measurements = undefined)
		number_of_measurements = 0
	endif

# recode unit selection for computation and output
	units$ = replace_regex$ (units$, ".", "\L&", 0)
	units$ = replace_regex$ (units$, " ", ",", 0)
	units_obj = Create Strings as tokens: units$, " ,"
	nr_units = Get number of strings

	if (nr_units = 0)
		printline No unit specified: no data computed.
		exit
	endif

# set units and symbols
	for i_unit to nr_units
		selectObject: units_obj
		unit$ = Get string: i_unit
		if (unit$ = "h")
			unit'i_unit'$ = "Hertz"
			unit_stdev'i_unit'$ = "Hertz"
			un'i_unit'$ = "Hz"
		elsif (unit$ = "l")
			unit'i_unit'$ = "logHertz"
			unit_stdev'i_unit'$ = "logHertz"
			un'i_unit'$ = "logHz"
		elsif (unit$ = "s")
			unit'i_unit'$ = "semitones re 1 Hz"
			unit_stdev'i_unit'$ = "semitones"
			un'i_unit'$ = "st"
		elsif (unit$ = "m")
			unit'i_unit'$ = "mel"
			unit_stdev'i_unit'$ = "mel"
			un'i_unit'$ = "mel"
		elsif (unit$ = "e")
			unit'i_unit'$ = "ERB"
			unit_stdev'i_unit'$ = "ERB"
			un'i_unit'$ = "ERB"
		else
			printline Illegal unit selection: 'unit$'. Program aborted.
			exit
		endif
	endfor
	removeObject: units_obj


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
			printline No TextGrids found. Only whole file measures will be reported.
		endif
		removeObject: grid_list_obj
	endif

# which interval parameters are required?
# preset mean (s)ubtraction, (z)-scores, (t)ime point reporting, (m)eans and quantiles to 'not requested' (= 0)
	ii_request = 0
	im_request = 0
	nr_quantiles = 0
	
	if (minimal_intensity)
		ii_request = 1
	endif

# check interval_parameters field
	interval_parameters$ = replace_regex$ (interval_parameters$, ".", "\L&", 0)
	interval_parameters$ = replace_regex$ (interval_parameters$, " ", ",", 0)
	item_obj = Create Strings as tokens: interval_parameters$, " ,"
	nr_items = Get number of strings

# check whether anything is selected at all
	if ((nr_items = 0) and (number_of_measurements = 0))
		printline Neither Intensity, Mean, Quantiles or measurement points are selected: no data computed.
		exit
	endif

# go thru requested measures (add 'symmetrical' quantiles, sort them and remove doublets)
# (if no inerval parameters are selected, this loop will be skipped since nr_items will be 0)
	for i_item to nr_items
		selectObject: item_obj
		item$ = Get string: i_item
# intensity requested?
		if (item$ = "i")
			ii_requested = 1
# means requested?
		elsif (item$ = "m")
			im_request = 1

# if none of the above, assume numbers, i.e. quantils (in percentages)
# the quantile values are stored in quantile_obje and used during computation from there
# (Illegal interval_parameters$ input will be captured by generating an 'undefined' numerical value from a string below!)
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
				printline Illegal parameter in Interval parameters: "'item$'". Computation aborted."
				exit
			endif
		endif
	endfor
	removeObject: item_obj

# sort quantiles (if required)
	if (nr_quantiles)
		call SortQuantiles
	endif

# check time and pitch contour parameters
# preset requests to 'not requested' (= 0)
	ci_request = 0
	cs_request = 0
	ct_request = 0
	cz_request = 0
	
# convert to lower case and convert spaces to commas first
	contour_parameters$ = replace_regex$ (contour_parameters$,".","\L&",0)
	contour_parameters$ = replace_regex$ (contour_parameters$, " ", ",", 0)
	item_obj = Create Strings as tokens: contour_parameters$, " ,"
	nr_items = Get number of strings

# go thru requested formant contour measures
# (using a method like ci_request = (item$ = "i") would miss wrong inputs!)
	for i_item to nr_items
		selectObject: item_obj
		item$ = Get string: i_item
# time position requested?
		if (item$ = "t")
			ct_request = 1
# intensity requested?
		elsif (item$ = "i")
			ci_request = 1
# mean subtraction requested?
		elsif (item$ = "s")
			cs_request = 1
# force mean request (to be able to do a substraction)
			im_request = 1
# z-scores requested?
		elsif (item$ = "z")
			cz_request = 1
# force mean request (to be able to compute z-scores)
			im_request = 1
# if none of the above issue error message
		else
			printline Illegal parameter in Contour parameters definition: "'item$'". Computation aborted."
			exit
		endif
	endfor
	removeObject: item_obj

### check which intervals are to be analyzed; set constants first:
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
		help_obj = Read Strings from raw text file: label$
		nr_labels = Get number of strings
		if (nr_labels < 1)
			printline File 'label$' has no text lines. Script aborted.
			exit
		endif
		printline 'nr_labels' labels found in file 'label$'.

# change <space> and <underline> to a strange symbol-sequence,
# because PRAAT puts them into separate entries in the word list
##@@
		label_list_obj = To WordList
		removeObject: help_obj
		label_flag = label_list

# treat input as one or more labels, separated by comma and pretend they come from a label file
	else
# change <space> and <underline> to a strange symbol-seqeunce,
# because PRAAT puts them into different entries in the word list
##@@
##		label$ = replace_regex$ (label$, " ", "§§$$§§", 0)
		help_obj = Create Strings as tokens: label$, " ,"
		nr_labels = Get number of strings
		if (nr_labels < 1)
			printline No valid label information found. Script aborted.
			exit
		endif
		label_list_obj = To WordList
		removeObject: help_obj
		label_flag = label_list
	endif

# too many contour measuremnts?
	if (number_of_measurements > max_number_of_measurements)
		pause Do you really want 'number_of_measurements' measurements per interval?
	endif

endproc


#########################################################################################
#
#	Procedure to sort quantiles and remove doublets
#
#########################################################################################

procedure SortQuantiles

# add leading zeros to allow alphabetical sorting (and as preparation for removing doublets)
##@@ (Is there something like sprintf in praat to do the formating?)
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


#########################################################################################
#
#	Procedure to create resultfile
#
#	Report in the sequence (see (7) in main script:
#	Location:
#		(path) file label start duration
#	Interval information:
#		(mean intensity) 
#		for pitch units
#			(mean pitch) (stdev pitch) (quantiles)
#		endfor
#	Contour information (loop thru time points on lower level inside 'ReportContour'):
#		(time) (intensity) 
#		for pitch units
#			pitch (mean subtraction) (z-score)
#		endfor
#
#########################################################################################

procedure CreateResultFile

# string for missing values in output
	missing_value$ = "'sep$''missing_value_symbol$'"

# create file name with date and time
	call GetDate date_time$
	result_file_name$ = result_directory$+"pitch_results_"+date_time$+".txt"

# create header, dummy and missing data lines (first part is always there, so no missing data needed)
# (first part is always there, so it will not be needed to removed from the skipped line later)
	out_line$ = ""
	dummy_line$ = ""
	if (path_name)
		out_line$ += "Path'sep$'"
		dummy_line$ += "dummy'sep$'"
	endif
	out_line$ += "File'sep$'Label'sep$'Start(s)"
	dummy_line$ += "dummy'sep$'dummy'sep$'0.0"
	if (duration_in_ms)
		out_line$ += "'sep$'Duration(ms)"
	else
		out_line$ += "'sep$'Duration(s)"
	endif
	dummy_line$ += "'sep$'0.0"

# add nr. of voiced frames as percentage (evenif only center is requested)
	out_line$ += "'sep$'Voiced(%)"
	dummy_line$ += "'sep$'0.0"

# report intensity data for interval if requested
	if (ii_request)
		out_line$ += "'sep$'Intensity_mean(dB)"
		dummy_line$ += "'sep$'0.0"
	endif
	remove_from_dummy$ = dummy_line$

# create header for different units
	for i_unit to nr_units

# get the coding back for un$ in procedures
		un$ = un'i_unit'$

# add header for mean and st.dev.
		if (im_request)
			out_line$ += "'sep$'Mean('un$')'sep$'StDev('un$')"
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
				out_line$ += "'sep$''quantile_value:2'%('un$')"
			endif
			dummy_line$ += "'sep$'0.0"
		endfor
# looping thru headers
	endfor

# contour required (i.e. number_of_measurements <> 0)?
	if (number_of_measurements)

# time onfo only once (if at all)
		if (ct_request)
			call ContourHeader t
		endif

# create header for different units
		for i_unit to nr_units

# get the coding back for un$ in procedures
			un$ = un'i_unit'$

			call ContourHeader p
			if (cs_request)
				call ContourHeader s
			endif
			if (cz_request)
				call ContourHeader z
			endif
# looping thru headers
		endfor
# contour required (i.e. number_of_measurements <> 0)
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
	skip_line$ = replace_regex$(skip_line$,"0.0",missing_value_symbol$,0)

endproc


#########################################################################################
#
#	Procedure to add header for contour measurements
#
#########################################################################################

procedure ContourHeader x$

	p1$ = "left"
	p2$ = "center"
	p3$ = "right"

# any time point measurement other than center (= 1)?
	if (number_of_measurements <> 1)
		perc_step = 100.0 / (number_of_measurements-1)
	endif

# adjust unit for report
	if (x$ = "p")
		pos_unit$ = "('un$')"
	elsif (x$ = "s")
		pos_unit$ = "('un$')"
	elsif (x$ = "t")
		pos_unit$ = "(s)"
	elsif (x$ = "z")
		pos_unit$ = "(z)"
	else
		printline Illegal parameter for procedure ContourHeader: "'x$'". Computation aborted."
		exit
	endif

# next loop is only enterd if any time point measurements (incl. center and edges ) are requested
	for i_pos to number_of_measurements

# special handling if only 3 or less required
		if (number_of_measurements = 1)
			p$ = p2$
			position$ = "'x$'_'p$'"
		elsif (number_of_measurements = 2)
			if (i_pos = 1)
				p$ = p1$
			else
				p$ = p3$
			endif
			position$ = "'x$'_'p$'"
		elsif (number_of_measurements = 3)
			p$ = p'i_pos'$
			position$ = "'x$'_'p$'"
		elsif (position_in_percentage)
			perc = (i_pos-1) * perc_step
			position$ = "'x$'_'perc:2'%"
		else
			position$ = "'x$'_'i_pos'"
		endif

		out_line$ += "'sep$''position$''pos_unit$'"
		dummy_line$ += "'sep$'0.0"
	endfor
endproc


#########################################################################################
#
#	Procedue to select a data object (if it exists already), otherwise, compute data first
#	This procedure also reads in the wav file, if not dome already!
#
#########################################################################################

procedure SelectObject obj$
	if ('obj$')
		selectObject: 'obj$'
	else
# no sound object loaded yet?
		if ((!'wav_obj') or (obj$ = "wav_obj"))
			wav_obj = Read from file: "'wav_directory$''wav_name$'"
			nr_wav += 1
		else
			selectObject: wav_obj
		endif

		if (obj$ = "intensity_obj")
			intensity_obj = 'np_string$' To Intensity: low_F0, step_rate, "yes"
		elsif (obj$ = "pitch_obj")
			pitch_obj = 'np_string$' To Pitch: step_rate, low_F0, high_F0
		elsif (obj$ = "wav_obj")
		else
			printline Illegal object in procedure SelectObject: 'obj$'. Program aborted.
			exit
		endif
	endif
endproc


#########################################################################################
#
#	Procedure to open sound- and TextGrid file
#	(or generate dummy TextGrid if whole files should be analysed)
#
#########################################################################################

procedure OpenFiles
	selectObject: wav_list_obj
	wav_name$ = Get string: i_file
# Do not use "selected$("Sound")" go get the sound file name, because PRAAT converts
# many symbols (like a tilde "~") into an underline ("_")
	base_name$ = replace_regex$(wav_name$,"'sound_ext$'$","",1)

	if (user_feedback)
		print Handling 'base_name$''space$'
	endif

# preset grid_obj to be able to indicate missing TextGrid
	grid_obj = 0

# create fake grid if whole file should be analyzed (no special handling for whole file needed)
	if (whole_file)
		call SelectObject wav_obj
		grid_obj = To TextGrid: "dummy", ""
	else

# check whether TextGrid exists
		grid_name$ = grid_directory$+base_name$+".TextGrid"
		if (fileReadable(grid_name$))

# TextGrid file exists?
			grid_obj = Read from file: grid_name$
		endif
	endif
endproc


#########################################################################################
#
#	Procedure to prepare output line (generate first part of line)
#
#########################################################################################

procedure PrepareOutputLine
	out_line$ = ""
	if (path_name)
		out_line$ += "'wav_directory$''sep$'"
	endif
	out_line$ += "'base_name$''sep$''interval_label$''sep$''t_start:04'"
	if (duration_in_ms)
		out_line$ += "'sep$''duration_ms:01'"
	else
		out_line$ += "'sep$''duration:04'"
	endif
endproc


#########################################################################################
#
#	Procedure to report contour values
#
#########################################################################################

procedure ReportContour x$

# Go thru measurements for a contour (special handling for '1' (center), '2' (edges', '3' (edges and center)
	if (number_of_measurements)

# Get pitch values of time points; use 'mid' as guiding time
		if (number_of_measurements = 1)
			dur_step = (t_right - t_left)
			mid = (t_right + t_left) / 2

# compute positions
		else
			dur_step = (t_right - t_left) / (number_of_measurements-1)
			mid = t_left
		endif

# report times of measurement
		if (x$ = "t")
			for i_pos to number_of_measurements
				call ReportValue mid 4
				mid += dur_step
			endfor

# report imtensity at this point
		elsif (x$ = "i")
			call SelectObject intensity_obj
			for i_pos to number_of_measurements
				intensity = Get value at time: mid, "cubic"
				call ReportValue intensity 1
				mid += dur_step
			endfor

# report pitch at this point
# (store values in variables like pitch1, pitch2…) for subtract mean or z-scores
		elsif (x$ = "p")
			for i_pos to number_of_measurements
				selectObject: pitch_obj
				pitch'i_pos' = Get value at time: mid, unit$, interpolation$
				call ReportValue pitch'i_pos' 2
				mid += dur_step
			endfor

# report subtracted mean
# (pitch values are already computed at this time and stored in variables like pitch1, pitch2…)
		elsif (x$ = "s")
			for i_pos to number_of_measurements
				pitch_s = pitch'i_pos' - mean_pitch
				call ReportValue pitch_s 2
			endfor

# report z-scores
# (pitch values are already computed at this time and stored in variables like pitch1, pitch2…)
		elsif (x$ = "z")
			for i_pos to number_of_measurements
				pitch_z = (pitch'i_pos' - mean_pitch) / stdev_pitch
				call ReportValue pitch_z 2
			endfor
			
# this should not happen
		else
			printline Unexpected ReportContour parameter: 'x$'. Script aborted.
			exit
		endif

# contour measurement required?
	endif
endproc


#########################################################################################
#
#	Procedure report the amount of voicing in an interval in percentage or interval length
#
#########################################################################################

procedure ReportVoicing

# compute percentage of voiced stretch within interval (see pitch_manual.pdf for documentation)
# compute percentage of first and last frame inside interval
# Praat's frames do not start at "0" but about 20 ms later.
# use Praat's 'get frame number form time' to get actual frame (as real number)
# 'frame_left' is a real value for a frame number (not a time!), e.g. "7.345"
# subtracting it from its floor (here: '7') gives a value between 0 and 0.999… (here: 0.345')
# indicating the portion of time that is voiced (multiplying it with 100 gives the percentage).
# The term (x <> undefined) is '1' if there is a (pitch-)value in 'x', and '0' otherwise.
# I.e., multiplying this with the portion of voicing give a '0' for unvoiced frames or the
# portion of voicing for the frame (likewise for 'frame_right').
# Because the first frame has been evaluated in this why, the counting of frames
# (from 'start_frame') has to be increased.

	frame_left = Get frame number from time: t_left
	start_frame = floor(frame_left)
	x = Get value in frame: start_frame, unit$
	start_frame += 1
	dur_voiced_left = (x <> undefined) * (start_frame - frame_left)
	frame_right = Get frame number from time: t_right
	end_frame = ceiling(frame_right)
	x = Get value in frame: end_frame, unit$
	end_frame -= 1
	dur_voiced_right = (x <> undefined) * (frame_right - end_frame)

# count now the frames that are completely inside interval
# we have to end one additional frame earlier, because the estimatin starts from the beginning of a frame!
	end_frame -= 1
	nr_voiced = 0
	for i_frame from start_frame to end_frame
		x = Get value in frame: i_frame, unit$
		nr_voiced += (x <> undefined)
	endfor
	percent = 100 * (dur_voiced_left + nr_voiced + dur_voiced_right) * step_rate / duration
	out_line$ += "'sep$''percent:0'"
endproc


#########################################################################################
#
#	Procedure to get label$, duration of interval and check whether it should be reported
#
#########################################################################################

procedure CheckLabel
	selectObject: grid_obj
	interval_label$ = Get label of interval: tier, i_interval

# find edges and measure length of whole interval
	t_start = Get starting point: tier, i_interval
	t_end = Get end point:     tier, i_interval
	duration = t_end - t_start
	duration_ms = duration * 1000

# redefine left and right edges in case no crossing of interval is requested
# (remember that duration is the 'real' duration; do not use it for computations of the adjusted length!)
	if (cross_interval_boundary)
		t_left = t_start
		t_right = t_end
	else
		t_left = t_start + half_window_length
		t_right = t_end - half_window_length
	endif
	
#
# check whether this interval should be reported
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
endproc


#########################################################################################
#
#  Procedure to report one value
#
#########################################################################################

procedure ReportValue v l
	if (v <> undefined)
		if (l = 0)
			out_line$ += "'sep$''v:0'"
		elsif (l = 1)
			out_line$ += "'sep$''v:01'"
		elsif (l = 2)
			out_line$ += "'sep$''v:02'"
		elsif (l = 3)
			out_line$ += "'sep$''v:03'"
		elsif (l = 4)
			out_line$ += "'sep$''v:04'"
		elsif (l = 5)
			out_line$ += "'sep$''v:05'"
		elsif (l = 6)
			out_line$ += "'sep$''v:06'"
		else
			out_line$ += "'sep$''v'"
		endif
	else
		out_line$ += "'missing_value$'"
	endif
endproc


#########################################################################################
#
#	Procedure to remove used objects
#
#########################################################################################

procedure RemoveObjects
	if (wav_obj)
		removeObject: wav_obj
	endif
	if (grid_obj)
		removeObject: grid_obj
	endif
	if (intensity_obj)
		removeObject: intensity_obj
	endif
	if (pitch_obj)
		removeObject: pitch_obj
	endif
endproc


#########################################################################################
#
#	Procedure to convert Praat's date and time to a date-and-time string
#
#########################################################################################

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


#########################################################################################
#
#	Procedure to report analyse parameters
#
#########################################################################################

procedure ReportAnalysisParameter
	out_line$ = newline$
	out_line$ += "Script: Pitch_'version'_'revision'_'bugfix'.praat'newline$'"
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
	out_line$ += "Computation units: 'unit$''newline$'"
	out_line$ += "Step rate: 'step_rate' s'newline$'"
	out_line$ += "Low F0: 'low_F0' Hz'newline$'"
	out_line$ += "High F0: 'high_F0' Hz'newline$'"
	out_line$ += "Minimal duration: 'minimal_length_ms' ms'newline$'"
	out_line$ += "Minimal intensity: 'minimal_intensity' dB'newline$'"
	fileappend 'result_file_name$' 'out_line$'
endproc

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
#		There is no versions 4. I jump to 5 to synchronise the style with the other scripts
#	Vers. 5.0.0, Henning Reetz, 05-nov-2020; synchronizing with other scripts; correct quantiles sorting
#	Vers. 6.0.0, Henning Reetz, 12-nov-2020; merged with Intensity_contour, subtract mean and z-scores options added
#	Vers. 6.0.1, Henning Reetz, 14-nov-2020; Tier 0 comment in form added, interpolation as parameter, 'energy' as default unit for intervals
#	Vers. 6.1.0, Henning Reetz, 19-nov-2020; Some clean-up: added procedures for common tasks
#	Vers. 6.1.1, Henning Reetz, 20-nov-2020; Now correct contour values if t_request is on
#	Vers. 6.1.2, Henning Reetz, 24-jan-2021; kurtosis' beta added 
#		(cf. Qiu et al. (2020) A New Tool for Noise Analysis, Acoustics today, 16(4), 39–47. DOI: 10.1121/AT.2020.16.4.39)
#	Vers. 6.2.0, Henning Reetz, 25-jan-2021; delayed open added (cf. formants_5_0_0.praat) 
#	Vers. 6.2.1, Henning Reetz, 02-feb-2021; bug fixed if Tier=0 
#
#	Tested with Praat 6.1.38
#
#@@ point tier handling not included
#@@ allow spaces in interval labels
#@@ add more than 1 tier in selecting and sorting
##

version = 6
revision = 2
bugfix = 1

# clear feedback window
clearinfo
# variable space$ in case we really need a space at the end of a line
space$ = " "

###
#	1) Inquire and check some parameters
#	(This form fits into screen with 640 pixel vertical resolution)
#	! Note that 'form' may only be used once in a script!
###

form Intensity parameters (Vers. 6.2):
	comment Leave the directory path empty if you want to use the current directory.
		text Directory
	comment Set tier to 0 if whole file to be analysed.
		word Tier 1
	comment ______________________________________________________________________________________________________________
	comment <label>, <list>.txt, '.' (= only labelled), or empty (= all)
		sentence Label .
	comment (m)ean, (k)urtosis, <list of quantiles in %> of intervals
		sentence Interval_parameters m
	comment Nr. of measurements per interval (for a contour) 1: only center, 2: only edges
		word Number_of_measurements 0
	comment (t)ime of measurement, additionally mean (s)ubtraction or (z)-scores?
		sentence Contour_parameters t
	comment ______________________________________________________________________________________________________________
	choice Report_skipped_intervals: 2
		button All
		button None
		word Missing_value_symbol .
endform


###
# 	2) Adjust the following settings as you prefer them (and/or add things from the form menu below)
###

## use this in the form window, in case you want to have it there
#	comment ______________________________________________________________________________________________________________
#	choice Unit: 1
#		button energy
#		button sones
#		button dB
# set default unit to 'energy' (i.e. unit = 1 in the choice syntax or the form window)
# this will report values that are closest to the mean values for intervals
unit = 1

# intensity computation parameters
step_rate = 0.005
low_F0 = 50

# minimal length in ms
minimal_length_ms = 0

# position reporting in steps (1, 2, 3,…) or percentage (0%, 25%…) of interval
position_in_percentage = 1

# maximal number of intervals for reporting the contour
max_number_of_measurements = 50

# type of interpolation (nearest, linear, cubic, sinc70, sinc700)
interpolation$ = "cubic"

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
#	wav_directory$ = "'directory$'Sound/"
#	grid_directory$ = "'directory$'Grid/"
#	result_directory$ = "'directory$'Result/"
#	support_directory$ = "'directory$'Support/"

# should the name of the diectory path be reported (path_name = 1) or not (path_name = 0)
path_name = 0

# extension of the audio files
sound_ext$ = ".wav"

# separator for output list (e.g. = "," for csv files)
sep$ = tab$

# should there be user feedback (= 1) or none to speed up processing  (= 0)
user_feedback = 1

# should there be no processing information from Praat (= "noprogress") or not (= ""  ; i.e. empty string)
np_string$ = "noprogress"

# should there be a data header to force correct data type in JMP or other tables (= 1) or not (= 0)
dummy_data_header = 0

# report duration in ms (duration_in_ms = 1) or seconds (duration_in_ms = 0)
duration_in_ms = 1

###
#	3) Check input and create result file
###

# check and recode user input
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

	call OpenFiles
# perform next steps only if there is a grid object (it is selected at this point)
	if (grid_obj)
		nr_tiers = Get number of tiers
		if (tier <= nr_tiers)

# check whether tier is an interval tier.
			tier_is_interval = Is interval tier: tier
			if  (tier_is_interval)

# if any of the above attempts to open a file worked, we should be save now
# compute pitch and intensity (needed for report and test)
				call SelectObject wav_obj
				intensity_obj = 'np_string$' To Intensity: low_F0, step_rate, "yes"

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
# This procedure defines and sets the variable l_flag
					call CheckLabel

### check for minimal duration
					d_flag = (duration_ms > minimal_length_ms)

###
#	7) check whether all conditions are met; if so, start reporting data
#
#	Report in the sequence:
#	Location:
#		(path) file label start duration
#	Interval information:
#		(kurtosis) (mean intensity) (quantiles)
#	Contour information (loop thru time points on lower level inside 'ReportContour'):
#		(time) intensity (mean subtraction) (z-score)
###
					if (l_flag and d_flag)
						nr_measured_intervals += 1

# prepare output line
						call PrepareOutputLine

# compute kurtosis if requested
						if (ik_request)
							call SelectObject wav_obj
							on = Get sample number from time: t_left
							on = round(on)
							off = Get sample number from time: t_right
							off = round(off)
							diff = off-on						
							sum_sq = 0
							sum_quad = 0
							for i from on to off
								sample = Get value at sample number: 0,i
##@@ check whether this can be speed up by using multiplications
								if (sample <> undefined)
									sum_quad += sample^4
									sum_sq += sample^2
								else
									diff -= 1
								endif
							endfor
							sum_quad /= diff
							sum_sq /= diff
							sum_sq = sum_sq^2
							beta = sum_quad/sum_sq
							call ReportValue beta 4
						endif

# select intensity object
						call SelectObject intensity_obj

# Get the mean intensity value if required
						if (im_request)
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
							call SelectObject intensity_obj
							quantile  = Get quantile: t_left, t_right, quantile_value
							call ReportValue quantile 2
						endfor

###
# report contour data
###

						if (number_of_measurements)

# report time data
							if (ct_request)
								call ReportContour t
							endif
# report intensity
							call ReportContour i

# report subtract mean
							if (cs_request)
								call ReportContour s
							endif

# report z-sscores
							if (cz_request)
								call ReportContour z
							endif
	 					endif

# all computations done for one interval that should be reported
						fileappend 'result_file_name$' 'out_line$''newline$'

#
# interval should not be reported (l_flag = 0), but the user might want to report skipped intyervals
#
					elsif (report_skipped_intervals = 1)
						call PrepareOutputLine
						out_line$ += "'skip_line$'"
						fileappend 'result_file_name$' 'out_line$''newline$'

# interval to be reported?
					endif

# going thru intervals
				endfor

# clean up
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

# check whether anything is requested at all
	if ((interval_parameters$ = "") and (number_of_measurements <= 0))
		printline Neither interval parameters nor contour data is requested: no data computed.
		exit
	endif

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
			printline No TextGrids found. Only whole file intensities will be reported.
		endif
		removeObject: grid_list_obj
	endif

### which interval_parameters are required?
# preset mean (s)ubtraction, (z)-scores, (t)ime point reporting, (k)urtosis, (m)eans and quantiles to 'not requested' (= 0)
	ik_request = 0
	im_request = 0
	cs_request = 0
	ct_request = 0
	cz_request = 0
	nr_quantiles = 0

# check interval_parameters field
	interval_parameters$ = replace_regex$ (interval_parameters$, ".", "\L&", 0)
	interval_parameters$ = replace_regex$ (interval_parameters$, " ", ",", 0)
	item_obj = Create Strings as tokens: interval_parameters$, " ,"
	nr_items = Get number of strings

# check whether anything is selected at all
	if ((nr_items = 0) and (number_of_measurements = 0))
		printline Neither Mean, Kurtosis, Quantiles, or measurement points are selected: no data computed.
		exit
	endif

#  add 'symmetrical' quantile and sort them (and remove doublets)@@ this has changed!!
	for i_item to nr_items
		selectObject: item_obj
		item$ = Get string: i_item
# kurtosis requested?
		if (item$ = "k")
			ik_request = 1
# means requested?
		elsif (item$ = "m")
			im_request = 1
# time position requested?
		elsif (item$ = "t")
			it_request = 1
# if none of the above, assume numbers, i.e. quantils (in percentages)
# (Illegal interval_parameters$ input willbe captured by generating an 'undefined' numerical value from a string below!)
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

### Check contour parameters
	contour_parameters$ = replace_regex$ (contour_parameters$,".","\L&",0)
	contour_parameters$ = replace_regex$ (contour_parameters$, " ", ",", 0)
	item_obj = Create Strings as tokens: contour_parameters$, " ,"
	nr_items = Get number of strings

# check item list
# (using a method like ct_request = (item$ = "t") would miss wrong inputs!)
	for i_item to nr_items
		selectObject: item_obj
		item$ = Get string: i_item

# time position requested?
		if (item$ = "t")
			ct_request = 1

# mean subtraction requested?
		elsif (item$ = "s")
			if (unit <> 1)
				printline Subtraction of means is only possible with "energy" units for means computation.
				printline Please change setting in the script to    unit = 1
				exit
			endif
# force mean request (to be able to compute mean subtraction)
			im_request = 1
			cs_request = 1
			
# z-scores requested?
		elsif (item$ = "z")
			if (unit <> 1)
				printline Subtraction of means is only possible with "energy" units for means computation.
				printline Please change setting in the script to    unit = 1
				exit
			endif
# force mean request (to be able to compute z-scores)
			im_request = 1
			cz_request = 1

# if none of the above issue error message
		else
			printline Illegal parameter in Contour parameters definition: "'item$'". Computation aborted."
			exit
		endif
	endfor
	removeObject: item_obj

### Check which intervals are to be analyzed; set constants first:
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
	if ((unit$ <> "energy") and !im_request)
		pause Unit "'unit$'" is only used for means computation, which is not requested!
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
#		(kurtosis) (mean intensity) (quantiles)
#	Contour information (loop thru time points on lower level inside 'ReportContour'):
#		(time) intensity (mean subtraction) (z-score)
#
#########################################################################################


procedure CreateResultFile

# string for missing values in output
	missing_value$ = "'sep$''missing_value_symbol$'"

# create file name with date and time
	call GetDate date_time$
	result_file_name$ = result_directory$+"intensity_results_"+date_time$+".txt"

# create header, dummy and missing data lines (first part is always there, so no missing data needed)
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
	remove_from_dummy$ = dummy_line$

# add header for kurtosis
	if (ik_request)
		out_line$ += "'sep$'Beta(kurtosis)"
		dummy_line$ += "'sep$'0.0"
	endif

# add header for mean and st.dev.
	if (im_request)
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
			out_line$ += "'sep$''quantile_value:2'%('un$')"
		endif
		dummy_line$ += "'sep$'0.0"
	endfor

# contour required (i.e. number_of_measurements <> 0)?
	if (number_of_measurements)
		if (ct_request)
			call ContourHeader t
		endif
		call ContourHeader i
		if (cs_request)
			call ContourHeader s
		endif
		if (cz_request)
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
	if (x$ = "i")
		pos_unit$ = "dB"
	elsif (x$ = "s")
		pos_unit$ = "dB"
	elsif (x$ = "t")
		pos_unit$ = "s"
	elsif (x$ = "z")
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

		out_line$ += "'sep$''position$'('pos_unit$')"
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
			intensity_obj = 'np_string$' To Intensity: low_pitch, step_rate, "yes"
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
	out_line$ += "'base_name$''sep$''interval_label$''sep$''t_left:04'"
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

# go thru measurements in n steps, starting at the left edge (= 'mid') or at the middle (for 1 measurement)
#@@@ make sure not to go beyond borders of recording (for 2, 3???

# Get intensity values at time points; use 'mid' as guiding time
		if (number_of_measurements = 1)
			dur_step = (t_right - t_left)
			mid = (t_right + t_left) / 2

# compute positions for analysis windows at segment boundaries
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
		
# report intensity at this point
# (store intensities in variables like intensity1, intensity2…) for subtract mean or z-scores
		elsif (x$ = "i")
			for i_pos to number_of_measurements
				call SelectObject intensity_obj
				intensity'i_pos' = Get value at time: mid, interpolation$
				call ReportValue intensity'i_pos' 2
				mid += dur_step
			endfor
	
# report subtracted mean 
# (intensities are already computed at this time and stored in variables like intensity1, intensity2…)
		elsif (x$ = "s")
			for i_pos to number_of_measurements
				intensity_s = intensity'i_pos' - mean_intensity
				call ReportValue intensity_s 2
			endfor
		
# report z-scores
# (intensities are already computed at this time and stored in variables like intensity1, intensity2…)
		elsif (x$ = "z")
			for i_pos to number_of_measurements
				intensity_z = (intensity'i_pos' - mean_intensity) / stdev_intensity
				call ReportValue intensity_z 2
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
#	Procedure to get label$, duration of interval and check whether it should be reported
#
#########################################################################################

procedure CheckLabel
	selectObject: grid_obj
	interval_label$ = Get label of interval: tier, i_interval

# find center and measure length
	t_left = Get starting point: tier, i_interval
	t_right = Get end point:     tier, i_interval
	duration = t_right - t_left
	duration_ms = duration * 1000

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



##
#	This script opens all sound files in a directory and associated TextGrids (if they exist),
#	computes the mean pitch of intervalls
#	(or the whole file) that have a name and writes the results together with the durations
#	of these intervals/files into a text file.
#
# **> Please read 'pitch.pdf' for a full description of this rather complex script.
# **> Please feel free to use and modify this script to your needs.
# **> But please report errors or give suggestions for improvements to <reetz.phonetics@gmail.com>
#
#	Version 1.0, Henning Reetz, 02-jul-2007
# 	Version 1.1, Henning Reetz, 22-jun-2009	'tier' added in form
#	There are no versions 2 or 3. I jump to 4 to synchronise the style with the other scripts
#	Version 4.0, Henning Reetz, 09-oct-2020	mayor revsision; adapted from intensity_mean_3_0.praat
#	Version 5.0, Henning Reetz, 26-oct-2020	new list syntax, tier=0 => whole file, correct quantile sorting
#
# Tested with Praat 6.1.27
##

##@@ allow points
##@@ allow spaces in interval labels

version = 5
revision = 0
bugfix = 0

clearinfo
space$ = " "

## 1) Inquire some parameters
# (This form fits into screen with 1024 pixel vertical resolution)
# ! Note that 'form' may only be used once in a script!

form Pitch parameters (Vers. 5.0):
	comment Leave the directory path empty if you want to use the current directory.
		text Directory
	comment Set tier to 0 if whole fiel to be analysed.
		integer Tier 1
	comment ______________________________________________________________________________________________________________
	comment <label>, <list>.txt, '.' (= only labelled), or empty (= all)
		sentence Label .
	comment ______________________________________________________________________________________________________________
	comment (i)ntensity, (c)enter, (e)dges, (m)ean, <list of quantiles in %>
		sentence Measurements i,c,m,0,50
	comment ______________________________________________________________________________________________________________
		real low_F0 75.0
		real high_F0 500.0
	comment ______________________________________________________________________________________________________________
	choice Report_skipped_intervals: 2
		button All
		button Length or Intensity exclusion
		button None
endform

##
# 2) Change the following settings as you prefer them (and/or add things from the form menu below)
##

# units of measurement (not in the form above, because it takes too much space)
# copy the 6 lines below into the form window if you want it there
#	comment ______________________________________________________________________________________________________________
#	choice Unit: 1
#		button Hertz
#		button semitones (re 1 Hz)
#		button mel
#		button ERB
#
# default used here: Hertz
unit = 1

# pitch computation parameters
# real Step_rate 0.005
step_rate = 0.005

# minimal length for an interval to be reported (0 = no restriction)
# real minimal_length_ms 25
minimal_length_ms = 25

# minimal intensity for an interval to be reported (0 = no restriction)
#**> note that this parameter becomes only relevant if i_request is set!
# real minimal_intensity 40
minimal_intensity = 40

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
# word ext .wav
ext$ = ".wav"

# missing values symbole (e.g. "NA" for R or "." for JMP)
# word Missing_values_symbol .
missing_values_symbol$ = "NA"

# separator for output list (e.g. = "," for csv files)
sep$ = tab$

# should there be minimal user feedback to speed up processing (= 1) or not (= 0)
# boolean User_feedback 1
user_feedback = 1

# should there be no processing information from Praat (= "noprogress") or not (= ""  ; i.e. empty string)
np_string$ = "noprogress"

# should the  absolute time of a measurement be reported (t_request = 1) or not (t_request = 0)?
# boolean t_request 1
t_request = 0

# should there be a dummy data header to force correct data type in JMP or other tables (= 1) or not (= 0)
# boolean Dummy_data_header 0
dummy_data_header = 0

# report duration in ms (duration_in_ms = 1) or seconds (duration_in_ms = 0)
duration_in_ms = 1

##
# 3) Check input and create result file
##

# check and recode user input
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
	print Computing...'space$'
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

# preset grid_obj to be able to indicate missing TextGrid
	grid_obj = 0

# create fake grid if whole file should be analyzed (no special handling for whole file needed)
	if (whole_file)
		grid_obj = To TextGrid: "dummy", ""
	else

# check whether TextGrid exists
		grid_name$ = grid_directory$+base_name$+".TextGrid"
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
				pitch_obj = 'np_string$' To Pitch: step_rate, low_F0, high_F0
# compute intensity if requeired
##@@ check with intensity required and minimal intensity!
				if (i_request)
					selectObject: wav_obj
					intensity_obj = 'np_string$' To Intensity: 100, 0, "yes"
				endif
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
					t1 = Get starting point: tier, i_interval
					t3 = Get end point:      tier, i_interval
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

### check for intensity if required
					if (i_request)
						selectObject: intensity_obj
						intensity_mean = Get mean: t1, t3, "energy"
						i_flag = (intensity_mean > minimal_intensity)

# essentially ignore intensity
					else
						i_flag = 1
					endif

					if (l_flag and d_flag and i_flag)
						nr_measured_intervals += 1

# prepare output line
						if (path_name)
							fileappend 'result_file_name$' 'wav_directory$''sep$'
						endif
						fileappend 'result_file_name$' 'base_name$''sep$''interval_label$''sep$''t1:04'
						if (duration_in_ms)
							fileappend 'result_file_name$' 'sep$''duration_ms:01'
						else
							fileappend 'result_file_name$' 'sep$''duration:04'
						endif

##@@ add statistics sentence here and check for anything requested
#@@ lower case; spaces to comma, whole words?

						if (i_request)
							if (intensity_mean <> undefined)
								fileappend 'result_file_name$' 'sep$''intensity_mean:02'
							else
								fileappend 'result_file_name$' 'missing_value$'
							endif
						endif
# select pitch object
						selectObject: pitch_obj

# report edges and center if required
						if (e_request)
							pitch = Get value at time: t1, unit$, "linear"
							call ReportPitch pitch
						endif
						if (c_request)
							pitch = Get value at time: t2, unit$, "linear"
							call ReportPitch pitch
						endif
						if (e_request)
							pitch = Get value at time: t3, unit$, "linear"
							call ReportPitch pitch
						endif

# Get the mean pitch value if required
						if (m_request)
							mean = Get mean: t1, t3, unit$
							stdev = Get standard deviation: t1, t3, unit_stdev$
							call ReportPitch mean
							call ReportPitch stdev
						endif

# Get quantiles if required (if not, nr_quantils is zero and the next loop will be skipped)
						for i_quantile to nr_quantiles
							selectObject: quantile_obj
							quantile_value$ = Get string: i_quantile
							quantile_value = number(quantile_value$) / 100
							selectObject: pitch_obj
							quantile  = Get quantile: t1, t3, quantile_value, unit$
							call ReportPitch quantile
						endfor

# determine percentange of voiced frames if reporting means or quantiles
						if (m_request or nr_quantiles)

# the first and last frame will not coincide; compute percentage of them being within interval
# see pitch_manual.pdf for documentation
#@@ (this computation is not correct if interval is shorted than steprate!)
# compute percentage of first and last frame inside interval
# praat's frames do not start at "0" but about 20 ms later.
# use praat's 'get frame number form time' to get actual frame (as real number)@@Get frame number from time: 3.1325

							frame_1 = Get frame number from time: t1
							start_frame = floor(frame_1)
							x = Get value in frame: start_frame, unit$
							start_frame += 1
							dur_voiced_1 = (x <> undefined) * (start_frame - frame_1)
							frame_3 = Get frame number from time: t3
							end_frame = ceiling(frame_3)
							x = Get value in frame: end_frame, unit$
							end_frame -= 1
							dur_voiced_3 = (x <> undefined) * (frame_3 - end_frame)

# count now the frames that are completely inside interval
# we have to end one frame earlier, because the estimatin starts from the beginning of a frame
							nr_voiced = 0
							end_frame -= 1
							for i_frame from start_frame to end_frame
								x = Get value in frame: i_frame, unit$
								nr_voiced += (x <> undefined)
							endfor

							percent = 100 * (dur_voiced_1 + nr_voiced + dur_voiced_3) * step_rate / duration
							fileappend 'result_file_name$' 'sep$''percent:0'
						endif

						fileappend 'result_file_name$' 'newline$'
#
# interval should not be reported (l_flag = 0), but the user might want to report skipped intyervals
#
					elsif (report_skipped_intervals = 1) or ((report_skipped_intervals = 2) and l_flag)
# prepare output line
						if (path_name)
							fileappend 'result_file_name$' 'wav_directory$''sep$'
						endif
						fileappend 'result_file_name$' 'base_name$''sep$''interval_label$''sep$''t1:04'
						if (duration_in_ms)
							fileappend 'result_file_name$' 'sep$''duration_ms:01'
						else
							fileappend 'result_file_name$' 'sep$''duration:04'
						endif
						if (i_request)
							if (intensity_mean <> undefined)
								fileappend 'result_file_name$' 'sep$''intensity_mean:01'
							else
								fileappend 'result_file_name$' 'missing_value$'
							endif
						endif

# report edges and center if required
						if (e_request)
							fileappend 'result_file_name$' 'missing_value$'
						endif
						if (c_request)
							fileappend 'result_file_name$' 'missing_value$'
						endif
						if (e_request)
							fileappend 'result_file_name$' 'missing_value$'
						endif

# report mean pitch value if required
						if (m_request)
							fileappend 'result_file_name$' 'missing_value$''missing_value$'
						endif

# report quantiles if required (if not, nr_quantils is zero and the next loop will be skipped)
						for i_quantile to nr_quantiles
							fileappend 'result_file_name$' 'missing_value$'
						endfor

# report percentage of voiced frames if mean or quantiles are requested
						if (m_request or nr_quantiles)
							fileappend 'result_file_name$' 'missing_value$'
						endif

						fileappend 'result_file_name$' 'newline$'

					endif
				endfor

# clean up
				removeObject: pitch_obj
				if (i_request)
					removeObject: intensity_obj
				endif
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
# one file processed

		removeObject: wav_obj, grid_obj

# no TextGrid found
	else
		if (!user_feedback)
			print File 'base_name$''space$'
		endif
		printline **> skipped since it has no TextGrid. <**
		removeObject: wav_obj
	endif

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

# recode unit selection for computation and output
	if (unit = 1)
		unit$ = "Hertz"
		unit_stdev$ = "Hertz"
		un$ = "Hz"
	elsif (unit = 2)
		unit$ = "semitones re 1 Hz"
		unit_stdev$ = "semitones"
		un$ = "st"
	elsif (unit = 3)
		unit$ = "mel"
		unit_stdev$ = "Hertz"
		un$ = "mel"
	elsif (unit = 4)
		unit$ = "ERB"
		unit_stdev$ = "Hertz"
		un$ = "ERB"
	else
		printline Impossible unit selection: 'unit'. Program aborted.
		exit
	endif

# check whether whole file should be analyzed (i.e. whole_file)
	if (tier = 0)
		whole_file = 1
		tier = 1

# check whether there are TextGrid files; if the grid_list is empty, assume whole file treatment
	else
		grid_list_obj = Create Strings as file list:  "grid_list", "'grid_directory$'*.TextGrid"
		nr_grid_files = Get number of strings
		whole_file = (nr_grid_files = 0)
		removeObject: grid_list_obj
	endif

# check whether anything is selected at all
	if (measurements$ = "")
		printline Neither Intensity, Center position, Edges, Mean nor Quantiles are selected: no data computed.
		exit

# which measurements are required?
	else

# preset intensity, center position, edges, means and quantiles to 'not requested' (= 0)
		i_request = 0
		c_request = 0
		e_request = 0
		m_request = 0
		nr_quantiles = 0

#		replace_regex$ (measurements$, ".", "\L&", 0)
##@@??		replace_regex$ (measurements$, " ", ",", 0)
		measurements_obj = Create Strings as tokens: measurements$, " ,"
		nr_measurements = Get number of strings

#  add 'symmetrical' quantile and sort them (and remove doublets)@@ this has changed!!
		for i_measurement to nr_measurements
			selectObject: measurements_obj
			measurement$ = Get string: i_measurement
# intensity requested?
			if (measurement$ = "i")
# intensity information requested?
				i_requested = 1
# center position requested?
			elsif (measurement$ = "c")
				c_request = 1
# edhges requested?
			elsif (measurement$ = "e")
				e_request = 1
# means requested?
			elsif (measurement$ = "m")
				m_request = 1

# if none of the above, assume numbers, i.e. quantils (in percantages)
			else
				quantile_value = number(measurement$)
				if (quantile_value <> undefined)
					if ((quantile_value < 0) or (quantile_value>100))
						printline The quantile value 'quantile_value' is out of range; only numbers between 0 and 100 are allowed.'newline$'Script aborted.
						exit
					endif
					if (nr_quantiles = 0)
						quantile_obj = Create Strings as tokens: measurement$, " ,"
						nr_quantiles = 1
					else
						selectObject: quantile_obj
						nr_quantiles += 1
						Insert string: nr_quantiles, measurement$
					endif

# create symmetrical value (add them at the end of the string); even for median
					new_value = 100 - quantile_value
					new_value$ = string$(new_value)
					nr_quantiles += 1
					Insert string: nr_quantiles, new_value$
				else
					printline Illegal parameter in Measurement definition: "'measurement$'". Computation aborted."
					exit
				endif
			endif
		endfor
		removeObject: measurements_obj

# add leading zeros to allow alphabetical sorting (and as preparation for removing doublets)

		if (nr_quantiles)
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
		endif
# no quantils required, but if means are required, add median, using the same mechanism as quantiles
	elsif (m_request)
		quantile_obj = Create Strings as tokens: "50", " ,"
		nr_quantiles = 1
	else
		nr_quantiles = 0
	endif


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

# change <space> and <underline> to a strange symbol-seqeunce,
# because PRAAT puts them into different entries in the word list
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

endproc

##
#	Create resultfile
##

procedure CreateResultFile

# string for missing values in output
	missing_value$ = "'sep$''missing_values_symbol$'"

# create file name with date and time
	call GetDate date_time$
	result_file_name$ = result_directory$+"pitch_results_"+date_time$+".txt"

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

# add intensity header
	if (i_request)
		out_line$ += "'sep$'Intensity(dB)"
		dummy_line$ += "'sep$'0.0"
	endif

# add header for left, center, right
	p1$ = "Left"
	p2$ = "Center"
	p3$ = "Right"
	if (t_request)
		for i_pos to 3
			if (((i_pos<>2) and e_request) or ((i_pos=2) and c_request))
				position$ = p'i_pos'$
				out_line$ += "'sep$'t_'position$'(s)"
				dummy_line$ += "'sep$'0.0"
			endif
		endfor
	endif

	for i_pos to 3
		if (((i_pos<>2) and e_request) or ((i_pos=2) and c_request))
			position$ = p'i_pos'$
			out_line$ += "'sep$''position$'('un$')"
			dummy_line$ += "'sep$'0.0"
		endif
	endfor

# add header for mean and st.dev.
	if (m_request)
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
			out_line$ += "'sep$'Med('un$')"
		elsif (quantile_value = 100)
			out_line$ += "'sep$'Max('un$')"
		else
			out_line$ += "'sep$''quantile_value:1'%('un$')"
		endif
		dummy_line$ += "'sep$'0.0'"
	endfor

# add nr. of voiced frames as percentage
	if (m_request or nr_quantiles)
		out_line$ += "'sep$'Voiced(%)"
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

##
#  Procedure to report one pitch value
##

procedure ReportPitch p
	if (p <> undefined)
		fileappend 'result_file_name$' 'sep$''p:2'
	else
		fileappend 'result_file_name$' 'missing_value$'
	endif
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
	out_line$ = newline$
	out_line$ += "Script: pitch_'version'_'revision'_'bugfix'.praat'newline$'"
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
	if (i_request)
		out_line$ += "Minimal intensity: 'minimal_intensity' dB'newline$'"
	endif
	fileappend 'result_file_name$' 'out_line$'
endproc

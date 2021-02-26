##
#	This script computes the formants of all labeled
#	intervals of all wav-soundfiles in a directory.
#
#  	Version 1.0, Henning Reetz, 27-aug-2007
#  	Version 2.0, Henning Reetz, 10-may-2020	Adapted to Formants_4_0 format
#	There are no versions 3 or 4. I jump to 5 to synchronise the style with the other scripts
#	Version 5.0.0,	Henning Reetz, 22-feb-2021	included contours; new form interface
#
# Tested with Praat 6.1.38
#
##@@ To be done:
##@@ allow points
##@@ allow spaces in interval labels
##@@ add more than 1 tier in selecting and sorting
##

version = 5
revision = 0
bugfix = 0

# clear feedback window
clearinfo
# variable space$ in case we really need a space at the end of a line
space$ = " "

###
#	1) Inquire and check some parameters
#	(This form fits into screen with 640 pixel vertical resolution)
#	! Note that 'form' may only be used once in a script!
###

form Spectrum (Vers. 5.0) parameters:
		word Tier 4
	comment ______________________________________________________________________________________________________________
	comment <label>, <list>.txt, 'IPA', 'Kiel', 'Sampa', 'TIMIT', '.' (= only labelled), or empty (= all)
		sentence Label .
		real High_pass_filter_frequency 300
		real Upper_frequency 8000
	comment (i)ntensity, (c)enter of gravity, (h)igher modes, spectral (p)eak,
	comment (r)egression lines, (g)raph dump?
		sentence Interval_parameters c,p g
	comment ______________________________________________________________________________________________________________
	comment Nr. of measurements per interval (for a contour) 1: only center, 2: only edges
		word Number_of_measurements 0
	comment (t)ime points, (i)ntensity, (c)enter of gravity, (h)igher modes, spectral (p)eak,
	comment (g)raph dump?
		sentence Contour_parameters t c p g
	comment ______________________________________________________________________________________________________________
	choice Report_skipped_intervals: 2
		button All
		button Length, Intensity exclusion
		button None
endform


###
# 	2) Adjust the following settings as you prefer them (and/or add things from the form menu below)
###

# spectrogram computing parameters
window_length_ms = 5
window_length = window_length_ms / 1000.0
half_window_length = window_length / 2
step_rate_in_ms = 2
step_rate = step_rate_in_ms / 1000.0
frequency_step = 20

# regression lines presets
# there are two represession lines: low and high and
# both lines have a bottom and a top frequency in Hertz
slope_low_bottom = high_pass_filter_frequency
slope_low_top = 2500
slope_high_bottom = slope_low_top
## here is a problem: 'upper_frequency' = 0 means: use nyquist frequency of the file
## this frequency will be re-coded when a file is opened and set to 'highest_frequency'
slope_high_top = upper_frequency
# remove the first line of the spectra
remove_DC_offset = 1

# minimal length for an interval to be analysed in ms
minimal_length_ms = 25

# maximal length in seconds of a interval to be considered to be a analysed
max_length = 10.0

# minimal intensity for an interval to be analysed in dB
# '0' means 'no restrictions' just for convenience,
# although 0 dB does not mean no amplitude (that would be minus infinity)
# The intensity computation expects a low_pitch value, which is only used for that computation
minimal_intensity = 0
low_pitch = 75

# maximal number of intervals for reporting the contour
max_number_of_measurements = 20

# position reporting in steps (1, 2, 3,…) or percentage (0%, 25%…) of interval
position_in_percentage = 1

# can the analysis window at the edges of a interval cross the interval boundary (=1) or not (=0)
cross_interval_boundary = 0

## source of data (empty string = directory where the script was called from)
#	comment Leave the directory path empty if you want to use the current directory.
#		text Directory
directory$ = ""

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
graph_directory$ = directory$

# Examples (for being one directory above the 4 sub-directories):
# In case you want the path for the .wav file in the output, set 'path_name' to 1
#	wav_directory$ = "./Sound/"
#	grid_directory$ = "./Grid/"
#	result_directory$ = "./Result/"
#	support_directory$ = "./Support/"

# force a Graph directory
graph_directory$ = "./Graphs/"
createFolder: graph_directory$

# should the name of the diectory path be reported (path_name = 1) or not (path_name = 0)
path_name = 0

# extension of the audio files
sound_ext$ = ".wav"

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

# missing values symbole (e.g. "NA" for R or "." for JMP)
#	word Missing_value_symbol .
missing_value_symbol$ = "NA"

# should there be a pause after a drawing?
# (this can be changed in the pause window)
pause_drawing = 1

# should the drawing be saved to a file?
# (this can be changed in the pause window)
save_graph = 1

# graph scale (0,0 means automatic adjustment)
graph_low_db = 0
graph_high_db = 0

# Graph file format (pdf, png or eps)
if (macintosh)
	graph_file_format$ = "pdf"
else
	graph_file_format$ = "png"
endif

# graph text font size (just write one of the numbers 10, 12, 14, 18, 24 here)
10


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
nr_graph_dump_files = 0
nr_low_rate = 0

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
#		(mean intensity) (CoG) (higher modes) (peak) (regression lines) (graph dump)
#	Contour information (loop thru time points on lower level inside 'ReportContour'):
#		(time) (intensity) (CoG) (higher modes) (peak) (graph dump)
					if (l_flag and d_flag and i_flag)
						nr_measured_intervals += 1

# warn about very long intervals
						if (duration > max_length)
							if (!user_feedback)
								print 'newline$'File 'base_name$'
							endif
							printline – has an interval longer than 'max_length' seconds.
						endif

						call PrepareOutputLine

# report intensity is requested or needed
						if (ii_request)
							if (!intensity_mean)
								call SelectObject intensity_obj
								intensity_mean = Get mean: t_left, t_right, "energy"
							endif
							call ReportValue intensity_mean 2
						endif

## CoG, peak, regression lines or graph requested -> spectrum needed
						if (icog_request or ip_request or ir_request or ig_request)
							call SelectObject wav_obj
							part_obj = Extract part: t_left, t_right, "rectangular", 1, "yes"
							spectrum_obj = 'np_string$' To Spectrum: "yes"

							if (icog_request)
								cog = Get centre of gravity: 2
								call ReportValue cog 1
							endif
							if (ih_request)
								stdev = Get standard deviation: 2
								skew = Get skewness: 2
								kurt = Get kurtosis: 2
								call ReportValue stdev 2
								call ReportValue skew 2
								call ReportValue kurt 2
							endif
							if (ip_request)
								ltas_obj = To Ltas (1-to-1)
								peak_freq = Get frequency of maximum: 0, 0, "none"
								call ReportValue peak_freq 1
								removeObject: ltas_obj
							endif
							if (ir_request)
								call ComputeSlopes
							endif

# skip graph if neither pausing nor saving is requested
							if (ig_request)
								call DrawSpectrum i
							endif

							removeObject: part_obj, spectrum_obj
						endif

###
# report contour data
###

# report times, intensity and pitch at measurement point only once (if requested at all)
						if (number_of_measurements)

# indicate that no spectrum data has been computed yet (used inside 'ReportContour')
							no_spectrum_data = 1

# report time data
							if (ct_request)
								call ReportContour t
							endif

# report intensity data
							if (ci_request)
								call ReportContour i
							endif

# report CoG data
							if (ccog_request)
								call ReportContour cog
							endif

# report higher modes data (StDev, skewness, kurtosis)?

							if (ch_request)
								call ReportContour stdev
								call ReportContour skew
								call ReportContour kurt
							endif

# report spectral peaks?
							if (cp_request)
								call ReportContour p
							endif

# report regression lines data (low slope, high slope)?
							if (cr_request)
								call ReportContour sl
								call ReportContour sk
							endif

# all computations done for one interval
						endif
						fileappend 'result_file_name$' 'out_line$''newline$'

# label, duration, or intensity requirements of the interval are not met
# report interval with missing info depending on 'report_skipped_intervals' and 'l_flag'
# either all, or only if label$ is okay or none
					elsif (report_skipped_intervals = 1) or ((report_skipped_intervals = 2) and l_flag)
						call PrepareOutputLine
						if (ii_request)
							out_line$ += "'sep$''intensity_mean:01'"
						endif
						out_line$ += "'skip_line$'"
						fileappend 'result_file_name$' 'out_line$''newline$'

# label, duration and intensity test
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
			print 'base_name$''space$'
		endif
		printline has no TextGrid. File skipped. ***
	endif

# clean up
	call RemoveObjects

# going thru all sound files
endfor

# clean up (do not use 'remove all' because the user might have some objects hanging around
removeObject: wav_list_obj
if (label_flag = label_list)
	removeObject: label_list_obj
elsif (label_flag > 10)
	removeObject: fricative_obj
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
if (nr_graph_dump_files)
	printline 'nr_graph_dump_files' graph files created in 'graph_directory$'.
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

# check whether anything is selected at all
	if ((interval_parameters$ = "") and (number_of_measurements <= 0))
		printline Neither interval parameters nor contour data is requested: no data computed.
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
		if (whole_file)
			printline No TextGrids found. Only whole file measures will be reported.
		endif
		removeObject: grid_list_obj
	endif

# which interval parameters are required?
# preset (i)ntesity, (p)itch, (m)eans and quantiles to 'not requested' (= 0)
# force report of intensity if minimal intensity request must be met
##	(c)og, (h)igher modes, (i)ntensity, spectral (p)eak, (s)lopes, (g)raph dump,
	icog_request = 0
	ig_request = 0
	ih_request = 0
	ii_request = 0
	ip_request = 0
	ir_request = 0

	if (minimal_intensity)
		ii_request = 1
	endif

# check interval_parameters field (convert to lower case and change spaces to commas first)
	interval_parameters$ = replace_regex$ (interval_parameters$, ".", "\L&", 0)
	interval_parameters$= replace_regex$ (interval_parameters$, " ", ",", 0)
	item_obj = Create Strings as tokens: interval_parameters$, " ,"
	nr_items = Get number of strings

# go thru requested measures
# (if no inerval parameters are selected, this loop will be skipped since nr_items will be 0)
	for i_item to nr_items
		selectObject: item_obj
		item$ = Get string: i_item

# CoG requested?
		if (item$ = "c")
			icog_request = 1

# graph dump requested?
		elsif (item$ = "g")
			ig_request = 1

# higher modes requested?
		elsif (item$ = "h")
			ih_request = 1

# intensity requested?
		elsif (item$ = "i")
			ii_request = 1

# spectral peak requested?
		elsif (item$ = "p")
			ip_request = 1

# regression line data requested?
		elsif (item$ = "r")
			ir_request = 1
# check for right sequence of slope boundaries and whether there is only one slope requested
			if (slope_low_bottom > slope_low_top)
				printline Lower slope boundary ('slope_low_bottom' Hz) is above upper boundary ('slope_low_top' Hz).
				printline Please correct boundaries.
				exit
			endif
## 'slope_high_top' can be '0' when the nyquist frequency of the file should be used
## re-coding will take place when the file is openend
			if (slope_high_top and (slope_high_bottom > slope_high_top))
				printline Upper slope boundary ('slope_high_top' Hz) is below lower boundary ('slope_high_bottom' Hz).
				printline Please correct boundaries.
				exit
			endif
			if (slope_low_bottom = slope_low_top) and (slope_high_bottom = slope_high_top)
				printline Both, low and high slope boundaries have the same values.
				printline Please correct boundaries.
				exit
			endif
			if (slope_low_bottom = slope_low_top)
				slope_low_bottom = slope_high_bottom
				only_one_slope = 1
			elsif (slope_high_bottom = slope_high_top)
				slope_high_bottom = slope_low_bottom
				slope_high_top = slope_low_top
				only_one_slope = 1
			else
				only_one_slope = 0
			endif

# illegal parameter?
		else
			printline Illegal parameter in Interval parameters: "'item$'". Computation aborted."
			exit
		endif
	endfor
	removeObject: item_obj


# check contour parameters
# preset requests to 'not requested' (= 0)
	ccog_request = 0
	cg_request = 0
	ch_request = 0
	ci_request = 0
	cp_request = 0
	cr_request = 0
	ct_request = 0

# check parameters only of contour data is requeired
	if (number_of_measurements)

# convert to lower case and convert spaces to commas first
		contour_parameters$ = replace_regex$ (contour_parameters$, ".", "\L&", 0)
		contour_parameters$ = replace_regex$ (contour_parameters$, " ", ",", 0)
		item_obj = Create Strings as tokens: contour_parameters$, " ,"

# go thru requested formant contour measures
# (using a method like ci_request = (item$ = "i") would miss wrong inputs!)
		nr_items = Get number of strings
		for i_item to nr_items
			selectObject: item_obj
			item$ = Get string: i_item

# CoG requested?
			if (item$ = "c")
				ccog_request = 1

# graph dump requested?
			elsif (item$ = "g")
				if (number_of_measurements > 3)
					pause Do you want 'number_of_measurements' graph dumps for every selected interval?
				endif
				cg_request = 1

# higher modes requested?
			elsif (item$ = "h")
				ch_request = 1

# intensity requested?
			elsif (item$ = "i")
				ci_request = 1

# spectral peak requested?
			elsif (item$ = "p")
				cp_request = 1

# regression line data requested?
			elsif (item$ = "r")
				cr_request = 1

# time points requested?
			elsif (item$ = "t")
				ct_request = 1

# illegal parameter?
			else
				printline Illegal parameter in Contour parameters: "'item$'". Computation aborted."
				exit
			endif
		endfor
		removeObject: item_obj

# contour data required?
	endif

### check which intervals are to be analyzed; set constants first:
# <nil> => all
	label_none = 0

# . => only labeled intervals
	label_any = 1

# label.txt or label(s)
	label_list = 2

# IPA fricative
	label_ipa = 11

# Kiel fricative
	label_kiel = 12

# SAMPA fricative
	label_sampa = 13

# TIMIT fricative
	label_timit = 14

### now recode the request
# lower case string is sometimes needed
	lc_label$ = replace_regex$ (label$, ".", "\L&", 0)

# report all intervals
	if (label$ = "")
		label_flag = label_none

# report only labelled intervals
	elsif (label$ = ".")
		label_flag = label_any

# report vowels (prepare WordLists)
	elsif ((lc_label$ = "ipa") or (lc_label$ = "kiel") or (lc_label$ = "sampa") or (lc_label$ = "timit"))
		if (lc_label$ = "ipa")
			help$ = "ɸ,β,f,v,θ,ð,s,z,ʃ,ʒ,ʂ,ʐ.ç,ʝ,x,ɣ,χ,ʁ,h,ɦ,ʕ"
			label_flag = label_ipa
		elsif (lc_label$ = "kiel")
			help$ = "C,S,Z,f,h,s,v,x,z"
			label_flag = label_kiel
		elsif (lc_label$ = "sampa")
			help$ = "D,S,T,Z,f,h,j,s,v,z"
			label_flag = label_sampa
		elsif (lc_label$ = "timit")
			help$ = "ch,jh,s,sh,z,zh,f,v,th,dh,hh,hv"
			label_flag = label_timit
		else
			printline Impossible lc_label$: 'lc_label$'. Scripte aborted.
			exit
		endif
		help_obj = Create Strings as tokens: "'help$'", " ,"
		fricative_obj = To WordList
		removeObject: help_obj

# report labels from a label file
	elsif (endsWith(lc_label$,".txt"))
		label$ = support_directory$+label$
		if (not fileReadable (label$))
			printline Label file 'label$' not found. Script aborted.
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
##@@ change this to allow spaces in label sortings
		label$ = replace_regex$ (label$, " ", ",", 0)
		label$ = replace_regex$ (label$, ",,", ",", 0)
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

# too many contour measuremnts?
	if (number_of_measurements > max_number_of_measurements)
		pause Do you really want 'number_of_measurements' measurements per interval?
	endif
endproc



#########################################################################################
#
#	Procedure to create resultfile
#
#	Report in the data file the sequence (see (7) in main script:
#	Location:
#		(path) file label start duration
#	Interval information:
#		(mean intensity) (CoG) (higher modes) (speactral peaks) (regression lines)
#	Contour information (loop thru time points on lower level inside 'ReportContour'):
#		(time) (intensity) (CoG) (higher modes) (speactral peaks)
#	(Graph dump files are generated inside DrawSpectrum)
#
#########################################################################################

procedure CreateResultFile

# string for missing values in output
	missing_value$ = "'sep$''missing_value_symbol$'"

# create file name with date and time
	call GetDate date_time$
	result_file_name$ = result_directory$+"spectrum_results_"+date_time$+".txt"

# create header, dummy and missing data lines (first part is always there, so no missing data needed)
	out_line$ = ""
	dummy_line$ = ""
	if (path_name)
		out_line$ += "Path'sep$'"
		dummy_line$ += "Dummy'sep$'"
	endif
	out_line$ += "File'sep$'Label'sep$'Start(s)"
	if (duration_in_ms)
		out_line$ += "'sep$'Duration(ms)"
	else
		out_line$ += "'sep$'Duration(s)"
	endif
	dummy_line$ += "Dummy'sep$'Dummy'sep$'0.0'sep$'0.0"
	remove_from_dummy$ = dummy_line$

# report intensity data for interval if requested
	if (ii_request)
		out_line$ += "'sep$'Intensity_mean(dB)"
		dummy_line$ += "'sep$'0.0"
	endif

# report center of gravity for interval if requested
	if (icog_request)
		out_line$ += "'sep$'CoG(Hz)"
		dummy_line$ += "'sep$'0.0"
	endif

# report higher modes for interval if requested
	if (ih_request)
		out_line$ += "'sep$'StDev(Hz)'sep$'Skewness'sep$'Kurtosis"
		dummy_line$ += "'sep$'0.0'sep$'0.0'sep$'0.0"
	endif

# report spectral peak for interval if requested
	if (ip_request)
		out_line$ += "'sep$'Peak(Hz)"
		dummy_line$ += "'sep$'0.0"
	endif

# report spectral regression lines for interval if requested
	if (ir_request)
		if (only_one_slope)
			out_line$ += "'sep$'intercept(dB)'sep$'slope(dB/kHz)"
			dummy_line$ += "'sep$'0.0'sep$'0.0"
		else
			out_line$ += "'sep$'low intercept(dB)'sep$'low slope(dB/kHz)'sep$'high intercept(dB)'sep$'high slope(dB/kHz)"
			dummy_line$ += "'sep$'0.0'sep$'0.0'sep$'0.0'sep$'0.0"
		endif
	endif

# contour required (i.e. number_of_measurements <> 0)?
	if (number_of_measurements)

# time point requested?
		if (ct_request)
			call ContourHeader t
		endif

# intensity requested?
		if (ci_request)
			call ContourHeader i
		endif

# CoG requested?
		if (ccog_request)
			call ContourHeader cog
		endif

# higher modes requested (StDev, skewness, kurtosis)?
		if (ch_request)
			call ContourHeader stdev
			call ContourHeader skew
			call ContourHeader kurt
		endif

# spectral peaks requested?
		if (cp_request)
			call ContourHeader p
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

procedure ContourHeader xch$

	p1$ = "left"
	p2$ = "center"
	p3$ = "right"

# any time point measurement other than center (= 1)?
	if (number_of_measurements <> 1)
		perc_step = 100.0 / (number_of_measurements-1)
	endif

# adjust unit for report
	if (xch$ = "cog")
		pos_unit$ = "(Hz)"
	elsif (xch$ = "stdev")
		pos_unit$ = "(Hz)"
	elsif (xch$ = "skew")
		pos_unit_2$ = "(skew)"
	elsif (xch$ = "kurt")
		pos_unit_3$ = "(kurt)"
	elsif (xch$ = "i")
		pos_unit$ = "(dB)"
	elsif (xch$ = "p")
		pos_unit$ = "(Hz)"
	elsif (xch$ = "sl")
		pos_unit$ = "(dB/Hz)"
	elsif (xch$ = "sh")
		pos_unit$ = "(dB/Hz)"
	elsif (xch$ = "t")
		pos_unit$ = "(s)"
	else
		printline Illegal parameter for procedure ContourHeader: "'xch$'". Computation aborted."
		exit
	endif

# next loop is only entered if a contour measurements is requested
	for i_pos to number_of_measurements

# special handling if only 3 or less required
		if (number_of_measurements = 1)
			p$ = p2$
			position$ = "'xch$'_'p$'"
		elsif (number_of_measurements = 2)
			if (i_pos = 1)
				p$ = p1$
			else
				p$ = p3$
			endif
			position$ = "'xch$'_'p$'"
		elsif (number_of_measurements = 3)
			p$ = p'i_pos'$
			position$ = "'xch$'_'p$'"
		elsif (position_in_percentage)
			perc = (i_pos-1) * perc_step
			position$ = "'xch$'_t'perc:2'%"
		else
			position$ = "'xch$'_t'i_pos'"
		endif

		out_line$ += "'sep$''position$''pos_unit$'"
		dummy_line$ += "'sep$'0.0"
	endfor
endproc


#########################################################################################
#
#	Procedure to compute the slopes of a spectrum
#@@ what does trendline do??
#
#########################################################################################

procedure ComputeSlopes

# convert data into tables format to be able to work on the numbers
# actually, make two tables, one for 'low' and one for 'high'
	selectObject: spectrum_obj
	high_obj = Tabulate: "no", "yes", "no", "no", "no", "yes"
	if (remove_DC_offset)
		Remove row: 1
	endif

# First remove data that is neither needed by the low or high slope form the high_obj
	call TrimTable slope_low_bottom slope_high_top

# Copy this data for the 'low' table (unless there is only one slope requested)
# and remove the higher frequencies
	if (!only_one_slope)
		low_obj = Copy: "low"
		call TrimTable slope_low_bottom slope_low_top
		reg_obj = To linear regression
		info$ = Info
		low_intercept = extractNumber (info$, "Intercept: ")
		low_slope_hz = extractNumber (info$, "Coefficient of factor freq(Hz): ")
		low_slope_khz = low_slope_hz * 1000
		call ReportValue low_intercept 2
		call ReportValue low_slope_khz 4
		removeObject: reg_obj
	endif

# Now remove the lower frequencies from the high table (no pun intended)
	selectObject: high_obj
	call TrimTable slope_high_bottom slope_high_top

# compute the linear regression from the 'high' table
# Thanks to Paul Boersma for this solution
	reg_obj = To linear regression
	info$ = Info
	high_intercept = extractNumber (info$, "Intercept: ")
	high_slope_hz = extractNumber (info$, "Coefficient of factor freq(Hz): ")
	high_slope_khz = high_slope_hz * 1000
	call ReportValue high_intercept 2
	call ReportValue high_slope_khz 4
	removeObject: reg_obj

# clean up after handling this spectrum
	removeObject: high_obj
	removeObject: low_obj
endproc


#########################################################################################
#
#	Procedue to remove lines from a spectrum's table outside 'low' and 'high' frequency boundaries
#
#########################################################################################

procedure TrimTable low high

# We first remove all rows below the boundary given by 'low'
# Note that we do not change the row number for the 'high' table, because after deleting
#	the first row, the next row becomes the first row! (i.e. the row number remains '1').
# Note that the first row will always be deleted in the upcoming 'repeat' loop in the 'high' table
			freq = Get value: 1, "freq(Hz)"
			while (freq < low)
				Remove row: 1
				freq = Get value: 1, "freq(Hz)"
			endwhile

# now erase the top rows until we reach the 'high' boundary
			nr_rows = Get number of rows
			freq = Get value: nr_rows, "freq(Hz)"
			while (freq > high)
				Remove row: nr_rows
# With every removing of the top row, we have to decrease 'nr_rows'!
				nr_rows -= 1
				freq = Get value: nr_rows, "freq(Hz)"
			endwhile

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
		elsif (obj$ = "spectrogram_obj")
			spectrogram_obj = 'np_string$' To Spectrogram: window_length, highest_frequency, step_rate, 20, "Gaussian"
		elsif (obj$ = "wav_obj")
		else
			printline Illegal object in procedure SelectObject: 'obj$'. Program aborted.
			exit
		endif
	endif
endproc


#########################################################################################
#
#	Procedue to Draw the spectrum with CoG and regression lines and handle graph dumping.
#
#########################################################################################

procedure DrawSpectrum xds$

# Draw graph first, then add headers
	selectObject: spectrum_obj
	Erase all
	Black

# Draw the spectrum of this interval
	Draw: 0, 'highest_frequency', 'graph_low_db', 'graph_high_db', "yes"

# Draw CoG line
	if ('xds$'cog_request)
		info$ = Picture info
		on_x = cog
		on_y = extractNumber (info$, "Axis top: ")
		off_x = cog
		off_y = extractNumber (info$, "Axis bottom: ")
		Cyan
		Line width: 2
		Draw line: on_x, on_y, off_x, off_y
		Line width: 1
	endif

	if ('xds$'r_request)
# Draw high regression line
		Red
		on_x = slope_high_bottom
		on_y = high_intercept + slope_high_bottom * high_slope_hz
		off_x = slope_high_top
		off_y = high_intercept + slope_high_top * high_slope_hz
		Draw line: on_x, on_y, off_x, off_y

# Draw low regression line
		if (!only_one_slope)
			Blue
			on_x = slope_low_bottom
			on_y = low_intercept + slope_low_bottom * low_slope_hz
			off_x = slope_low_top
			off_y = low_intercept + slope_low_top * low_slope_hz
			Draw line: on_x, on_y, off_x, off_y
		endif

# Write graph header (compress data since regression lines takes 2nd line)
		if ('xds$'p_request)
			graph_header$ += " pk: 'peak_freq:0'"
		endif
		if ('xds$'cog_request)
			graph_header$ += " C: 'cog:0'"
		endif
		if ('xds$'h_request)
			graph_header$ += " SD: 'stdev:0' sk: 'skew:1' k: 'kurt:1'"
		endif
		Text top: "yes", "'graph_header$'"
		if (only_one_slope)
			Text top: "no", "slope: 'high_intercept:02' + f * 'high_slope_khz:04' dB/kHz"
		else
			Text top: "no", "low: 'low_intercept:02' + f * 'low_slope_khz:04', high: 'high_intercept:02' + f * 'high_slope_khz:04' dB/kHz"
		endif

# Header without regression line data
	else
		Text top: "yes", "'graph_header$'"
		graph_header$ = ""
		if ('xds$'p_request)
			graph_header$ += " peak: 'peak_freq:0' Hz"
		endif
		if ('xds$'cog_request)
			graph_header$ += " CoG: 'cog:0' Hz"
		endif
		if ('xds$'h_request)
			graph_header$ += " SD: 'stdev:0' Hz, skew: 'skew:1', kurtosis: 'kurt:1'"
		endif
		Text top: "no", "'graph_header$'"
	endif

# interact with user to find out how to proceed
	if (pause_drawing)
		beginPause: "'graph_header$'"
			choice: "Save graph", save_graph
				option: "This (and all following)"
				option: "This not (and none of the following)"
		pause_selection = endPause: "Stop", "Next", "No more pauses", 2, 1
	endif

# save graph (or not)
	if (save_graph = 1)
		graph_file_name$ = graph_directory$+graph_file_name$+"_"+date_time$
		if (graph_file_format$ = "pdf")
			Save as PDF file: "'graph_file_name$'.pdf"
		elsif (graph_file_format$ = "png")
			Save as 600-dpi PNG file: "'graph_file_name$'.png"
		elseif (graph_file_format$ = "eps")
			Save as EPS file: "'graph_file_name$'.eps"
		else
			printline Illegals output format 'graph_file_format$' for graph file. Processing aborted.
			exit
		endif
		nr_graph_dump_files += 1
	endif

# proceed according to reaction to pause
	if (pause_selection = 1)
		printline Scripted aborted by user.
## do NOT remove objects in case user wants to inspect them
		exit
	elsif (pause_selection = 3)
		pause_drawing = 0
	endif

# switch off spectrum drawing if neither pauses are requested nor graphs should be saved
	if (!pause_drawing and !save_graph)
		ig_request = 0
		cg_request = 0
	endif

endproc


#########################################################################################
#
#	Procedure to test whether a interval's label is an IPA, Kiel, Sampa or TIMIT fricative
#
#########################################################################################

procedure IsFricative interval_label$$ l_flag

# test for IPA vowels
	if (label_flag = label_ipa)
# remove additional marks (diacritics, stress marks)
		local_label$ = replace_regex$ (interval_label$, "[:ː]", "", 0)

# test for Kiel vowels
	elsif (label_flag = label_kiel)
		local_label$ = interval_label$

# test for SAMPA vowels (no lower/upper case conversion, because SAMPA uses lower and uper case for different phoneme)
	elsif (label_flag = label_sampa)
# remove additional marks (diacritics, stress marks)
		local_label$ = replace_regex$ (interval_label$, ":", "", 0)

# test for TIMIT vowels
	elsif (label_flag = label_timit)
# convert to lower case (same us lower case, some upper case)
		local_label$ = replace_regex$ (interval_label$, ".", "\L&", 0)

# this should not happen
	else
		printline Impossible label_flag in IsFricative: 'label_flag'. Script aborted.
		exit
	endif

	selectObject: fricative_obj
	l_flag = Has word: local_label$
endproc


#########################################################################################
#
#	Procedure to open sound- and TextGrid file
#	(or generate dummy TextGrid if whole files should be analysed)
#
#########################################################################################

procedure OpenFiles
	wav_obj = 0
	grid_obj = 0
	intensity_obj = 0
	spectrogram_obj = 0

	selectObject: wav_list_obj
	wav_name$ = Get string: i_file
# Do not use "selected$("Sound")" go get the sound file name, because PRAAT converts
# many symbols (like a tilde "~") into an underline ("_")
	base_name$ = replace_regex$(wav_name$,"'sound_ext$'$","",1)

	if (user_feedback)
		print Handling 'base_name$''space$'
	endif

# resample if necessary
	call SelectObject wav_obj
	rate = Get sampling frequency
	nyquist = rate / 2
	if (upper_frequency = 0)
		highest_frequency = nyquist
	else
		highest_frequency = upper_frequency
	endif
# if highest slope frequency is '0', re-code it here
	if (slope_high_top = 0)
		slope_high_top = highest_frequency
	endif
	if (nyquist > highest_frequency)
## resampling is actually only needed when spectral interval parameters are needed
## otherwise, 'To Spectrogram' does the trick
## but values can differ with/out resampling, so I resample always here
#		if (interval_parameters$ <> "")
			new_rate = highest_frequency * 2
			if (new_rate <> rate)
				help_obj = Resample: new_rate, 50
				removeObject: wav_obj
				wav_obj = help_obj
			endif
#		endif
	elsif (nyquist < highest_frequency)
		nr_low_rate += 1
		if (!user_feedback)
			print 'newline$''base_name$''space$'
		endif
		printline has a sampling rate of 'rate' Hz (Nyquist: 'nyquist' Hz) ***
	endif

# filter, if required
	if (high_pass_filter_frequency)
		call SelectObject wav_obj
		help_obj = Filter (stop Hann band): 0, high_pass_filter_frequency, 100
		removeObject: wav_obj
		wav_obj = help_obj
	endif

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
#	Procedure to report contour values
#
#########################################################################################

procedure ReportContour xrc$

# Go thru measurements for a contour (special handling for '1' (center), '2' (edges', '3' (edges and center)
	if (number_of_measurements)

# Get values of time points; use 'mid' as guiding time
		if (number_of_measurements = 1)
			dur_step = (t_right - t_left)
			mid = (t_right + t_left) / 2

# compute positions
		else
			dur_step = (t_right - t_left) / (number_of_measurements-1)
## bad nameing: mid is the left edge!!
			mid = t_left
		endif

# compute spectrum at time points only once and store values that will be needed later,
# but provide also a variable without index for an eventual graph dump
# (i.e., we need e.g. "cog" and 'cog'ipos'")
# Note that the loop here will change the position of 'mid', so it has to be saved and reset!
# (Use the global cX_request because the spectrum and all data is computed once only!)
		if (no_spectrum_data and (ccog_request or ch_request or cp_request or cg_request))
			save_mid = mid
			for i_pos to number_of_measurements
				call SelectObject spectrogram_obj
				spectrum_obj = To Spectrum (slice): mid
				if (ccog_request)
					cog'i_pos' = Get centre of gravity: 2
#help = cog'i_pos'
#printline 'i_pos' 'help'
					cog = cog'i_pos'
				endif
# store higher modes if requested to avoid re-computation
				if (ch_request)
					stdev'i_pos' = Get standard deviation: 2
					skew'i_pos' = Get skewness: 2
					kurt'i_pos' = Get kurtosis: 2
					stdev = stdev'i_pos'
					skew = skew'i_pos'
					kurt = kurt'i_pos'
				endif
				if (cp_request)
					'np_string$' To Ltas (1-to-1)
					peak_freq'i_pos' = Get frequency of maximum: 0, 0, "None"
					peak_freq = peak_freq'i_pos'
		 			Remove
				endif

# Do the graph now while the spectra are there and add the requested data
				if (cg_request)
					graph_header$ = ""
					if (path_name)
						graph_header$ += "'wav_directory$''sep$'"
					endif
					help$ = "'mid:04'"
					help$ = replace_regex$ (help$, "\.", "s", 0)
					graph_file_name$ = graph_header$ + "'base_name$'_'interval_label$'_'help$'_'i_pos'"
					graph_header$ += "'base_name$' ['interval_label$']('i_pos') at 'mid:04'"
					call DrawSpectrum c
				endif
				removeObject: spectrum_obj
				mid += dur_step
			endfor
# indicate data has been computed
			no_spectrum_data = 0
			mid = save_mid
		endif

# report times of measurement
		if (xrc$ = "t")
			for i_pos to number_of_measurements
				call ReportValue mid 4
				mid += dur_step
			endfor

# report imtensity
		elsif (xrc$ = "i")
			call SelectObject intensity_obj
			for i_pos to number_of_measurements
				intensity = Get value at time: mid, "cubic"
				call ReportValue intensity 2
				mid += dur_step
			endfor

# report center of gravity (data is already stored)
		elsif (xrc$ = "cog")
			for i_pos to number_of_measurements
				call ReportValue cog'i_pos' 1
			endfor

# report standard deviation (data is already stored)
		elsif (xrc$ = "stdev")
			for i_pos to number_of_measurements
				call ReportValue stdev'i_pos' 2
			endfor

# report skewness (data is already stored)
		elsif (xrc$ = "skew")
			for i_pos to number_of_measurements
				call ReportValue skew'i_pos' 2
			endfor

# report kurtosis (data is already stored)
		elsif (xrc$ = "kurt")
			for i_pos to number_of_measurements
				call ReportValue kurt'i_pos' 2
			endfor

# report spectral peak  (data is already stored)
		elsif (xrc$ = "p")
			for i_pos to number_of_measurements
				call ReportValue peak_freq'i_pos' 1
			endfor

# this should not happen
		else
			printline Unexpected ReportContour parameter: 'xrc$'. Script aborted.
			exit
		endif

# contour measurement required?
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

# generate graph dump file name and header for interval data
	if (ig_request)
		graph_header$ = ""
		graph_file_name$ = ""
		if (path_name)
			graph_header$ += "'wav_directory$' "
			graph_file_name$ += "'wav_directory$'_"
		endif
		graph_header$ += "'base_name$' ['interval_label$'] at 't_start:02'"
# substitute the decinal point in the tine with 's' for 'second'
		help$ = "'t_start:04'"
		help$ = replace_regex$ (help$, "\.", "s", 0)
# add a "_0" at the end to force interval files ahead of contour files in directory listings
		graph_file_name$ += "'base_name$'_'interval_label$'_'help$'_0"
		if (duration_in_ms)
			graph_header$ += " d: 'duration_ms:0'"
		else
			graph_header$ += " d: 'duration:03'"
		endif
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

# report all vowels
	elsif (label_flag > 10)
		call IsFricative interval_label$ l_flag

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
	if (spectrogram_obj)
		removeObject: spectrogram_obj
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
	out_line$ += "Script: Spectrum_'version'_'revision'_'bugfix'.praat'newline$'"
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
	out_line$ += "High pass filter frequency: 'high_pass_filter_frequency' Hz'newline$'"
	out_line$ += "Highest frequency: 'highest_frequency' Hz'newline$'"
	out_line$ += "Minimal length: 'minimal_length_ms' ms'newline$'"
	out_line$ += "Minimal intensity: 'minimal_intensity' dB'newline$'"
	if (ii_request or ci_request)
		out_line$ += "Low pitch for intensity computation: 'low_pitch' Hz'newline$'"
	endif
	if (ir_request or cr_request)
		out_line$ += "Low slope boundarys: 'slope_low_bottom' – 'slope_low_top' Hz'newline$'"
		out_line$ += "High slope boundarys: 'slope_high_bottom' – 'slope_high_top' Hz'newline$'"
	endif
	out_line$ += "Step rate: 'step_rate_in_ms' ms'newline$'"
	out_line$ += "Window size: 'window_length_ms' ms'newline$'"
	fileappend 'result_file_name$' 'out_line$'
endproc

##
#	This script opens all sound files in a directory and associated TextGrids (if they exist),
#	computes the mean formant frequencies, bandwiths and amplitudes of intervalls
#	(or the whole file) that have a name and writes the results together with the durations
#	of these intervals/files into a text file.
#
# **> Please read 'formants_manual.pdf' for a full description of this rather complex script.
# **> Please feel free to use and modify this script to your needs.
# **> But please report errors or give suggestions for improvements to <reetz.phonetics@gmail.com>
#
#  	Vers. 0.0, Henning Reetz, 27-aug-2007
#	Vers. 1.1, Henning Reetz, 16-jun-2009; no computation of Formants if
#				interval is shorter than a given size or label of interval is a dot ('.') only;
#				center of left and right edge-positions are shifted by half window size to have the analysis inside the interval
#  	Vers. 2.0, Henning Reetz, 24-mar-2019	more parameters, pitch and intensity reported
#  	Vers. 3.0, Henning Reetz, 05-apr-2020	general revision; adaptations taken from Formant_contour.praat
#  	Vers. 4.0, Henning Reetz, 16-apr-2020	more adaptations and version number should be now in parallel
#  	Vers. 4.1, Henning Reetz, 30-apr-2020	tested with separate directories for wav and TextGrid etc.
#  	Vers. 4.2, Henning Reetz, 12-may-2020	removed bug with label_list_obj handling, some clean up
#	Vers. 5.0.0, Henning Reetz, 14-dec-2020	included contours; new form interface
#
# Tested with Praat 6.1.33
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

form Formant (Vers. 5.0) parameters:
		word Tier 1
		integer Compute_formants 5
		integer Report_formants 3
		real Highest_frequency 5000.0
	comment <label>, <list>.txt, 'IPA', 'Kiel', 'Sampa', 'TIMIT', '.' (= only labelled), or empty (= all)
		sentence Label TIMIT
		boolean Pitch_must_exist 0
	comment (i)ntensity, (p)itch, (m)ean, <list of quantiles in %> of intervals
		sentence Interval_parameters p,m,0,50
	comment Nr. of measurements per interval (for a contour) 1: only center, 2: only edges
		word Number_of_measurements 3
	comment (t)ime of measurement, (i)ntensity, (p)itch, (b)andwidth, (q)uality, (a)mplitude,
	comment additionally mean (s)ubtraction, (z)-scores for formants?
		sentence Contour_parameters t,b
	comment ______________________________________________________________________________________________________________
	choice Report_skipped_intervals: 2
		button All
		button Length, Intensity, Pitch exclusion
		button None
endform


###
# 	2) Adjust the following settings as you prefer them (and/or add things from the form menu below)
###

# Units for formant data
unit$ = "hertz"

# formant computation parameters
#		real Step_rate_in_ms 5
step_rate_in_ms = 5
step_rate = step_rate_in_ms / 1000
pre_emphasis = 50.0
window_length_ms = 25.6
window_length = window_length_ms / 1000.0

# minimal length for an interval to be analysed in ms
#		real Minimal_length_ms 25
minimal_length_ms = 25

# maximal length in seconds of a interval to be considered to be a analysed
max_length = 1.0

# minimal intensity for an interval to be analysed in dB
# '0' means 'no restrictions' just for convenience,
# although 0 dB does not mean no amplitude (that would be minus infinity)
#		real Minimal_intensity 40
minimal_intensity = 0

# position reporting in steps (1, 2, 3,…) or percentage (0%, 25%…) of interval
position_in_percentage = 1

# maximal number of intervals for reporting the contour
max_number_of_measurements = 20

# pitch computation parameters
#		real Low_pitch 75
#		real High_pitch 600
low_pitch = 75
high_pitch = 600

# can the analysis window at the edges of a interval cross the interval boundary (=1) or not (=0)
cross_interval_boundary = 1

# half window length will be used if no interval boundaries should be crossed
half_window_length = window_length / 2.0

# use an arbitrary reference to shift amplitude-values of formants in a reasonable range
# it would be 92 dB for a full 16-bit resolution, but usually the signal is about 12 dB lower
arbitrary_db = 80

# source of data (empty string = directory where the script was called from)
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
#	word sound_ext .wav
sound_ext$ = ".wav"

# separator for output list (e.g. = "," for csv files)
sep$ = tab$

# should there be user feedback (= 1) or none to speed up processing  (= 0)
#	boolean User_feedback 1
user_feedback = 1

# should there be no processing information from Praat (= "noprogress") or not (= ""  ; i.e. empty string)
np_string$ = "noprogress"

# should there be a dummy data header to force correct data type in JMP or other tables (= 1) or not (= 0)
#	boolean Dummy_data_header 0
dummy_data_header = 0

# report duration in ms (duration_in_ms = 1) or seconds (duration_in_ms = 0)
duration_in_ms = 1

# missing values symbole (e.g. "NA" for R or "." for JMP)
#	word Missing_value_symbol .
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
	formant_obj = 0
	intensity_obj = 0
	pitch_obj = 0
	lpc_obj = 0
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

#
# check whether this interval should be reported
#

### check for pitch if label is okay and pitch must exist
					if (l_flag and pitch_must_exist)
						call SelectObject pitch_obj
						pitch_mean = Get mean: t_left, t_right, "hertz"
						p_flag = (pitch_mean <> undefined)
# essentially ignore pitch
					else
						pitch_mean = 0
						p_flag = 1
					endif

###
#	7) check whether all conditions are met; if so, start reporting data
#
#	Report in the sequence:
#	Location:
#		(path) file label start duration
#	Interval information:
#		(mean intensity) (mean pitch)
#		for report_formants:
#			(mean formant) (stdev formant) (quantiles)
#		endfor
#	Contour information (loop thru time points on lower level inside 'ReportContour'):
#		(time) (intensity) (pitch)
#		for report_formants (and inside each formant: loop thru time points 'ReportContour'):
#			formant (bandwidth) (quality) (amplitude) (mean subtraction) (z-score)
#		endfor
###
					if (l_flag and d_flag and p_flag and i_flag)
						nr_measured_intervals += 1

# warn about very long intervals
						if (duration > max_length)
							if (!user_feedback)
								print 'newline$'File 'base_name$'
							endif
							printline – has a interval longer than 'max_length' seconds.
						endif

						call PrepareOutputLine
						call SelectObject formant_obj

# report intensity is requested or needed
						if (ii_request)
							if (!intensity_mean)
								call SelectObject intensity_obj
								intensity_mean = Get mean: t_left, t_right, "energy"
							endif
							call ReportValue intensity_mean 2
						endif

# report pitch if requested or needed
						if (ip_request)
							if (!pitch_mean)
								call SelectObject pitch_obj
								pitch_mean = Get mean: t_left, t_right, "Hertz"
							endif
							call ReportValue pitch_mean 2
						endif

###
# report mean and quantile formant data
###

# Get the mean formant values if required
						for i_formant to report_formants
							if (im_request or cs_request or cz_request)
								call SelectObject formant_obj
								f'i_formant'_mean = Get mean: i_formant, t_left, t_right, unit$
								f'i_formant'_stdev = Get standard deviation: i_formant, t_left, t_right, unit$
								call ReportValue f'i_formant'_mean 1
								call ReportValue f'i_formant'_stdev 1
							endif

# Get quantiles if required
							if (nr_quantiles)
								for i_quantile to nr_quantiles
									selectObject: quantile_obj
									quantile_value$ = Get string: i_quantile
									quantile_value = number(quantile_value$) / 100
									call SelectObject: formant_obj
									quantile = Get quantile: i_formant, t_left, t_right, unit$, quantile_value
									call ReportValue quantile 1
								endfor
							endif
# going thru mean formant information
						endfor

###
# report contour data
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

# report pitch data
							if (cp_request)
								call ReportContour p
							endif

# go now thru the formants - repprting all requested data first for F1, then for F2, et
# always report formant center frequencies
							for i_formant to report_formants
								call ReportContour f

# report bandwidth data
								if (cb_request)
									call ReportContour b
								endif

# report quality data
								if (cq_request)
									call ReportContour q
								endif

# report amplitude data
								if (ca_request)
									call ReportContour a
								endif

# report subtract mean
								if (cs_request)
									call ReportContour s
								endif

# report z-sscores
								if (cs_request)
									call ReportContour z
								endif

# going thru (contour) formants information
							endfor

# rporting contour data
						endif

# all computations done for one interval that should be reported
						fileappend 'result_file_name$' 'out_line$''newline$'

# label, duration, pitch or intensity requirements of the interval are not met
# report interval with missing info depending on 'report_skipped_intervals' and 'l_flag'
# either all, or only if label$ is okay or none
					elsif (report_skipped_intervals = 1) or ((report_skipped_intervals = 2) and l_flag)
						call PrepareOutputLine
						if (ii_request)
							out_line$ += "'sep$''intensity_mean:01'"
						endif
						if (ip_request)
							if (pitch_mean <> undefined)
								out_line$ += "'sep$''pitch_mean:01'"
							else
								out_line$ += "'missing_value$'"
							endif
						endif
						out_line$ += "'skip_line$'"
						fileappend 'result_file_name$' 'out_line$''newline$'

# label, duration, pitch and intensity test
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
					printline File 'base_name$' skipped since tier 'tier' is not an interval tier.
				else
					printline skipped since tier 'tier' is not an interval tier.
				endif
			endif

# tier does not exist
		else
			if (!user_feedback)
				print 'base_name$'
			endif
			printline has only 'nr_tiers' tiers. File skipped. ***
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

# going thru all sound files
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

# check whether anything is requested at all
	if (report_formants <= 0)
		printline No formants to be reported: no data computed.
		exit
	endif
	if ((interval_parameters$ = "") and (number_of_measurements <= 0))
		printline Neither interval parameters nor contour data is requested: no data computed.
		exit
	endif

# code unit symbol for output
# (Praat provides only Hertz and Bark, but perhaps you want to compute others as well)
	if (unit$ = "hertz")
		un$ = "Hz"
	elsif (unit$ = "bark")
		un$ = "Bk"
	elsif (unit$ = "mel")
		un$ = "mel"
	elsif (unit$ = "ERB")
		un$ = "ERB"
	else
		printline Illegal unit selection: 'unit$'. Program aborted.
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
	if (minimal_intensity)
		ii_request = 1
	else
		ii_request = 0
	endif
# force report of pitch if pitch must exist
	if (pitch_must_exist)
		ip_request = 1
	else
		ip_request = 0
	endif
	im_request = 0
	nr_quantiles = 0

# check interval_parameters field (convert to lower case and change spaces to commas first)
	interval_parameters$ = replace_regex$ (interval_parameters$, ".", "\L&", 0)
	interval_parameters$= replace_regex$ (interval_parameters$, " ", ",", 0)
	item_obj = Create Strings as tokens: interval_parameters$, " ,"
	nr_items = Get number of strings

# go thru requested measures (add 'symmetrical' quantiles, sort them and remove doublets)
# (if no inerval parameters are selected, this loop will be skipped since nr_items will be 0)
	for i_item to nr_items
		selectObject: item_obj
		item$ = Get string: i_item
# intensity requested?
		if (item$ = "i")
			ii_request = 1
# pitch requested?
		elsif (item$ = "p")
			ip_request = 1
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

# no quantiles yet; initialize object
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

# check time and formant contour parameters
# preset requests to 'not requested' (= 0)
	ca_request = 0
	cb_request = 0
	ci_request = 0
	cp_request = 0
	cq_request = 0
	cs_request = 0
	cz_request = 0

# convert to lower case and convert spaces to commas first
	contour_parameters$ = replace_regex$ (contour_parameters$, ".", "\L&", 0)
	contour_parameters$ = replace_regex$ (contour_parameters$, " ", ",", 0)
	item_obj = Create Strings as tokens: contour_parameters$, " ,"

#  go thru requested formant contour measures
# (using a method like ci_request = (item$ = "i") would miss wrong inputs!)
	nr_items = Get number of strings
	for i_item to nr_items
		item$ = Get string: i_item

# amplitude requested?
		if (item$ = "a")
			ca_request = 1
# bandwidth requested?
		elsif (item$ = "b")
			cb_request = 1
# intensity requested for time points in contour?
		elsif (item$ = "i")
			ci_request = 1
# pitch requested for time points in contour?
		elsif (item$ = "p")
			cp_request = 1
# quality requested?
		elsif (item$ = "q")
			cq_request = 1
# mean subtraction requested?
		elsif (item$ = "s")
			cs_request = 1
# force mean request (to be able to do a substraction)
			im_request = 1
# time stamp requested?
		elsif (item$ = "t")
			ct_request = 1
# z-score requested?
		elsif (item$ = "z")
			cz_request = 1
# force mean request (to be able to compute z-scores)
			im_request = 1
		else
			printline Illegal formant contour parameter: "'item$'". Computation aborted."
			exit
		endif
	endfor
	removeObject: item_obj

# Check requests about Formants
	if (((highest_frequency / 1000) - 1) > compute_formants)
		printline Are you sure to compute only 'compute_formants' formants? This might give wrong results!
		pause
	endif
	if (report_formants > compute_formants)
		printline You want to report more formants than you want to compute! Script aborted.
		exit
	endif


### check which intervals are to be analyzed; set constants first:
# <nil> => all
	label_none = 0

# . => only labeled intervals
	label_any = 1

# label.txt or label(s)
	label_list = 2

# IPA vowel
	label_ipa = 11

# Kiel vowel
	label_kiel = 12

# SAMPA vowel
	label_sampa = 13

# TIMIT vowel
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

# report 'standard' vowels (prepare WordLists of vowels)
	elsif ((lc_label$ = "ipa") or (lc_label$ = "kiel") or (lc_label$ = "sampa") or (lc_label$ = "timit"))
		if (lc_label$ = "ipa")
			help$ = "a,ɑ,æ,ɐ,ɒ,œ,e,ɛ,ə,u,ʊ,ʉ,i,ɨ,ɪ,ɔ,o,ø"
			label_flag = label_ipa
		elsif (lc_label$ = "kiel")
			help$ = "@,2:,6,9,a,a:,E,e:,E:,I,i:,O,o:,U,u:,Y,y:"
			label_flag = label_kiel
		elsif (lc_label$ = "sampa")
			help$ = "A,{,6,Q,E,@,3,I,O,2,9,&,U,},V,Y"
			label_flag = label_sampa
		elsif (lc_label$ = "timit")
			help$ = "aa,ae,ah,ao,aw,ax,axr,ay,eh,er,ey,ih,ix,iy,ow,oy,uh,uw,ux"
			label_flag = label_timit
		else
			printline Impossible "'label$'". Script aborted.
			exit
		endif
		help_obj = Create Strings as tokens: help$, " ,"
		vowel_obj = To WordList
		removeObject: help_obj

# report labels from a label file
	elsif (endsWith(lc_label$,".txt"))
		label$ = support_directory$+label$
		if (not fileReadable (label$))
			printline Label file 'label$' not found. Script aborted.
			exit
		endif
		help_obj = Read Strings from raw text file: label$
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
##@@	label$ = replace_regex$ (label$, " ", ",", 0)
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
#		(mean intensity) (mean pitch)
#		for report_formants:
#			(mean formant) (stdev formant) (quantiles)
#		endfor
#	Contour information (loop thru time points on lower level inside 'ReportContour'):
#		(time) (intensity) (pitch)
#		for report_formants (and inside each formant: loop thru time points 'ReportContour'):
#			formant (bandwidth) (quality) (amplitude) (mean subtraction) (z-score)
#		endfor
#
#########################################################################################

procedure CreateResultFile

# create file name with date and time
	call GetDate date_time$
	result_file_name$ = result_directory$+"formant_results_"+date_time$+".txt"

# create header, dummy and missing data lines
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

# report intensity data for interval if requested
	if (ii_request)
		out_line$ += "'sep$'Intensity_mean(dB)"
		dummy_line$ += "'sep$'0.0"
	endif

# report pitch data for interval if requested
	if (ip_request)
		out_line$ += "'sep$'Pitch_mean(Hz)"
		dummy_line$ += "'sep$'0.0"
	endif
	remove_from_dummy$ = dummy_line$

# for each formant: mean, stdev and quantiles
	for i_formant to report_formants
		if (im_request)
			out_line$ += "'sep$'F'i_formant:0'_mean('un$')'sep$'F'i_formant:0'_stdev('un$')"
			dummy_line$ += "'sep$'0.0'sep$'0.0"
		endif

# add header for quantiles (automatically skipped if nr_quantiles = 0)
		for i_quantile to nr_quantiles
			selectObject: quantile_obj
			quantile_value$ = Get string: i_quantile
			quantile_value = number(quantile_value$)
			if (quantile_value = 0)
				out_line$ += "'sep$'F'i_formant'_Min('un$')"
			elsif (quantile_value = 50)
				out_line$ += "'sep$'F'i_formant'_Median('un$')"
			elsif (quantile_value = 100)
				out_line$ += "'sep$'F'i_formant'_Max('un$')"
			else
				out_line$ += "'sep$'F'i_formant'_'quantile_value:2'%('un$')"
			endif
			dummy_line$ += "'sep$'0.0"
		endfor

# going thru formants
	endfor

# contour required (i.e. number_of_measurements <> 0)?
	if (number_of_measurements)

# time, intensity, pitch info only once (if at all)
		if (ct_request)
			call ContourHeader t
		endif
		if (ci_request)
			call ContourHeader i
		endif
		if (cp_request)
			call ContourHeader p
		endif

# now loop thru formants
		for i_formant to report_formants
			i_formant$ = string$(i_formant)

# formants always; bandwidth, quality and amplitude on request
			call ContourHeader F 'i_formant$'

			if (cb_request)
				call ContourHeader B 'i_formant$'
			endif
			if (cq_request)
				call ContourHeader Q 'i_formant$'
			endif
			if (ca_request)
				call ContourHeader A 'i_formant$'
			endif

# subtract mean and z-scores
			if (cs_request)
				call ContourHeader sF 'i_formant$'
			endif
			if (cz_request)
				call ContourHeader zF 'i_formant$'
			endif

# going thru formants
		endfor

# contour requested
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

procedure ContourHeader x$ i$

	p1$ = "left"
	p2$ = "center"
	p3$ = "right"

# any time point measurement other than center (= 1)?
	if (number_of_measurements <> 1)
		perc_step = 100.0 / (number_of_measurements-1)
	endif

# adjust unit for report
	if (x$ = "A")
		pos_unit$ = "(dB)"
	elsif (x$ = "B")
		pos_unit$ = "('un$')"
	elsif (x$ = "F")
		pos_unit$ = "('un$')"
	elsif (x$ = "i")
		pos_unit$ = "(dB)"
	elsif (x$ = "p")
		pos_unit$ = "(Hz)"
	elsif (x$ = "Q")
		pos_unit$ = ""
	elsif (x$ = "sF")
		pos_unit$ = "('un$')"
	elsif (x$ = "t")
		pos_unit$ = "(s)"
	elsif (x$ = "zF")
		pos_unit$ = "(z)"
	else
		printline Illegal parameter for procedure ContourHeader: "'x$'". Computation aborted."
		exit
	endif

# next loop is only entered if a contour measurements is requested
	for i_pos to number_of_measurements

# special handling if only 3 or less required
		if (number_of_measurements = 1)
			p$ = p2$
			position$ = "'x$''i$'_'p$'"
		elsif (number_of_measurements = 2)
			if (i_pos = 1)
				p$ = p1$
			else
				p$ = p3$
			endif
			position$ = "'x$''i$'_'p$'"
		elsif (number_of_measurements = 3)
			p$ = p'i_pos'$
			position$ = "'x$''i$'_'p$'"
		elsif (position_in_percentage)
			perc = (i_pos-1) * perc_step
			position$ = "'x$''i$'_t'perc:2'%"
		else
			position$ = "'x$''i$'_t'i_pos'"
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

		if (obj$ = "formant_obj")
			formant_obj = 'np_string$' To Formant (burg): step_rate, compute_formants, highest_frequency, window_length, pre_emphasis
		elsif (obj$ = "intensity_obj")
			intensity_obj = 'np_string$' To Intensity: low_pitch, step_rate, "yes"
		elsif (obj$ = "lpc_obj")
			new_freq = highest_frequency * 2
			help_obj = 'np_string$' Resample: new_freq, 50
			nr_poles = compute_formants * 2
			lpc_obj = 'np_string$' To LPC (autocorrelation): nr_poles, window_length, 0.005, pre_emphasis
			removeObject: help_obj
		elsif (obj$ = "pitch_obj")
			pitch_obj = 'np_string$' To Pitch: step_rate, low_pitch, high_pitch
		elsif (obj$ = "wav_obj")
		else
			printline Illegal object in procedure SelectObject: 'obj$'. Program aborted.
			exit
		endif
	endif
endproc



#########################################################################################
#
#	Procedure to test whether a interval's label is an IPA, Kiel, Sampa or TIMIT vowel#
#	@@ no diphthongs!
#
#########################################################################################

procedure IsVowel interval_label$$ l_flag

# test for IPA vowels
	if (label_flag = label_ipa)
# remove additional marks (diacritics, stress marks)
		local_label$ = replace_regex$ (interval_label$, "[:ːˑʰ̹̜̥̠̯̤̰̝̞̘̙̈̽˷̃ˈ̩̟̆]", "", 0)

# test for Kiel vowels
	elsif (label_flag = label_kiel)
		local_label$ = interval_label$

# test for SAMPA vowels (no lower/upper case conversion, because SAMPA uses lower and uper case for different phoneme)
	elsif (label_flag = label_sampa)
# remove additional marks (diacritics, stress marks)
		local_label$ = replace_regex$ (interval_label$, "[:'`~%]", "", 0)

# test for TIMIT vowels
	elsif (label_flag = label_timit)
# convert to lower case (same us lower case, some upper case)
		local_label$ = replace_regex$ (interval_label$, ".", "\L&", 0)

# this should not happen
	else
		printline Impossible label_flag in IsVowel: 'label_flag'. Script aborted.
		exit
	endif

	selectObject: vowel_obj
	l_flag = Has word: local_label$
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
		elsif (x$ = "p")
			call SelectObject pitch_obj
			for i_pos to number_of_measurements
				pitch = Get value at time: mid, "hertz", "linear"
				call ReportValue pitch 1
				mid += dur_step
			endfor

# report (and store) formant at this point ('i_formant' is set outside this procedure)
		elsif (x$ = "f")
			call SelectObject formant_obj
			for i_pos to number_of_measurements
				f'i_formant'_'i_pos' = Get value at time: i_formant, mid, unit$, "linear"
				call ReportValue f'i_formant'_'i_pos' 1
				mid += dur_step
			endfor

# report bandwidth at this point ('i_formant' is set outside this procedure)
		elsif (x$ = "b")
			call SelectObject formant_obj
			for i_pos to number_of_measurements
				bandwidth = Get bandwidth at time: i_formant, mid, unit$, "linear"
				call ReportValue bandwidth 1
				mid += dur_step
			endfor

# report quality at this point ('i_formant' is set outside this procedure)
# (formants are already computed, but bandwidth might not be computed, so we do it here anyway)
		elsif (x$ = "q")
			call SelectObject formant_obj
			for i_pos to number_of_measurements
				bandwidth = Get bandwidth at time: i_formant, mid, unit$, "linear"
				if (bandwidth <> undefined)
					quality = f'i_formant'_'i_pos' / bandwidth
				else
					quality = bandwidth
				endif
				call ReportValue quality 1
				mid += dur_step
			endfor

# report amplitude
		elsif (x$ = "a")
			for i_pos to number_of_measurements
				call SelectObject intensity_obj
				intensity = Get value at time: mid, "Cubic"
				call SelectObject lpc_obj
				slice_obj = 'np_string$' To Spectrum (slice): mid, 20, 0, pre_emphasis
				ltas_obj = 'np_string$' To Ltas (1-to-1)
				amplitude = Get value at frequency: f'i_formant'_'i_pos',"Cubic"
				amplitude -= intensity + arbitrary_db
				removeObject: slice_obj, ltas_obj
				call ReportValue amplitude 1
				mid += dur_step
			endfor

# report subtracted mean
# (formant values are already computed at this time and stored in variables like formant1_1, formant1_2…)
		elsif (x$ = "s")
			for i_pos to number_of_measurements
				formant_s = f'i_formant'_'i_pos' - f'i_formant'_mean
				call ReportValue formant_s 2
			endfor

# report z-scores
# (formant values are already computed at this time and stored in variables like formant1_1, formant1_2…)
		elsif (x$ = "z")
			for i_pos to number_of_measurements
				formant_z = (f'i_formant'_'i_pos' - f'i_formant'_mean) / f'i_formant'_stdev
				call ReportValue formant_z 2
			endfor
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
		call IsVowel interval_label$ l_flag

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
	if (formant_obj)
		removeObject: formant_obj
	endif
	if (intensity_obj)
		removeObject: intensity_obj
	endif
	if (pitch_obj)
		removeObject: pitch_obj
	endif
	if (lpc_obj)
		removeObject: lpc_obj
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

#@ check what is missing

procedure ReportAnalysisParameter
	out_line$ = newline$
	out_line$ += "Script: Formant_'version'_'revision'_'bugfix'.praat'newline$'"
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
	out_line$ += "Minimal length: 'minimal_length_ms' ms'newline$'"
	out_line$ += "Minimal intensity: 'minimal_intensity' dB'newline$'"
	out_line$ += "Pitch must exist: "
	if (pitch_must_exist)
		out_line$ += "Yes'newline$'"
	else
		out_line$ += "No'newline$'"
	endif
	out_line$ += "Analysis crosses interval boundaries: "
	if (cross_interval_boundary)
		out_line$ += "Yes'newline$'"
	else
		out_line$ += "No'newline$'"
	endif
	out_line$ += "Formants computed: 'compute_formants''newline$'"
	out_line$ += "Highest formants frequency: 'highest_frequency' Hz'newline$'"
	out_line$ += "Step rate: 'step_rate_in_ms' ms'newline$'"
	out_line$ += "Window size: 'window_length_ms' ms'newline$'"
	out_line$ += "Pre-emphasis: 'pre_emphasis' Hz'newline$'"
	if (ca_request)
		out_line$ += "Offset for formant amplitude: 'arbitrary_db' dB'newline$'"
	endif
	fileappend 'result_file_name$' 'out_line$'
endproc

##
#	This script generates 'Formant contours' of segments.
#
#	This script opens all sound files in a directory and their associated TextGrids,
#	computes the first Formants and their Bandwidths of all labelled segments (in Hz) in steps 
#	and writes the results as a percentage of the time of a segment to a text file 
#	"formant_contour_results<date_time>.txt" at the same directory of the sound files.
#
#	Version 1.0, Henning Reetz, 06-sep-2016; modified version of pitch_contour_2_6.praat
#	Version 2.0, Henning Reetz, 13-mar-2020; added features from formant_complex_2_0.praat
#	Version 3.0, Henning Reetz, 24-mar-2020; decide on intensity and pitch requirements on basis of whole segment
#	Version 3.1, Henning Reetz, 01-apr-2020; compute interval-steps for not-crossing LPC-windows speparately in stead of shifting window at edges 
#	Version 3.2, Henning Reetz, 05-apr-2020; Duration output in seconds possible
#	Version 4.0, Henning Reetz, 17-apr-2020; Major revision to harmonise with Formants_3_0.praat
#	Version 4.1, Henning Reetz, 30-apr-2020; Tested with separate directories for wav and TextGrid etc.
#  	Version 4.2, Henning Reetz, 12-may-2020; removed bug with label_list_obj handling, some clean up
#
#	Tested with Praat 6.1.12
#
##

clearinfo

##
# 1) Inquire and check some parameters
# ! Note that 'form' may only be used once in a script!
##

form Formant contour parameters:
	comment Leave the directory path empty if you want to use the current directory.
		text Directory
		integer Tier_to_be_analysed 1
	comment ______________________________________________________________________________________________________________
	comment <label>, <list>.txt, 'IPA', 'Kiel', 'Sampa', 'TIMIT', '.' (= only labelled), or empty (= all)
		sentence Label kiel
		real Minimal_length_ms 25
		real Minimal_intensity 40
		boolean Pitch_must_exist 0
	comment Nr. of measurements per segment. 1: only center, 2: only edges
		integer Number_of_measurements 3
	comment ______________________________________________________________________________________________________________
		integer Compute_formants 5
		integer Report_formants 3
		real Highest_frequency 5000.0
	comment Do you want (t)ime, (i)ntensity, (p)itch, formant (b)andwidth, (q)uality, (a)mplitude?
		sentence Formant_parameters b,q
	comment ______________________________________________________________________________________________________________
	choice Report_skipped_intervals: 2
		button All
		button Length, Intensity, Pitch exclusion
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

# can the analysis window at the edges of a segment cross the segment boundary (=1) or not (=0)
do_not_cross_segment_boundary = 1

# are frequencies in Hertz (unit = 1) or Bark (unit = 2)
unit = 1

# should there be minimal user feedback to speed up processing (= 1) or not (= 0)
user_feedback = 1

# should there be no processing information from Praat (= "noprogress") or not (= ""  ; i.e. empty string)
np_string$ = "noprogress"

# should there be a dummy data header to force correct data type in JMP or other tables (= 1) or not (= 0) 
dummy_data_header = 0

# report duration in ms (duration_in_ms = 1) or seconds (duration_in_ms = 0)
duration_in_ms = 1

# maximal length in seconds of a segment to be considered to be a analysed
max_length = 2.0

# formant computation parameters
pre_emphasis = 50.0
step_rate = 0.0
window_length_ms = 25.6
window_length = window_length_ms / 1000.0

# pitch computation parameters
low_pitch = 75
high_pitch = 600

# half window length will be used if no segment boundaries should be crossed
half_window_length = window_length / 2.0

# re-code minimal intensity if necessary
intensity_percentil_flag = ((minimal_intensity > 0) and (minimal_intensity < 1))

# use an arbitrary reference to shift amplitude-values of formants in a resonable range
# it woul dbe 92 dB for a full 16-bit resolution, but usually the signal is a bout 12 dB lower
arbitrary_db = 80

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
			selectObject: wav_obj
			formant_obj = 'np_string$' To Formant (burg): step_rate, compute_formants, highest_frequency, window_length, pre_emphasis

			if (a_request)
				selectObject: wav_obj
				new_freq = highest_frequency * 2
				help_obj = 'np_string$' Resample: new_freq, 50
				nr_poles = compute_formants * 2
				lpc_obj = 'np_string$' To LPC (autocorrelation): nr_poles, window_length, 0.005, pre_emphasis
				removeObject: help_obj
			endif

			selectObject: wav_obj
			intensity_obj = 'np_string$' To Intensity: 100, 0, "yes"
			if (intensity_percentil_flag)
				min_intensity = Get quantile: 0, 0, minimal_intensity
			else
				min_intensity = minimal_intensity
			endif

			selectObject: wav_obj
			pitch_obj = 'np_string$' To Pitch: 0, low_pitch, high_pitch

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

# warn about very long intervals
				if (duration > max_length)
					if (!user_feedback)
						print 'newline$'File 'base_name$' 
					endif
					printline – has a segment longer than 'max_length' seconds.
				endif 

# Get Formant chunks of segment; use 'mid' as guiding time
				if (number_of_measurements = 1)
					mid = (t_right + t_left) / 2
					perc = 50

# compute positions for analysis windows not crossing segment boundaries
				elsif (do_not_cross_segment_boundary)					
					dur = (t_right - t_left - window_length) / (number_of_measurements-1)
					mid = t_left + half_window_length
					perc = 0

# compute positions for analysis windows at segment boundaries
				else				
					dur = (t_right - t_left) / (number_of_measurements-1)
					mid = t_left
					perc = 0
				endif
#
# check whether this segment should be reported
#
				d_flag = 0
				p_flag = 0
				i_flag = 0
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

# report all vowels
				elsif (label_flag > 10)
					call IsVowel interval_label$ l_flag

# impossible
				else
					printline Impossible label_flag: 'label_flag'. Script aborted.
					exit
				endif

### check for minimal duration
				d_flag = (duration_ms > minimal_length_ms)

### check for pitch (pitch is always needed for report)
				selectObject: pitch_obj
				pitch_mean = Get mean: t_left, t_right, "hertz"
				if (pitch_must_exist)
					p_flag = (pitch_mean <> undefined)
				else
					p_flag = 1
				endif

### check for intensity (intensity is always needed for report)
				selectObject: intensity_obj
				intensity_mean = Get mean: t_left, t_right, "energy"
				i_flag = (intensity_mean > min_intensity)

### check whether all conditions are met
				if (l_flag + d_flag + p_flag + i_flag = 4)
					nr_measured_segments += 1

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
						out_line$ += "'tab$''intensity_mean:01'"
						if (pitch_mean <> undefined)
							out_line$ += "'tab$''pitch_mean:01'"
						else
							out_line$ += "'missing_value$'"
						endif
						out_line$ += "'tab$''perc:0'"

# report times of measurement
						if (t_request)
							out_line$ += "'tab$''time:04'"
						endif

# report intensity if requested
						if (i_request)
							selectObject: intensity_obj
							intensity = Get value at time: time, "Cubic"
							out_line$ += "'tab$''intensity:01'"
						endif

# report pitch if requested
						if (p_request)
							selectObject: pitch_obj
							pitch = Get value at time: time, "hertz", "Linear"
							if (pitch <> undefined)
								out_line$ += "'tab$''pitch:01'"
							else
								out_line$ += "'missing_value$'"
							endif
						endif

### now do the formant measurement
						selectObject: formant_obj
						for i_formant to report_formants
							f'i_formant' = Get value at time: i_formant, time, unit$, "Linear"

# if formant has a value, bandwidth must be there as well
							if (f'i_formant' <> undefined)					
								b'i_formant' = Get bandwidth at time: i_formant, time, unit$, "Linear"
								q'i_formant' = f'i_formant' / b'i_formant'
								if (a_request)
									selectObject: intensity_obj
									intensity = Get value at time: time, "Cubic"
									selectObject: lpc_obj						
									slice_obj = 'np_string$' To Spectrum (slice): time, 20, 0, pre_emphasis
									ltas_obj = 'np_string$' To Ltas (1-to-1)
									a'i_formant' = Get value at frequency: f'i_formant',"Cubic"
									a'i_formant' = a'i_formant' - intensity + arbitrary_db
									removeObject: slice_obj, ltas_obj
									selectObject: formant_obj

# ReportFormant needs 4 parameters, just use 0.0 for 'a' 
								else
									a'i_formant' = 0.0
								endif

# no formant found. ReportFormant will handle it, but the parameters must be there, i.e. use just 0.0  
							else
								b'i_formant' = 0.0
								a'i_formant' = 0.0
								q'i_formant' = 0.0
							endif

# now report the formant
							call ReportFormant f'i_formant' b'i_formant' a'i_formant' q'i_formant'

# looping thru formants to be reported
						endfor

# add a newline for this data set
						fileappend 'result_file_name$' 'out_line$''newline$'

# update positions for next chunk						
						mid = mid + dur
						perc = perc + perc_step

# stepping thru one interval
					endfor					

# label, duration, pitch and intensity requirements of the interval are not met
# report interval with missing info depending on 'report_skipped_intervals' and 'l_flag'
# either all, or only if label$ is okay or none
				elsif (report_skipped_intervals = 1) or ((report_skipped_intervals = 2) and l_flag)
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
					out_line$ += "'tab$''intensity_mean:01''tab$''pitch_mean:01''skip_line$'"
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
			removeObject: grid_obj, wav_obj, intensity_obj, pitch_obj, formant_obj
# LPC object is generated for any interval tier
			if (a_request)
				removeObject: lpc_obj
			endif
	
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
elsif (label_flag > 10)
	removeObject: vowel_obj
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

# recode units (and strings for header of output file)
	if (unit = 1)
		unit$ = "hertz"
		un$ = "(Hz)"
	else
		unit$ = "bark"
		un$ = "(Bk)"
	endif

# Check requests about Formants 
	if (((highest_frequency / 1000) - 1) > compute_formants)
		printline Are you sure to compute only 'compute_formants' Formants? This might give wrong results!
		pause
	endif
	if (report_formants > compute_formants)
		printline You want to report more formants than you want to compute! Script aborted.
		exit
	endif

# check time and formant parameters (convert to lower case and convert spaces to commas first)
	formant_parameters$ = replace_regex$ (formant_parameters$, ".", "\L&", 0)
	formant_parameters$ = replace_regex$ (formant_parameters$, " ", ",", 0)
	help_obj = Create Strings as tokens: formant_parameters$, " ,"
	help2_obj = To WordList
	a_request = Has word: "a"
	b_request = Has word: "b"
	i_request = Has word: "i"
	p_request = Has word: "p"
	q_request = Has word: "q"
	t_request = Has word: "t"
	removeObject: help_obj
	removeObject: help2_obj
  
### check which segments are to be analyzed; set constants first:
# <nil> => all
	label_none = 0

# . => only labeled segments
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

# report vowels (prepare WordLists)
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
			printline Impossible lc_label$: 'lc_label$'. Scripte aborted.
			exit
		endif
		help_obj = Create Strings as tokens: "'help$'", " ,"
		vowel_obj = To WordList
		removeObject: help_obj

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
	result_file_name$ = result_directory$+"formant_contour_results_"+date_time$+".txt"

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
	out_line$ += "'tab$'Intensity_mean(dB)'tab$'Pitch_mean(Hz)'tab$'%"
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
		out_line$ += "'tab$'timepoint(s)"
		dummy_line$ += "'tab$'0.0"
	endif
	if (i_request)
		out_line$ += "'tab$'intensity(dB)"
		dummy_line$ += "'tab$'0.0"
	endif
	if (p_request)
		out_line$ += "'tab$'pitch(Hz)"
		dummy_line$ += "'tab$'0.0"
	endif

	for i_formant to report_formants
		out_line$ += "'tab$'F'i_formant:0''un$'"
	    dummy_line$ += "'tab$'0.0"
		if (b_request)
			out_line$ += "'tab$'B'i_formant:0''un$'"
			dummy_line$ += "'tab$'0.0"
		endif
		if (a_request)
			out_line$ += "'tab$'A'i_formant:0'(dB)"
		    dummy_line$ += "'tab$'0.0"
		endif
    	if (q_request)
			out_line$ += "'tab$'Q'i_formant:0''un$'"
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
#	Procedure to test whether a segment's label is an IPA, Kiel, Sampa or TIMIT vowel#
#@@ no diphthongs!
##
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


## Procedure to report one formant

procedure ReportFormant f b a q
	if (f <> undefined)
		if (unit$ = "hertz")
			out_line$ += "'tab$''f:0'"
			if (b_request)
				out_line$ += "'tab$''b:0'"
			endif
			if (a_request)
				out_line$ += "'tab$''a:01'"
			endif
			if (q_request)
				out_line$ += "'tab$''q:02'"
			endif
		else
			out_line$ += "'tab$''f:02'"
			if (b_request)
				out_line$ += "'tab$''b:02'"
			endif
			if (a_request)
				out_line$ += "'tab$''a:01'"
			endif
			if (q_request)
				out_line$ += "'tab$''q:02'"
			endif
		endif
	else
		out_line$ += "'missing_value$'"
		if (b_request)
			out_line$ += "'missing_value$'"
		endif
		if (a_request)
			out_line$ += "'missing_value$'"
		endif
		if (q_request)
			out_line$ += "'missing_value$'"
		endif
	endif
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
	out_line$ += "Minimal length: 'minimal_length_ms' ms'newline$'"	
	out_line$ += "Minimal intensity: 'minimal_intensity' dB'newline$'"	
	out_line$ += "Pitch must exist: "	
	if (pitch_must_exist)
		out_line$ += "Yes'newline$'"	
	else
		out_line$ += "No'newline$'"	
	endif
	out_line$ += "Formants computed: 'compute_formants''newline$'"	
	out_line$ += "Highest formants frequency: 'highest_frequency' Hz'newline$'"	
	out_line$ += "Window size: 'window_length_ms' ms'newline$'"	
	out_line$ += "Pre-emphasis: 'pre_emphasis''newline$'"	
	if (a_request)
		out_line$ += "Offset for formant amplitude: 'arbitrary_db' dB'newline$'"	
	endif
	fileappend 'result_file_name$' 'out_line$'
endproc

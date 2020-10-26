##
#	This script computes the formants of all segments or at points that fit several
#	criteria of all wav-soundfiles in a directory which have a textgrid file.
#
#  	Version 0.0, Henning Reetz, 27-aug-2007
#	Version 1.1, Henning Reetz, 16-jun-2009; no computation of Formants if
#				interval is shorter than a given size or label of interval is a dot ('.') only;
#				center of left and right edge-positions are shifted by half window size to have the analysis inside the interval
#  	Version 2.0, Henning Reetz, 24-mar-2019	more parameters, pitch and intensity reported
#  	Version 3.0, Henning Reetz, 05-apr-2020	general revision; adaptations taken from Formant_contour.praat
#  	Version 4.0, Henning Reetz, 16-apr-2020	more adaptations and version number should be now in parallel
#  	Version 4.1, Henning Reetz, 30-apr-2020	tested with separate directories for wav and TextGrid etc.
#  	Version 4.2, Henning Reetz, 12-may-2020	removed bug with label_list_obj handling, some clean up
#
#@@ implement point tier handling
#
#	Tested with Praat 6.1.12
##

clearinfo

##
# 1) Inquire and check some parameters
# ! Note that 'form' may only be used once in a script!
##

form Formant parameters:
	comment Leave the directory path empty if you want to use the current directory.
		text Directory
		integer Tier_to_be_analysed 1
	comment ______________________________________________________________________________________________________________
	comment <label>, <list>.txt, 'IPA', 'Kiel', 'Sampa', 'TIMIT', '.' (= only labelled), or empty (= all)
		sentence Label kiel
		real Minimal_length_ms 25
		real Minimal_intensity 40
		boolean Pitch_must_exist 0
	comment ______________________________________________________________________________________________________________
		boolean Center_position 1
		boolean Edges 0
		boolean Means 0
		word Quantiles
	comment ______________________________________________________________________________________________________________
		integer Compute_formants 5
		integer Report_formants 3
		real Highest_frequency 5000.0
	comment Do you want (t)ime, (i)ntensity, (p)itch, formant (b)andwidth, (q)uality, (a)mplitude?
		sentence Formant_parameters t b,q
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
				t1 = Get starting point: tier, i_segment
				t3 = Get end point:      tier, i_segment
				t_adj_2 = (t1 + t3) / 2
				if (do_not_cross_segment_boundary)
					t_adj_1 = t1 + half_window_length
					t_adj_3 = t3 - half_window_length
				else
					t_adj_1 = t1
					t_adj_3 = t3
				endif
				duration = t3 - t1
				duration_ms = duration * 1000

# warn about very long intervals
				if (duration > max_length)
					if (!user_feedback)
						print 'newline$'File 'base_name$' 
					endif
					printline – has a segment longer than 'max_length' seconds.
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
				pitch_mean = Get mean: t1, t3, "hertz"
				if (pitch_must_exist)
					p_flag = (pitch_mean <> undefined)
				else
					p_flag = 1
				endif

### check for intensity (intensity is always needed for report)
				selectObject: intensity_obj
				intensity_mean = Get mean: t1, t3, "energy"
				i_flag = (intensity_mean > min_intensity)

### check whether all conditions are met
				if (l_flag and d_flag and p_flag and i_flag)
					nr_measured_segments += 1

# prepare output line
					out_line$ = ""
					if (path_name)
						out_line$ += "'wav_directory$''tab$'"
					endif
					out_line$ += "'base_name$''tab$''interval_label$''tab$''t1:04'"
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
#					
# Get formant values at left, middle and right of segment (even if not needed - this action does not take time)
#
					selectObject: formant_obj
					for i_formant to report_formants
						for i_pos to 3
							f'i_pos''i_formant' = Get value at time: i_formant, t_adj_'i_pos', unit$, "Linear"
							if (f'i_pos''i_formant' <> undefined)					
								b'i_pos''i_formant' = Get bandwidth at time: i_formant, t_adj_'i_pos', unit$, "Linear"
								q'i_pos''i_formant' = f'i_pos''i_formant' / b'i_pos''i_formant'
								if (a_request)
									selectObject: intensity_obj
									intensity = Get value at time: t_adj_'i_pos', "Cubic"
									selectObject: lpc_obj						
									slice_obj = 'np_string$' To Spectrum (slice): t_adj_'i_pos', 20, 0, pre_emphasis
									ltas_obj = 'np_string$' To Ltas (1-to-1)
									a'i_pos''i_formant' = Get value at frequency: f'i_pos''i_formant',"Cubic"
									a'i_pos''i_formant' = a'i_pos''i_formant' - intensity + arbitrary_db
									removeObject: slice_obj, ltas_obj
									selectObject: formant_obj
								else
									a'i_pos''i_formant' = 0.0
								endif
# for an undefined formant value, a, b, and q will not be reported, but we need the variables to feed them to the FormantReport procdure
							else
								b'i_pos''i_formant' = 0.0
								a'i_pos''i_formant' = 0.0
								q'i_pos''i_formant' = 0.0
							endif
						endfor					
					endfor

# report times, intensity and pitch at measurement if requested
					for i_pos to 3
						if (((i_pos<>2) and edges) or ((i_pos=2) and center_position))
							if (t_request)
								help = t_adj_'i_pos'
								out_line$ += "'tab$''help:04'"
							endif
							if (i_request)
								selectObject: intensity_obj
								intensity = Get value at time: t_adj_'i_pos', "Cubic"
								out_line$ += "'tab$''intensity:01'"
							endif
							if (p_request)
								selectObject: pitch_obj
								pitch = Get value at time: t_adj_'i_pos', "hertz", "Linear"
								if (pitch <> undefined)
									out_line$ += "'tab$''pitch:01'"
								else
									out_line$ += "'missing_value$'"
								endif
							endif			
						endif
					endfor
# report formants in a ordered way: left, center, right
					for i_formant to report_formants
						if (edges)
							call ReportFormant f1'i_formant' b1'i_formant' a1'i_formant' q1'i_formant'
						endif
						if (center_position)
							call ReportFormant f2'i_formant' b2'i_formant' a2'i_formant' q2'i_formant'
						endif
						if (edges)
							call ReportFormant f3'i_formant' b3'i_formant' a3'i_formant' q3'i_formant'
						endif

# Get the mean of the formant frequency for this formant
						if (means)
							selectObject: formant_obj
							f_mean  = Get mean: i_formant, t1, t3, unit$
							f_stdev = Get standard deviation: i_formant, t1, t3, unit$
							if f_mean <> undefined
								if (unit$ = "hertz")
									out_line$ += "'tab$''f_mean:0''tab$''f_stdev:02'"
								else
									out_line$ += "'tab$''f_mean:02''tab$''f_stdev:02'"
								endif
							else
								out_line$ += "'missing_value$''missing_value$'"
							endif
							for i_quantile to nr_quantiles
								selectObject: 'quantile_obj'
								quantile_value$ = Get string: i_quantile
								quantile_value = number(quantile_value$) / 100
								selectObject: 'formant_obj'
								f_quantile  = Get quantile: i_formant, t1, t3, "'unit$'", quantile_value
								if f_quantile <> undefined
									if (unit$ = "hertz")
										out_line$ += "'tab$''f_quantile:0'"
									else
										out_line$ += "'tab$''f_quantile:02'"
									endif
								else
									out_line$ += "'missing_value$'"
								endif
							endfor
# end of means handling
						endif
						
# end of formants handling
					endfor

# all computations done for one segment
					fileappend 'result_file_name$' 'out_line$''newline$'

# label, duration, pitch and intensity requirements of the interval are not met
# report interval with missing info depending on 'report_skipped_intervals' and 'l_flag'
# either all, or only if label$ is okay or none
				elsif (report_skipped_intervals = 1) or ((report_skipped_intervals = 2) and l_flag)
					out_line$ = ""
					if (path_name)
						out_line$ += "'wav_directory$''tab$'"
					endif
					out_line$ += "'base_name$''tab$''interval_label$''tab$''t1:04'"
					if (duration_in_ms)
						out_line$ += "'tab$''duration_ms:01'"
					else
						out_line$ += "'tab$''duration:04'"
					endif
					out_line$ += "'tab$''intensity_mean:01'"
					if (pitch_mean <> undefined)
						out_line$ += "'tab$''pitch_mean:01''skip_line$'"
					else
						out_line$ += "'missing_value$''skip_line$'"
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
			removeObject: grid_obj, wav_obj, intensity_obj, pitch_obj, formant_obj
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
		removeObject: wav_obj, grid_obj
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

# check whether anything is selected at all
	if (center_position+edges+means = 0)
		printline Neither Center position, Edges nor Mean are selected: no data computed.
		exit
	endif

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
	removeObject: help_obj, help2_obj

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
	endif
endproc


##
#	Create resultfile
##

procedure CreateResultFile

# create file name with date and time
	call GetDate date_time$
	result_file_name$ = result_directory$+"formant_results_"+date_time$+".txt"

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
	out_line$ += "'tab$'Intensity_mean(dB)'tab$'Pitch_mean(Hz)"
	dummy_line$ = ""
	if (path_name)
		dummy_line$ += "'wav_directory$''tab$'"
	endif
	dummy_line$ += "Dummy'tab$'Dummy'tab$'0.0'tab$'0.0'tab$'0.0'tab$'0.0"
	remove_from_dummy$ = dummy_line$

	p1$ = "_left"
	p2$ = "_mid"
	p3$ = "_right"
	for i_pos to 3
		if (((i_pos<>2) and edges) or ((i_pos=2) and center_position))
			position$ = p'i_pos'$
			if (t_request)
				out_line$ += "'tab$'t'position$'(s)"
				dummy_line$ += "'tab$'0.0"
			endif
			if (i_request)
				out_line$ += "'tab$'i'position$'(s)"
				dummy_line$ += "'tab$'0.0"
			endif
			if (p_request)
				out_line$ += "'tab$'p'position$'(s)"
				dummy_line$ += "'tab$'0.0"
			endif
		endif
	endfor

	for i_formant to report_formants
		for i_pos to 3
			if (((i_pos<>2) and edges) or ((i_pos=2) and center_position))
				position$ = p'i_pos'$
				out_line$ += "'tab$'F'i_formant:0''position$''un$'"
			    dummy_line$ += "'tab$'0.0"
			    if (b_request)
					out_line$ += "'tab$'B'i_formant:0''position$''un$'"
		    		dummy_line$ += "'tab$'0.0"
				endif
			    if (a_request)
					out_line$ += "'tab$'A'i_formant:0''position$'(dB)"
		    		dummy_line$ += "'tab$'0.0"
				endif
				if (q_request)
					out_line$ += "'tab$'Q'i_formant:0''position$''un$'"
					dummy_line$ += "'tab$'0.0"
				endif
			endif
		endfor
		if (means)
			out_line$ += "'tab$'F'i_formant:0'_mean'un$''tab$'F'i_formant:0'_stdev'un$'"
			dummy_line$ += "'tab$'0.0'tab$'0.0"
			for i_quantile to nr_quantiles
				quantile_value$ = Get string: i_quantile
				quantile_value = number(quantile_value$)
				if (quantile_value = 50)
					out_line$ += "'tab$'F'i_formant:0'_median'un$'"
				else
					out_line$ += "'tab$'F'i_formant:0'_'quantile_value:0'%'un$'"
				endif
				dummy_line$ += "'tab$'0.0'"
			endfor
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

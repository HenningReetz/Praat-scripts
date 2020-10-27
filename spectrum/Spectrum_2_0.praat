##
#	This script computes the formants of all labeled
#	segments of all wav-soundfiles in a directory.
#
#  	Version 1.0, Henning Reetz, 27-aug-2007
#  	Version 2.0, Henning Reetz, 10-may-2020	Adapted to Formants_4_0 format
#
##
##@@ spectral slopes, energy in frequency band, graphdump, table dump

clearinfo

#
## 1) Inquire some parameters
## ! Note that 'form' may only be used once in a script!
#

form Spectrum parameters:
	comment Leave the directory path empty if you want to use the current directory.
		text Directory
		integer Tier_to_be_analysed 1
	comment ______________________________________________________________________________________________________________
	comment <label>, <list>.txt, 'IPA', 'Kiel', 'Sampa', 'TIMIT', '.' (= only labelled), or empty (= all)
		sentence Label kiel
		real Minimal_length_ms 25
		real Minimal_intensity 40
		real High_pass_filter_frequency 300
		real Highest_frequency 10000
	comment ______________________________________________________________________________________________________________
		boolean Center_position 1
		boolean Means 0
	comment ______________________________________________________________________________________________________________
	comment Do you want (m)odes and/or spectral (p)eak? 
		sentence Parameters m p
	comment ______________________________________________________________________________________________________________
	choice Report_skipped_intervals: 2
		button All
		button Length, Intensity exclusion
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

# should there be minimal user feedback to speed up processing (= 1) or not (= 0)
user_feedback = 1

# should there be no processing information from Praat (= "noprogress") or not (= ""  ; i.e. empty string)
np_string$ = "noprogress"

# should there be a dummy data header to force correct data type in JMP or other tables (= 1) or not (= 0) 
dummy_data_header = 1

# report duration in ms (duration_in_ms = 1) or seconds (duration_in_ms = 0)
duration_in_ms = 1

# window size for spectrogram computing
window_size = 0.005

# maximal length in seconds of a segment to be considered to be a analysed
max_length = 2.0

# re-code minimal intensity if necessary
intensity_percentil_flag = ((minimal_intensity > 0) and (minimal_intensity < 1))

# just to make the variable name shorter
tier = tier_to_be_analysed

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
nr_low_rate = 0

# total nr. of segments of all files
tot_segments = 0

# create list of .textgrid files
grid_list_obj = Create Strings as file list: "file_list", "'grid_directory$'*.TextGrid"
nr_grid_files = Get number of strings

# Give minimal user feedback
if (!user_feedback)
	print Computing... 
endif

##
# 5) Go thru all files
##

for i_file to nr_grid_files
	selectObject: grid_list_obj
	grid_name$ = Get string: i_file
	grid_obj = Read from file: "'grid_directory$''grid_name$'"
# Do not use "selected$("TextGrid")" go get the sound file name, because PRAAT converts 
# many symbols (like a tilde "~") into an underline ("_")
	base_name$ = replace_regex$(grid_name$,".TextGrid$","",1)
	nr_grid += 1

	if (user_feedback)
		print Handling 'base_name$' 
	endif
	
	nr_tiers = Get number of tiers
	if (tier <= nr_tiers)

# check whether tier is an interval tier.
		tier_is_interval = Is interval tier: tier
		if  (tier_is_interval)
# check whether sound file exists
			wav_name$ = wav_directory$+base_name$+ext$
			if (fileReadable(wav_name$))
				wav_obj = Read from file: wav_name$
				nr_wav += 1
				
# resample if necessary
				rate = Get sampling frequency
				nyquist = rate / 2
				if (highest_frequency and (nyquist > highest_frequency))
					new_freq = highest_frequency * 2
					help_obj = Resample: new_freq, 50
					removeObject: wav_obj
					wav_obj = help_obj
				elsif (highest_frequency and (nyquist < highest_frequency))
					nr_low_rate += 1
					if (!user_feedback)
						print 'base_name$' 
					endif
					printline has a sampling rate of 'rate' Hz (Nyquist: 'nyquist' Hz) ***
				endif
				
# filter, if required
				if (high_pass_filter_frequency)
					selectObject: wav_obj
					help_obj = Filter (stop Hann band): 0, high_pass_filter_frequency, 100
					removeObject: wav_obj
					wav_obj = help_obj
				endif

# compute intensity for intensity filtering and reporting (always needed)
				selectObject: wav_obj
				intensity_obj = 'np_string$' To Intensity: 100, 0, "yes"
				if (intensity_percentil_flag)
					min_intensity = Get quantile: 0, 0, minimal_intensity
				else
					min_intensity = minimal_intensity
				endif

				if (center_position)
					selectObject: wav_obj
					spectrogram_obj = 'np_string$' To Spectrogram: window_size, highest_frequency, 0.002, 20, "Gaussian"
				endif				

# Use the TextGrid to find all segments.
				selectObject: grid_obj
				nr_segments = Get number of intervals: tier
				nr_measured_segments = 0			

# go thru all segments
				for i_segment from 1 to nr_segments
					selectObject: grid_obj
					interval_label$ = Get label of interval: tier, i_segment
					
# find center and measure length
					t1 = Get starting point: tier, i_segment
					t3 = Get end point:      tier, i_segment
					t2 = (t1 + t3) / 2
					duration = t3 - t1
					duration_ms = duration * 1000

# warn about very long intervals
					if (means and (duration > max_length))
						if (!user_feedback)
							print 'newline$'File 'base_name$' 
						endif
						printline – has a segment longer than 'max_length' seconds.
					endif
#
# check whether this segment should be reported
#
					d_flag = 0
					i_flag = 0
					n_flag = 0
#
# check whether this data should be reported
#

### check label
					l_flag = 0

# report all intervals
					if (label_flag = label_none)
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
						call IsFricative interval_label$ l_flag

# impossible
					else
						printline Impossible label_flag: 'label_flag'. Script aborted.
						exit
					endif

### check for minimal duration
					d_flag = (duration_ms > minimal_length_ms)

### check for intensity (intensity is always needed for report)
					selectObject: intensity_obj
					intensity_mean = 'np_string$' Get mean: t1, t3, "energy"
					i_flag = (intensity_mean > min_intensity)

### check whether all conditions are met
					if (l_flag + d_flag + i_flag = 3)
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
#
# cut out one interval and compute spectrum from it
#
						if (center_position)
							out_line$ += "'tab$''t2:04'"
							selectObject: spectrogram_obj
							spectrum_obj = 'np_string$' To Spectrum (slice): t2
							if (m_request)
								mean = Get centre of gravity... 2
								stdev = Get standard deviation... 2
								skew = Get skewness... 2
								kurt = Get kurtosis... 2
								call PrintValue mean
								call PrintValue stdev
								call PrintValue skew
								call PrintValue kurt
							endif
							if (p_request)
								ltas_obj = 'np_string$' To Ltas (1-to-1)
								peak_freq = Get frequency of maximum: 0, 0, "None"
								call PrintValue peak_freq
							endif
							removeObject: spectrum_obj, ltas_obj						
#@@ other measures here!
						endif
						
						if (means)
							selectObject: wav_obj
							part_obj = Extract part: t1, t3, "Rectangular", 1, "yes"
							spectrum_obj = 'np_string$' To Spectrum: "yes"
							if (m_request)
								mean = Get centre of gravity... 2
								stdev = Get standard deviation... 2
								skew = Get skewness... 2
								kurt = Get kurtosis... 2
								call PrintValue mean
								call PrintValue stdev
								call PrintValue skew
								call PrintValue kurt
							endif
							if (p_request)
								ltas_obj = To Ltas (1-to-1)
								peak_freq = Get frequency of maximum: 0, 0, "None"
								call PrintValue peak_freq
								removeObject: ltas_obj
							endif
							removeObject: part_obj, spectrum_obj
#@@ other measures here!
						endif

# all computations done for one segment
						fileappend 'result_file_name$' 'out_line$''newline$'

# label, duration, pitch and intensity requirements of the interval are not met
# report interval with missing info depending on 'report_skipped_intervals' and 'l_flag'
# either all, or only if label$ is okay or none
#@@ put this up for all cases (if l_flag + = 3 or this if)
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
						out_line$ += skip_line$
						fileappend 'result_file_name$' 'out_line$''newline$'

# label, duration and intensity test
					endif
				
# going thru all segments of a TextGrid	
				endfor
				removeObject: wav_obj, intensity_obj
				if (center_position)
					removeObject: spectrogram_obj
				endif

# entertain user and clean up
				tot_segments += nr_measured_segments
				if (user_feedback)
					perc = (i_file/nr_grid_files) * 100
					printline with 'nr_measured_segments' segments finished ('perc:2'%).
				endif

# no wav file found
			else
				if (!user_feedback)
					print 'base_name$' 
				endif
				printline has no 'ext$' file. File skipped. ***
			endif

# tier is not an interval tier
		else
			if (!user_feedback)
				printline File 'base_name$' skipped since tier 'tier' is not an interval tier.
			else
				printline skipped since tier 'tier' is not an interval tier.
			endif
		endif

# requested tier does not exist
	else
		if (!user_feedback)
			print 'base_name$' 
		endif
		printline has only 'nr_tiers' tiers. File skipped. ***
	endif

# going thru all TextGrid files
	removeObject: grid_obj
endfor

# clean up

removeObject: grid_list_obj, fricative_obj

call ReportAnalysisParameter

# inform user that we are done.
nr_no_wav = nr_grid - nr_wav
printline 'newline$''nr_wav' files with a total of 'tot_segments' segments processed.
if (nr_no_wav)
	printline 'nr_no_wav' files not processed since there were no wav files.
endif
if (nr_low_rate)
	printline 'nr_low_rate' files had sampling rates too low for the upper boundary of 'highest_frequency' Hz.
	printline These files are processed, but be aware of the effects on the data.
endif
printline Results are written to 'directory$''result_file_name$'. 'newline$'Program completed.


# Procedure to print values

procedure PrintValue value
	if value <> undefined
		out_line$ += "'tab$''value:2'"
	else
		out_line$ += missing_values$
	endif
endproc

##
# check and recode user input
##

procedure CheckParameters

# check whether anything is selected at all
	if (center_position+means = 0)
		printline Neither Center position nor Means are selected: no data computed.
		exit
	endif

# check time and formant parameters (convert to lower case and convert spaces to commas first)
	parameters$ = replace_regex$ (parameters$, ".", "\L&", 0)
	parameters$ = replace_regex$ (parameters$, " ", ",", 0)
	help_obj = Create Strings as tokens: parameters$, " ,"
	help2_obj = To WordList
##	(m)odes, spectral (p)eak, (s)lopes, (t)abulate spectra, (g)raph dump, 
	g_request = Has word: "g"
	m_request = Has word: "m"
	p_request = Has word: "p"
	s_request = Has word: "s"
	t_request = Has word: "t"
	removeObject: help_obj, help2_obj

### check which segments are to be analyzed; set constants first:
# <nil> => all
	label_none = 0

# . => only labeled segments
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
		list_obj = To WordList
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
		list_obj = To WordList
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
	result_file_name$ = result_directory$+"spectrum_results_"+date_time$+".txt"

# create header, dummy and missing data lines (first part is always there, so no missing data needed)
	out_line$ = ""
	dummy_line$ = ""
	if (path_name)
		out_line$ += "Path'tab$'"
		dummy_line$ += "'wav_directory$''tab$'"
	endif
	out_line$ += "File'tab$'Label'tab$'Start(s)"
	if (duration_in_ms)
		out_line$ += "'tab$'Duration(ms)"
	else
		out_line$ += "'tab$'Duration(s)"
	endif
	out_line$ += "'tab$'Intensity_mean(dB)"
	dummy_line$ += "Dummy'tab$'Dummy'tab$'0.0'tab$'0.0'tab$'0.0"
	remove_from_dummy$ = dummy_line$

	if (center_position)
		out_line$ += "'tab$'time(s)"
		dummy_line$ += "'tab$'0.0"
		if (m_request)
			out_line$ += "'tab$'CoG(Hz)'tab$'StDev(Hz)'tab$'Skewness'tab$'Kurtosis"
			dummy_line$ += "'tab$'0.0'tab$'0.0'tab$'0.0'tab$'0.0"
		endif
		if (p_request)
			out_line$ += "'tab$'Peak(Hz)"
			dummy_line$ += "'tab$'0.0"
		endif
		if (s_request)
			out_line$ += "'tab$'Low_slope(dB/Hz)'tab$'High_slope(dB/Hz)'tab$'Diff_slope(dB/Hz)"
			dummy_line$ += "'tab$'0.0'tab$'0.0'tab$'0.0"
		endif
	endif

	if (means)
		if (m_request)
			out_line$ += "'tab$'mCoG(Hz)'tab$'mStDev(Hz)'tab$'mSkewness'tab$'mKurtosis"
			dummy_line$ += "'tab$'0.0'tab$'0.0'tab$'0.0'tab$'0.0"
		endif
		if (p_request)
			out_line$ += "'tab$'mPeak(Hz)"
			dummy_line$ += "'tab$'0.0"
		endif
		if (s_request)
			out_line$ += "'tab$'mLow_slope(dB/Hz)'tab$'mHigh_slope(dB/Hz)'tab$'mDiff_slope(dB/Hz)"
			dummy_line$ += "'tab$'0.0'tab$'0.0'tab$'0.0"
		endif
	endif

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
		printline Impossible label_flag in IsVowel: 'label_flag'. Script aborted.
		exit
	endif

	selectObject: fricative_obj
	l_flag = Has word: local_label$
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
	out_line$ += "Tier: 'tier_to_be_analysed''newline$'"
	out_line$ += "Labels: 'label$''newline$'"	
	out_line$ += "Minimal length: 'minimal_length_ms' ms'newline$'"	
	out_line$ += "Minimal intensity: 'minimal_intensity' dB'newline$'"	
	out_line$ += "High pass filter frequency: 'high_pass_filter_frequency' Hz'newline$'"	
	out_line$ += "Highest frequency: 'highest_frequency' Hz'newline$'"	
	out_line$ += "Window size for spectrograms: 'window_size' s'newline$'"
	fileappend 'result_file_name$' 'out_line$'
endproc

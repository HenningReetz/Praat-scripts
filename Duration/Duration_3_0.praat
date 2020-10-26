##
#	This script computes the durations of either
#	(a) all sounds files in a directory or
#	(b) all labeled segments of all wav-soundfiles in a directory.
#
#  	Vers. 1.0, Henning Reetz, 01-aug-2007
#	Vers. 1.1, Henning Reetz, ???; ???
#	Vers. 1.2, Henning Reetz, 13-jun-2009; only minor adjustments
#	Vers. 2.0, Henning Reetz, 09-dec-2014; adjusted to new Praat script syntax; handling directory names without "/" at the end
#	Vers. 2.1, Henning Reetz, 16-dec-2014; 'selectObject:' added
#	Vers. 3.0, Henning Reetz, 25-jul-2020; new extended features
#
#	Tested with Praat 6.1.12
#
##


clearinfo

#
## 1) Inquire some parameters
## ! Note that 'form' may only be used once in a script!
#

form Duration parameters:
	comment Leave the directory path empty if you want to use the current directory.
	word directory
	comment __________________________________________________________________________________________________
	comment Which tier should be measured (0 = whole file)?
		integer Tier 1
	comment ______________________________________________________________________________________________________________
	comment In case you selected a tier, which intervals/points should be reported:
	comment <labels>, <list>.txt, '.' (= only labelled), or empty (= all)
		sentence Label pcl,tcl,kcl,p,t,k
	comment Handling of missing data
		boolean Report_missing false
		word Missing_value_symbol NA
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

# directories for .TextGrid, result- and support-files (must end with a slash "/"!
wav_directory$ = directory$
grid_directory$ = directory$
result_directory$ = directory$
support_directory$ = directory$

# Examples (for being one directory above the 4 sub-directories):
# In case you want the path for the .wav file in the output, set 'path_name' to 1
#	wav_directory$ = "./Wav/"
#	grid_directory$ = "./Grid/"
#	result_directory$ = "./Result/"
#	support_directory$ = "./Support/"

# input is either wav of grid, but not both; recode, in case different directories are used
if (tier = 0)
	directory$ = wav_directory$
else
	directory$ = grid_directory$
endif

# extension of the audio files
audio_ext$ = ".wav"

# should the name of the diectory path be reported (path_name = 1) or not (path_name = 0)
path_name = 0

# should there be only minimal user feedback to speed up processing (= 0) or not (= 1)
user_feedback = 1

# should there be a dummy data header to force correct data type in JMP or other tables (= 1) or not (= 0)
dummy_data_header = 0

# report duration in ms (duration_in_ms = 1) or seconds (duration_in_ms = 0)
duration_in_ms = 1

# use audio- or TextGrid file extension
if (tier = 0)
	ext$ = audio_ext$
else
	ext$ = ".TextGrid"
endif

##
# 4) check parameters (especialy the labe string
##

call CheckParameters


##
# 4) Create result file
##

call CreateResultFile


##
#  5) Get file names from a directory
##

# nr. of files that have been processed
nr_grid = 0

# total nr. of segments/points of all files
tot_segments = 0

# create list of .wav or .TextGrid files

file_list_obj = Create Strings as file list: "file_list", "'directory$'*'ext$'"
nr_files = Get number of strings

# Give minimal user feedback
if (!user_feedback)
	print "Computing... "
endif

##
# 5) Go thru all files
##

for i_file to nr_files
	selectObject: file_list_obj
	file_name$ = Get string... i_file
	base_name$ = replace_regex$(file_name$,"'ext$'$","",1)
	file_obj = Read from file: "'directory$''file_name$'"
	if (user_feedback)
		print "Handling 'base_name$' "
	endif

# get only length of whole file
	if tier = 0
		duration = Get total duration
		if (duration_in_ms)
			duration *= 1000
			fileappend 'result_file_name$' 'base_name$''tab$''duration:1''newline$'
		else
			fileappend 'result_file_name$' 'base_name$''tab$''duration:4''newline$'
		endif

# get length of all segments of one textgrid
	else

# check whether the selected tier number is not too large.
		max_tier = Get number of tiers
		tier_is_interval = 0
		if tier <= max_tier
			tier_is_interval = Is interval tier: 'tier'

# use 'type$' string to process intervals and points with the same loop
# (i use the name 'segment' and 'interval' for both in the subsequent processing , even if it is a  point)
			if  (tier_is_interval)
				type$ = "interval"
			else
				type$ = "point"
			endif

# Use the TextGrid to find all segments/points.
			nr_segments = Get number of 'type$'s: tier
			nr_measured_segments = 0
##
# handle interval tier
##
			for i to nr_segments
				interval_label$ = Get label of 'type$'... tier i
### check label
				l_flag = 0
# report all intervals/points
				if (label_flag = label_none)
					l_flag = 1
# report list of labels
				elsif (label_flag = label_list)
					selectObject: label_list_obj
					l_flag = Has word: interval_label$
					selectObject: file_obj
# report all labeled  intervals/points
				elsif (label_flag = label_any)
					l_flag = (interval_label$ <> "")
# impossible
				else
					printline Impossible label_flag: 'label_flag'. Script aborted.
					exit
				endif
#
# okay, this segment/point should be reported
#
				if (l_flag)
					nr_measured_segments += 1
					if (path_name)
						fileappend 'result_file_name$' 'directory$''tab$'
					endif

# measure length of interval
					if (tier_is_interval)
						begin_segment = Get starting point: tier, i
						end_segment   = Get end point:      tier, i
						duration = (end_segment - begin_segment)
# report length
						if (duration_in_ms)
							duration *= 1000
							fileappend 'result_file_name$' 'base_name$''tab$''interval_label$''tab$''begin_segment:4''tab$''duration:1''newline$'
						else
							fileappend 'result_file_name$' 'base_name$''tab$''interval_label$''tab$''begin_segment:4''tab$''duration:4''newline$'
						endif

# report only time of point
					else
						begin_segment = Get time of point: tier, i
						fileappend 'result_file_name$' 'base_name$''tab$''interval_label$''tab$''begin_segment:4''tab$''missing_value_symbol$''newline$'
					endif

# label should be reported (i.e. l_flag <> 0)
					endif
# going thru all intervals
				endfor

# report files without matching items if requuested
				if (report_missing and !nr_measured_segments)
					fileappend 'result_file_name$' 'base_name$''tab$''missing_value_symbol$''tab$''missing_value_symbol$''tab$''missing_value_symbol$''newline$'
				endif
# entertain user
				tot_segments += nr_measured_segments
				if (user_feedback)
					percent = 100 * i_file/nr_files
					printline with 'nr_measured_segments' segments finished. ('percent:2'% processed).
				endif

# requested tier was beyong maximal number of tiers
		else
			if (!user_feedback)
				print "'new_line$'Handling 'base_anme$' "
			endif
			printline failed: Only 'max_tier' tiers but tier 'tier' requested.
		endif

# test whether whole file or individual segments are reported
	endif

# remove file from object list
	removeObject: file_obj

# going thru all files
endfor

# clean up

if (label_flag = label_list)
	removeObject: label_list_obj
endif
removeObject: file_list_obj

# write analysis parameter to output file
call ReportAnalysisParameter

# inform user that we are done.
if tier = 0
	printline 'newline$''nr_files' files processed.
else
	printline 'newline$''nr_files' files with a total of 'tot_segments' segments/points processed.
endif

printline Results are written to 'result_file_name$'. 'newline$'Program completed.'newline$'


##
# check and recode user input
##

procedure CheckParameters

### check which segments are to be analyzed; set constants first:
# <nil> => all
	label_none = 0

# . => only labeled segments
	label_any = 1

# label.txt or label(s)
	label_list = 2


### now recode the request
# get lowercase name to make file search easier
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
endproc



##
#	Create resultfile
##

procedure CreateResultFile

# create file name with date and time
	call GetDate date_time$
	result_file_name$ = result_directory$+"duration_results_"+date_time$+".txt"

# create header, dummy and missing data lines (first part is always there, so no missing data needed)
	out_line$ = ""
	dummy_line$ = ""
	skip_line$ = ""
	if (path_name)
		out_line$ += "Path'tab$'"
		dummy_line$ += "'directory$''tab$'"
	endif
	if (tier = 0)
		out_line$ += "File"
		dummy_line$ += "Dummy"
	else
		out_line$ += "File'tab$'Label'tab$'Start(s)"
		dummy_line$ += "Dummy'tab$'Dummy'tab$'0.0"
		skip_line$ += "'tab$''missing_value_symbol$''tab$''missing_value_symbol$'"
	endif
	if (duration_in_ms)
		out_line$ += "'tab$'Duration(ms)"
	else
		out_line$ += "'tab$'Duration(s)"
	endif
	dummy_line$ += "'tab$'0.0"
	skip_line$ += "'tab$''missing_value_symbol$'"

# write header line
	fileappend 'result_file_name$' 'out_line$''newline$'

# add dummy line (if requested)
	if (dummy_data_header)
		fileappend 'result_file_name$' 'dummy_line$''newline$'
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
		out_line$ += "Path for files: 'directory$''newline$'"
	endif
	if (tier = 0)
		out_line$ += "Whole files analysed (no TextGrids used)'newline$'"
	else
		out_line$ += "Tier: 'tier''newline$'"
		out_line$ += "Labels: 'label$''newline$'"
	endif
	fileappend 'result_file_name$' 'out_line$'
endproc

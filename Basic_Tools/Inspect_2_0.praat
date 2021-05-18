##
#	This script opens each sound (and its .TextGrid) file, and moves
#   to a specific part of the signal with a specific window size.
#	The sequence of files (and their data) are given by the .txt output file of my Formants, Duration or Pitch scripts.
#	or can be given in many other ways (see Inspect_manual.pdf)
#	This script creates a file "Inspect_progress_file_V01.txt" to handle the skipping of .wav/.TextGrid files
#	that have already been inspected (in a previous session).
#
#  	Version 0.0, Henning Reetz, 18-jan-2019
#  	Version 0.1, Henning Reetz, 10-jun-2019, 'previous' option, skip already viewed segements
#  	Version 0.2, Henning Reetz, 18-mar-2020, open every file only once (not a good solution)
#  	Version 0.4, Henning Reetz, 20-mar-2020, do not re-open files with same name and start time; relative window times
#  	Version 1.0, Henning Reetz, 30-apr-2020, allow empty file list (= all sound files) and more strings for file, start, duration
#  	Version 2.0, Henning Reetz, 17-may-2020, re-writing of most of the code; new 'progress file' mechanics
#
#	Tested with Praat 6.1.43
##
##@@ handling of full path names given in result file
##@@ insert entertainment at the beginning if it takes a while…
##@@ do not restrict search to one tier when labels are given

version = 2
revision = 0
bugfix = 0

# clear feedback window
clearinfo

##########################################################################################
#
#	1) First preset several strings and parameters
#	Note that the 'result_file$' is the output of a previously run analysis - not a result of this script!
#
##########################################################################################

##########
# Define directories that are needed.
# I use the directory where the script was started for everything, but users might be more organized.
# Directory names are empty or must end with a slash "/"
# Define also the sound-file extension.
# ! Watch out: directories' specifications may change after user input; search for ###>>> below
##########

support_directory$ = ""

# extension of the audio files
sound_ext$ = ".wav"


##########
# Create a list of words that are used by a 'result_file$'
# The next 5 code lines define the words in the header of result file that are needed to find
# the related columns. Note that either 'duration_string$' or 'end_string$' can be used,
# but not both at the same time. 'label_string$' is optional.
# (see Inpect_manual.pdf for documentation)
# The pre-setting of "result_header'i_col'$" is used later in the script to generate a hash
# with the column name (e.g. "File") pointing to the column (e.g. "2"):
#    hash[File] = 2
# This is only done to be able to access the columns by name, rather than using its number.
##########

file_string$ = "File"
label_string$ = "Label"
start_string$ = "Start(s)"
duration_string$ = "Duration(ms)"
end_string$ = ""
# duration in the result file is given in in milliseconds or seconds
#	duration_is_ms = 0	seconds
#	duration_is_ms = 1	milliseconds
duration_is_ms = 1

# make a tab-delimited string of the header items
result_header_items$ = file_string$ + tab$ + label_string$ + tab$ + start_string$ + tab$ + duration_string$ + end_string$
# use this string to put the words on a line-by-line basis
Create Strings from tokens: "help", result_header_items$, tab$
max_result_header = Get number of strings
# now copy the words into an array that will be used later for searching the header items
for i_col to max_result_header
	result_header_'i_col'$ = Get string: i_col
endfor
# mark wether label, duration, or end are there
result_has_label = (label_string$ <> "")
result_has_duration = (duration_string$ <> "")
result_has_end = (end_string$ <> "")
# either end or duration are allowed, not both
if (result_has_end and result_has_duration)
	printline "Duration" and "End" time for result file header specified. Use either one or the other.
	printline Process aborted.
	exit
endif
# we don't need the String we just created anymore
Remove

##########
# Create a header for the progress file.
# We could use the strings where they are needed, but it is more flexible to just
# define them once here, and use the variables in the script later
##########

# Names and locations of progress files
progress_file_name$ = "'support_directory$'000_Inspect_progress_file_V01.txt"

# Create header of progress file
progress_state$ = "state"
progress_file$ = "file"
progress_start$ = "start"
progress_end$ = "end"
progress_cursor$ = "cursor"
progress_header$ = progress_state$ + tab$ + progress_file$ + tab$ + progress_start$ + tab$ + progress_end$ + tab$ + progress_cursor$

# preset all object variables with 0 to remove all objects easily
# (if might be very hard to find out, which objects are there during runtime)
file_list_obj = 0
help_obj = 0
label_list_obj = 0
progress_obj = 0


##########################################################################################
#
#	2) In case there is no progress file, inquire parameters
#		(do not use 'form' since it comes always up).
#
##########################################################################################

files$ = "g071a000"
labels$ = "a:"
tier$ = "4"
window$ = "50"

# on smaller errors, the user can change the change parameters

label restart
if (!fileReadable(progress_file_name$))
	beginPause: "Inspect parameters:"
		comment: "Leave the directory path for 'sound_ext$' files empty if you want to use the current directory."
			word: "Directory", ""
		comment: "__________________________________________________________________________________"
		comment: "Sound files (list) or result file of analysis:"
			sentence: "Files", files$
		comment: "Label(s) or center time"
			sentence: "Labels", labels$
		comment: "Tier number in case you want to select labels from TextGrids:"
			word: "Tier", tier$
		comment: "(Additional) window size in ms:"
			word: "Window", window$
		comment: "__________________________________________________________________________________"
		comment: "Always use default parameter settings?"
			boolean: "Default", 0
	clicked = endPause: "Stop", "Continue", 2, 1

# clear feedback window (again - to remove old error messages)
	clearinfo

	if (clicked = 1)
		printline Script aborted by user.
		exit
	endif

# directory specifications

	if (directory$ = "")
		directory$ = "./"
	elsif (not endsWith(directory$,"/"))
		directory$ = directory$ + "/"
	endif
	sound_directory$ = directory$
	grid_directory$ = directory$
	result_directory$ = directory$

# I use strings for numerals to allow empty fileds; convert them to a number here
# 	and change window ms time to seconds
	tier = number(tier$)
	window = number(window$)
	window = window / 1000

##########
#	2) Analyse the specification because that controls how the script will handle data
#	Convert the data given here in the progress file format, which will be used to run the script
#	First check the fields and generate variables and set flags
#	If the general syntax is okay, create the progress table
##########

	call CheckFileField
	call CheckLabelField
	call CheckTimeField

# Create progress file header
	nr_progress_lines = 0
	progress_obj = Create Table with column names: "progress_table", nr_progress_lines, progress_header$

##
# 2.1) Sound files given
##
	if (file_flag = file_sound)

# go thru all sound files
		for i_file to nr_files
			selectObject: file_list_obj
			sound_name$ = Get string: i_file
			base_name$ = replace_regex$(sound_name$,"'sound_ext$'$","",1)

# 2.1.1) if 'labels$' is empty then show all sound files
			if (label_flag = label_none)
# fill progress table with data
				start = 0
				end = window
				cursor = (start + end) / 2
				call AddProgressLine
				goto next_sound_file

# 2.1.2) if the label is actually a time, treat it like a point marker
			elsif (label_flag = label_time)
				selectObject: label_list_obj
				nr_strings = Get number of strings
				for i_string to nr_strings
					string$ = Get string: i_string
					cursor = number(string$)
					start = cursor - window/2
					end = cursor + window/2
					call AddProgressLine
				endfor
				goto next_sound_file
			endif

# 2.1.3) labels$ given, use it to filter cases
# when labels are specified, there must be a tier specification
			if (tier$ = "")
				printline No tier specification for labels. Please define the tier to use.
				call RemoveObjects
				goto restart
			endif

# get the TextGrid file to look for labels
			grid_name$ = grid_directory$ + base_name$ + ".TextGrid"
			grid_exists = fileReadable(grid_name$)
			if (!grid_exists)
				help$ = replace_regex$(grid_name$,"^\./","",1)
				printline No file 'help$' found. File skipped.
				goto next_sound_file
			endif
			grid_obj = Read from file: grid_name$
			nr_tiers = Get number of tiers

# specific tier does not exist?
			if (tier > nr_tiers)
				help$ = replace_regex$(grid_name$,"^\./","",1)
				printline File 'help$' has only 'nr_tiers' tiers, but tier 'tier' was requested.
				printline File 'help$' will be skipped.
				goto next_grid_file
			endif

# tier can be interval tier or point tier
# write the code so that it works for both without too much special handling
# e.g. instead of
#	Get number of intervals:
# use
# 	type$ = "interval"
#	Get number of 'type$'s:
# (Note the final 's' which is sometimes there)
# Furthermore, I use 'interval' for my variable names, although they can be points
			tier_is_interval = Is interval tier: tier
			if (tier_is_interval)
				type$ = "interval"
			else
				type$ = "point"
			endif

# go thru all intervals in one TextGrid
			nr_intervals = Get number of 'type$'s: tier
			for i_interval to nr_intervals
				selectObject: grid_obj

# check whether label matches required labels
				label$ = Get label of 'type$': tier, i_interval
				if (label_flag = label_list)
					selectObject: label_list_obj
					label_exists = Has word: label$
					selectObject: grid_obj
				elsif (label_flag = label_any)
					label_exists = (label$ <> "")
				else
					printline Fatal programming error. Illegal label_flag: 'label_flag'.
					printline Processing aborted.
					exit
				endif

# fitting label found
				if (label_exists)
					if (tier_is_interval)
						start = Get start time of interval: tier, i_interval
						end = Get end time of interval: tier, i_interval
						start -= window
						end += window
						cursor = (start + end) / 2
					else
						cursor = Get time of point: tier, i_interval
						start = cursor - window/2
						end = cursor + window/2
					endif

					call AddProgressLine
				endif

# going thru all intervals
			endfor

label next_grid_file
			removeObject: grid_obj
label next_sound_file
		endfor

##
# 2.2) result file given
##

# 'result_table_obj' is actually already a table with a header!
	elsif (file_flag = file_result)

# check whether labels should be filtered but the result_file$ has no labels
		if ((label_flag <> label_none) and !result_has_label)
			help$ = replace_regex$(file$,"^\./","",1)
			printline Labels specified but the result file 'help$' has no 'label_string$' column.
			printline Processing aborted.
			exit
		endif

		selectObject: result_table_obj
		nr_rows = Get number of rows

# preset mechanisme to avoid identical lines
# (identical lines can happen when the result file lists several measures for the same
#  intervals/points on separate lines)
		last_file$ = ""
		last_start = 0
		last_end = 0

# search for fitting labels (even if no labels are required)
		for i_row to nr_rows
			selectObject: result_table_obj

# no label specification, so be pretend label specification is okay
			if (label_flag = label_none)
				label_exists = 1

# labels$ are specified, so compare
			else
				label$ = Get value: i_row, label_string$
				if (label_flag = label_list)
					selectObject: label_list_obj
					label_exists = Has word: label$
				elsif (label_flag = label_any)
					label_exists = (label$ <> "")
				else
					printline Fatal programming error. Illegal label_flag: 'label_flag'.
					printline Processing aborted.
					exit
				endif
# labels are specified or not
			endif

# fitting label found (this is also true if no label specifications are given!)
			if (label_exists)
				selectObject: result_table_obj
				sound_name$ = Get value: i_row, file_string$
				base_name$ = replace_regex$(sound_name$,"'sound_ext$'$","",1)
				start = Get value: i_row, start_string$
				if (result_has_end)
					end = Get value: i_row, end_string$
				elsif (result_has_duration)
					duration = Get value: i_row, duration_string$
					if (duration_is_ms)
						duration /= 1000
					endif
					end = start + duration
# neither End nor Duration given -- assume it is a point
				else
				endif
				start -= window
				end += window
				cursor = (start+end)/2

				if ((last_file$ <> sound_name$) or (last_start <> start) or (last_end <> end))
					call AddProgressLine
					last_file$ = sound_name$
					last_start = start
					last_end = end
				endif

# label exists
			endif

# going thru all lines of a result file
		endfor
		removeObject: result_table_obj

# illegal file_flag
	else
		printline Fatal programming error. Illegal file_flag: 'file_flag'.
		printline Processing aborted.
		exit
	endif

### Add global parameters to progress_file
	selectObject: progress_obj
	nr_rows = Get number of rows
	if (nr_rows)
		row = 1
		Insert row: row
		Set numeric value: row, "state", 3
		Set numeric value: row, "start", default
		row += 1
		Insert row: row
		Set numeric value: row, "state", 4
		Set string value: row, "file", sound_directory$
		row += 1
		Insert row: row
		Set numeric value: row, "state", 5
		Set string value: row, "file", grid_directory$
		first_row = row + 2
# now mark in row 1 where the real data starts
		row = 1
		Insert row: row
		Set numeric value: row, "state", 2
		Set numeric value: row, "start", first_row
# no files to process
	else
		printline No files to process. Program aborted.
		exit
	endif

##########################################################################################
#
#	3) Progress file exists
#
##########################################################################################

else
	progress_obj = Read from file: progress_file_name$
# get global parameters
	first_row = Get value: 1, "start"
	default = Get value: 2, "start"
	sound_directory$ = Get value: 3, "file"
	grid_directory$ = Get value: 4, "file"
endif

##########################################################################################
#
#	4) Here starts the real action
# 	There is a table with files names, start and end time, a status flag, and cursor information
#	but start and end time can point beyond actual sound file
#
##########################################################################################

nr_handled_items = 0
abort_flag = 0

# go, row by row, through the table
selectObject: progress_obj
nr_rows = Get number of rows
last_file$ = ""

##
# first skip rows that have been handled in a previous session
##

start_row = first_row
repeat
	state = Get value: start_row, progress_state$
	start_row += 1
until (state = 0)
start_row -= 1

##
# now go thru all (unhadled) rows of the progress table
##

for i_row from start_row to nr_rows

	selectObject: progress_obj
	state = Get value: i_row, progress_state$

# for correct handling of previous/next question later, we need to now the status of the next row
	next_row = i_row+1
	if (next_row <= nr_rows)
		next_state = Get value: next_row, progress_state$
	else
		next_state = 0
	endif

# read information from progress table
	base_name$ = Get value: i_row, progress_file$
	start = Get value: i_row, progress_start$
	end = Get value: i_row, progress_end$
	cursor = Get value: i_row, progress_cursor$

# get sound and grid file names
	sound_file$ = sound_directory$ + base_name$ + sound_ext$
	grid_file$ = grid_directory$ + base_name$ + ".TextGrid"

# avoid re-reading sound and TextGrid files
	if (sound_file$ <> last_file$)

# sound file changed. Remove old objects
		if (last_file$ <> "")
			if (sound)
				removeObject: sound_obj
			endif
			if (grid)
				removeObject: grid_obj
			endif
		endif

# Try to read sound and TextGrid files
		if fileReadable(sound_file$)
			sound_obj = Read from file: sound_file$
			sound = 1
			last_file$ = sound_file$
# find out, whether there is a .TextGrid file and open it
			if fileReadable(grid_file$)
				grid_obj = Read from file: grid_file$
				plusObject: sound_obj
				grid = 1
			else
				grid = 0
			endif
		else
			help$ = replace_regex$(sound_file$,"^\./","",1)
			printline No sound file 'help$' found.
			sound = 0
			goto get_next_item
		endif
		last_file$ = sound_file$

	else
		selectObject: sound_obj
		if (grid)
			plusObject: grid_obj
		endif
	endif

#
# display signal (and TextGrid, if it is there)
#

	View & Edit
# reset parameters if required
		if (default)
			Spectrogram settings: 0, 5000, 0.005, 70
			Pitch settings: 75, 500, "Hertz", "autocorrelation", "automatic"
			Formant settings: 5000, 5, 0.025, 30, 1
		endif

		if (grid)
			editor: grid_obj
		else
			editor: sound_obj
		endif

# set display window (if 'last_time' == 'first_time', i.e. window = 0, Praat displays whole file)
		Select: start, end
		Zoom to selection
		Move cursor to: cursor

#pause 'next_state' 'first_row' 'i_row' 'nr_rows'

# enable user interaction
		real_nr_rows = nr_rows - first_row + 1
		real_i_row = i_row - first_row + 1
		beginPause ("Do what ever you want")
			comment: "'real_i_row' of 'real_nr_rows' items"

# To reduce the cluttering of possible situations here
#	(e.g., special handling for first and last row in the table, where no 'Previous' or
#	'Next' row exists) I only present (next to Exit) options to go to the Next or Previous
#	window. In xase the user had done two back skipping, there are to Next options:
#	go to the Next item in the progress table of to the Next non-handled item.
#	The special cases for first/last row and the Exit are handled with 'i_row' checks,
#	not transparent to the user.
# The possible situations that need to be handled are:
#	state	next_state
#	0		0		normal progress, incl. last entry
#	0		1		impossible
#	1		0		in front of unhandled window
#	1		1		inside handled cases
# now generate pause windows according to the situation
#	(I know there is an if-then-else but that would become rather opaque)
# Additionally, I make use of the answer number:
#	1	Exit
#	2	Previous
#	3	Next in progress table (ev. updating present row)
#	4	Find first 'state = 0'

			if (state = 0) or (next_state = 0)
				answer = endPause ("Exit","Previous","Next",3,1)
			elsif (state = 1) and (next_state = 1)
				answer = endPause ("Exit","Previous","Next in list","Next new",3,1)
			else
				printline Impossible situation: state: 'state', next_state: 'next_state'.
				exit
			endif

# close editor window
	Close

# if a TextGrid exists and it is not an 'Exit' update TextGrid and remove it
	if (grid and (answer <> 1))
		selectObject: grid_obj
		Save as text file: grid_file$
	endif

# user wants to end session (force end of for-loop by putting i_row beyond nr_rows)
	if (answer = 1)
		abort_flag = 1
		i_row = nr_rows + 1

# user wants to go backwards (reset 'i_row' by 2 so that after increment by 1 it will be resetted by 1)
	elsif (answer = 2)
		if (i_row > first_row)
			i_row -= 2
		elsif (i_row = first_row)
			i_row -= 1
		else
			printline Impossible 'Previous' situation: i_row: 'i_row', first_row: 'first_row'.
			exit
		endif

# user wants to go one item forward in the list
	elsif (answer = 3)

# if the present window had not been inspected, mark it now as inspected and update progress sile
		if (state = 0)
			selectObject: progress_obj
			Set numeric value: i_row, progress_state$, 1
			Save as tab-separated file: progress_file_name$
			nr_handled_items += 1
		endif

# user wants next untreated item, i.e., the 'next_row' must be 0
#	since the last row must still have a 'state = 0', we are not in danger to move beyond
#	end-of-table
	elsif (answer = 4)
		selectObject: progress_obj
		while (next_state = 1)
			i_row += 1
			next_state = Get value: i_row, progress_state$
		endwhile
		i_row -= 1
	else
		printline Impossible answer: 'answer'.
		exit
	endif

label get_next_item
# handling all items in the progress table
endfor

# remove sound and TextGrid objects
removeObject: sound_obj
if (grid)
	removeObject: grid_obj
endif


if (!abort_flag)
	deleteFile: progress_file_name$
endif
call RemoveObjects

printline Done. 'nr_handled_items' item checked.


##########################################################################################
#
# Procedure to check the 'File' field of the initial form
#
##########################################################################################

procedure CheckFileField

# <nil> => all sound files
	file_all = 0

# sound file (list given)
	file_sound = 1

# result file (list)
	file_result = 2

### now recode the request
# lower case string is sometimes needed
	lc_files$ = replace_regex$ (files$, ".", "\L&", 0)

# report all
	if (files$ = "")

# create list of sound files
		file_list_obj = Create Strings as file list:  "file_list", "'sound_directory$'*'sound_ext$'"
		nr_files = Get number of strings
		file_flag = file_sound

# report a list of sound files or use data from a result file
	elsif (endsWith(lc_files$,".txt"))
		files$ = support_directory$+files$
		if (not fileReadable (files$))
			help$ = replace_regex$(file$,"^\./","",1)
			printline File 'help$' not found. Please correct input.
			call RemoveObjects
			goto restart
		endif
		file_list_obj = Read Strings from raw text file: files$
		nr_files = Get number of strings
		if (nr_files < 1)
			help$ = replace_regex$(file$,"^\./","",1)
			printline File 'help$' has no text lines. Script aborted.
			exit
		endif

# find out whether it is just a list of file names (i.e. 1 column) or a result file
		line$ = Get string: 1
		help_obj = Create Table with column names: "input_table", 0, line$
		nr_col = Get number of columns

# if it looks like file name, check whether it is a list of audio files
		if (nr_col = 1)
			removeObject: help_obj
			help_obj = 0
			selectObject: file_list_obj
			for i_line to nr_files
				line$ = Get string: i_line
				lc_help$ = replace_regex$ (line$, ".", "\L&", 0)
				if (not endsWith(line$,sound_ext$))
					line$ += sound_ext$
				endif
				if (not fileReadable(line$))
					help$ = replace_regex$(file$,"^\./","",1)
					printline The file "'help$'" seems not to contain a list of sound file names.
					printline Please correct the input or the file format.
					exit
# it is an audio file. re-store name with extension.
				else
					Set string: i_line, line$
				endif
			endfor
			file_flag = file_sound
# This seems to be a result file
# Check whether all header labels are there
		else
			err = 0
			for i_col to max_result_header
				header_col = Get column index: result_header_'i_col'$
				if (header_col)
					hash[result_header_'i_col'$] = header_col
				else
					help$ = result_header_'i_col'$
					help_file$ = replace_regex$(file$,"^\./","",1)
					printline File "'help_files$'" has no column with the header "'help$'".
					err += 1
				endif
			endfor
			if (err)
				printline Please correct the header specifications in this script.
				exit
			endif
			removeObject: help_obj
			help_obj = 0
			removeObject: file_list_obj
			file_list_obj = 0
			result_table_obj = Read from file: files$
			file_flag = file_result
		endif

# treat input as one or more sound files, separated by comma or spaces
	else
		files$ = replace_regex$ (files$, " ", ",", 0)
		files$ = replace_regex$ (files$, ",,", ",", 0)
		file_list_obj = Create Strings as tokens: files$, " ,"
		nr_files = Get number of strings
		if (nr_files < 1)
			printline No valid file information found. Please correct input.
			call RemoveObjects
			goto restart
		endif
		for i_line to nr_files
			line$ = Get string: i_line
			if (not endsWith(line$,sound_ext$))
				line$ += sound_ext$
			endif
			if (not fileReadable(line$))
				help$ = replace_regex$(files$,"^\./","",1)
				printline The file "'help$'" seems not to be sound file.
				printline Please correct the input or file format.
				call RemoveObjects
				goto restart
# it is an audio file. re-store name with extension.
			else
				Set string: i_line, line$
			endif
		endfor
		file_flag = file_sound
	endif
endproc


##########################################################################################
#
# Procedure to check the 'Label' field of the initial form
#
##########################################################################################

procedure CheckLabelField

# check which intervals are to be analyzed; set constants first:
# <nil> => whole files
	label_none = 0

# . => only labeled intervals
	label_any = 1

# label.txt or label(s)
	label_list = 2

# time
	label_time = 3

### now recode the request
# lower case string is sometimes needed
	lc_labels$ = replace_regex$ (labels$, ".", "\L&", 0)

# report all intervals
	if (labels$ = "")
		label_flag = label_none

# report only labelled intervals
	elsif (labels$ = ".")
		label_flag = label_any

# report labels from a label file or times
	elsif (endsWith(lc_labels$,".txt"))
		labels$ = support_directory$+labels$
		if (not fileReadable (labels$))
			printline Label file "'labels$'" not found. Script aborted.
			exit
		endif
		help_obj = Read Strings from raw text file: labels$
		nr_labels = Get number of strings
		if (nr_labels < 1)
			help$ = replace_regex$(labels$,"^\./","",1)
			printline File "'help$'" has no text lines. Script aborted.
			exit
		endif
		help$ = replace_regex$(labels$,"^\./","",1)
		printline 'nr_labels' labels found in file "'help$'".
		label_list_obj = To WordList
		removeObject: help_obj
		help_obj = 0
		label_flag = label_list

# treat input as one or more labels or times, separated by comma and pretend they come from a label file
	else
		help_obj = Create Strings as tokens: labels$, " "
		nr_labels = Get number of strings
		if (nr_labels < 1)
			printline No valid label information found. Script aborted.
			exit
		endif
# check the all lines to see whether they are all times, otherwise they are all labels
# or a result file is given, then labels are never times
#	(to lazy to do an extra handling for this, I just stick it into the test)
#@@ this fails if the labels are numbers!
		time_flag = 1
		for i_label to nr_labels
			item$ = Get string: i_label
# add a leading 0 if string starts with "."
			item$ = replace_regex$ (item$, "^\.", "0.", 0)
# use the number$ function to find out whether it is a number without Praat crashing
			if ((file_flag = file_result) or (number(item$)=undefined))
# one non-numeric string is enough to declare all as labels
				label_flag = label_list
				label_list_obj = To WordList
				removeObject: help_obj
				help_obj = 0
				i_label = nr_labels + 1
				time_flag = 0
# it's a time; rewrite to add leading 0s
			else
				Set string: i_label, item$
			endif
		endfor
# if the loop left normally, all entries must have been numbers
		if (time_flag)
			label_flag = label_time
			label_list_obj = help_obj
			help_obj = 0
		endif

# test for type of label
	endif

endproc


##########################################################################################
#
# Procedure to check the 'Time' field of the initial form
#
##########################################################################################

procedure CheckTimeField

	window_add = 1
	window_raw = 0

# convert window to a number and check whether it is an additional window size
	if (window$ = "")
		window$ = "0"
	endif
	if (startsWith(window$,"+"))
		window_flag = window_add
	else
		window_flag = window_raw
	endif
	if (window < 0)
		printline Negative window size. Please adjust window size.
		call RemoveObjects
		goto restart
	endif
endproc


##########################################################################################
#
# Procedure to write new progress line
#
##########################################################################################

procedure AddProgressLine
	selectObject: progress_obj
	Append row
	nr_progress_lines += 1
	Set numeric value: nr_progress_lines, progress_state$, 0
	Set string value: nr_progress_lines, progress_file$, base_name$
	Set numeric value: nr_progress_lines, progress_start$, start
	Set numeric value: nr_progress_lines, progress_end$, end
	Set numeric value: nr_progress_lines, progress_cursor$, cursor
endproc


##########################################################################################
#
# Procedure to remove all dangling objects
#
##########################################################################################

procedure RemoveObjects
	if (file_list_obj)
		removeObject: file_list_obj
		file_list_obj = 0
	endif
	if (help_obj)
		removeObject: help_obj
		help_obj = 0
	endif
	if (label_list_obj)
		removeObject: label_list_obj
		label_list_obj = 0
	endif
	if (progress_obj)
		removeObject: progress_obj
		progress_obj = 0
	endif
endproc


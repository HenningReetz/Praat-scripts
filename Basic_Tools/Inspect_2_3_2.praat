##
#	This script should enable to scan quikly through (many) files, intervals, or points
#	to inspect them or to make judgements (like e.g. 'Voiced', 'Voiceless'), add comments,
#	or note them down for later investigation.
#	This script opens sound (and .TextGrid) files, and moves to a specific part of the
#	signal with a specific window size.
#	The sequence of files (and their data) can be specified at startup, or can be given
#	by the .txt output file of my Formants, Duration or Pitch scripts, or can be specified
#	in many other ways (see Inspect_manual.pdf for details).
#	This script creates a file "Inspect_progress_file_V04.txt" to enable the user to leave
#	the script and continue later at the same file/interval/point.
#
#	To change parameters that conytrol the script, search for:
#	"### 1 >>>"	support_directory, sound files' extension, strings on initial (form) window
#	"### 2 >>>"	comments, judgments and notes parameters
#	"### 3 >>>"	header strings for columns in result files form previous analysis
#	"### 4 >>>"	specifications for sound-, TextGrid-, result-directories
#
#  	Version 0.0, Henning Reetz, 18-jan-2019
#  	Version 0.1, Henning Reetz, 10-jun-2019, 'previous' option, skip already viewed segements
#  	Version 0.2, Henning Reetz, 18-mar-2020, open every file only once (not a good solution)
#  	Version 0.4, Henning Reetz, 20-mar-2020, do not re-open files with same name and start time; relative window times
#  	Version 1.0, Henning Reetz, 30-apr-2021, allow empty file list (= all sound files) and more strings for file, start, duration
#  	Version 2.0, Henning Reetz, 17-may-2021, re-writing of most of the code; new 'progress file' mechanics
#  	Version 2.0.1, Henning Reetz, 24-may-2021, correct handling of show whole file (end = 0)
#  	Version 2.0.2, Henning Reetz, 27-ma y-2021, correct handling of result_file with window = 0
#  	Version 2.1.0, Henning Reetz, 07-jun-2021, added options for judgments and comments, new progress-file format
#  	Version 2.2.0, Henning Reetz, 07-jul-2021, added options for notes, new progress-file format
#  	Version 2.3.0, Henning Reetz, 21-oct-2021, commments, notes and judgments file stored in progress file
#  	Version 2.3.1, Henning Reetz, 26-nov-2021, correct computation of praat version compability; ToSoundFile replaced by MakeFileNames
#  	Version 2.3.2, Henning Reetz, 13-jan-2022, ignores empty lines in file lists
#
#	Tested with Praat 6.1.51
##
##@@ insert entertainment at the beginning if it takes a while.
##@@ do not restrict search to one tier when labels are given
##@@ I assume all sound files are in one directory

version = 2
revision = 3
bugfix = 2

# clear feedback window, check Praat version (gets OS too to define orientation of
# 'slash' ('/' or '\') in paths) and get date_time$ to make file names unique
clearinfo
call CheckPraatVersion
call GetDateTime


##########################################################################################
#
# (1) Preset several strings and parameters
#	Note that the 'result_file$' is the output of a previously run analysis - not a result of this script!
#
##########################################################################################

### 1 >>>
#
# a) I use the directory where the script was started for everything, but users might be more organized.
#	The 'support_directory$' is defined here because the script looks for a 'progress_file$'
#	from a previous session. Other directories are specified later and might be changed by
#	user input: search for "### 4 >>>" below
#
# b) The sound-file extension is set here.
#
# c) The parameters ('file$', 'label$', 'tier$', 'window$') that appear in the
#	form-type window are defined here .
#
### 1 >>>

# location of support files, especially the 'progress_file$'
support_directory$ = ""

# extension for the sound files
sound_ext$ = ".wav"

# parameters that are inquired if no progress_file$ has been found
files$ = ""
labels$ = ""
tier$ = ""
window$ = "0"


### 2 >>>
# set comments, notes and judgments flags ('0' disables them)
# The user interaction for 'judgments' are coded in string variables/vectors with the names
# judgment_name$, judgment#$[1], judgment$#[2], ... and nr_judgments:
#	judgment_name$:	string (and variable name) for judgments, e.g. "Voicing"
#	judgment$#[1]:	first choice option (always selected as default), e.g. "Voiced"
#	judgment$#[2]:	second choice option, e.g. "Voiceless"
#	judgment$#[i]:	additional optional choice options, etc.
# The example below is preset to generate a choice field as presented in the Inspect_manual.pdf

# set comments flag
comments_flag = 1

# set notes flag (default_note_selection is set to 0, i.e., 'no note')
notes_flag = 0
default_note_selection = 0

# set judgments flag and define judgements
nr_judgments = 2
judgment_name$ = "Quality"
judgment$# = {"Okay","Click"}

# set a flag to indicate that a report file must be used
# this always generates a reports file name, even if it now reports are requested;
# note that a report file given later will override this string!
reports_flag = comments_flag or notes_flag or nr_judgments
reports_file$ = support_directory$ + "001_Inspect_reports_" + date_time$ + ".txt"


### 3 >>>
# Create a list of words that are used in the header of a 'result_file$' from a previous analysis.
# The next 5 code lines define the words in the header of result file that are needed to find
# the related columns. Note that either 'duration_string$' or 'end_string$' can be used,
# but not both at the same time. 'label_string$' is optional (set to an empty string if not wanted).
# (see Inpect_manual.pdf for documentation)
# The pre-setting of "result_header$#" is used later in the script to generate a hash
# with the column name (e.g. "File") pointing to the column in the file (e.g. "2"):
#    hash[File] = 2
# This is only done to be able to access the columns by name, rather than using its number.

file_string$ = "File"
label_string$ = "Label"
start_string$ = "Start(s)"
duration_string$ = "Duration(ms)"
end_string$ = ""
# duration in the result file is given in in milliseconds or seconds
#	duration_is_ms = 0	seconds
#	duration_is_ms = 1	milliseconds
duration_is_ms = 1

# make a vector of the header items
result_header$# = { file_string$, label_string$, start_string$, duration_string$, end_string$ }

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


##########
# Create a header for the progress file.
# We could use the strings where they are needed, but it is more flexible to just
# define them once here, and use the variables in the script later
##########

# Names and locations of progress and report files
progress_file_name$ = support_directory$ + "000_Inspect_progress_file_V04.txt"

# Create header of progress file
progress_state$ = "State"
progress_file$ = "File"
progress_start$ = "Start(s)"
progress_end$ = "End(s)"
progress_cursor$ = "Cursor(s)"
progress_label$ = "Label"
progress_note$ = "Note"
progress_judgment$ = "Judgment"
progress_comment$ = "Comment"

progress_header$ = progress_state$ + tab$ + progress_file$ + tab$ + progress_start$ + tab$ + progress_end$ + tab$ + progress_cursor$ + tab$ + progress_label$ + tab$ + progress_note$ + tab$ + progress_judgment$ + tab$ + progress_comment$
report_header$ = progress_header$

# preset all object variables with 0 to remove all praat objects easily
# (it might otherwise be very hard to find out, which objects are there during runtime)
file_list_obj = 0
help_obj = 0
label_list_obj = 0
progress_obj = 0


##########################################################################################
#
# (2) In case there is no progress file, inquire parameters
#		(do not use 'form' as it always appears).
#
##########################################################################################

# on smaller errors, the user can change the parameters gain and 'restart'

label restart
if (!fileReadable(progress_file_name$))
	progress_file_exists = 0
	beginPause: "Inspect parameters:"
		comment: "Leave the directory path for 'sound_ext$' files empty if you want to use the current directory."
			word: "Directory", ""
		comment: "__________________________________________________________________________________"
		comment: "Sound files (list), result file of analysis, or reports file:"
			sentence: "Files", files$
		comment: "Label(s) or center time:"
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

### 4 >>> directory specifications
	sound_directory$ = directory$
	grid_directory$ = directory$
	result_directory$ = directory$

# example of of having thing in sub-directories (here: path start from present directory)
#	path$ = "." + slash$
#	sound_directory$ = path$ + "Sound"
#	grid_directory$ = path$ + "Grid"
#	result_directory$ = path$ + "Result"

# make sure all directory names end with a slash
# (AddSlash sets a variable help$, which is the output of the operation)
	call AddSlash 'directory$'
	directory$ = help$
	call AddSlash 'sound_directory$'
	sound_directory$ = help$
	call AddSlash 'grid_directory$'
	grid_directory$ = help$
	call AddSlash 'result_directory$'
	result_directory$ = help$

# I use strings for numerals to allow empty strings; convert them to a number here
	tier = number(tier$)

##########
#	Analyse the specification because that will control how the script will handle data
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

# at the beginning, notes, judgments and comments are not given (independent of notes_flag, nr_judgmemnts, comments_flag)
	note = -1
	judgment$ = ""
	comment$ = ""

###
# (2.1) Sound files given
###
	if (file_flag = file_sound)

# go thru all sound files
		for i_file to nr_files
			selectObject: file_list_obj
			file$ = Get string: i_file
			call MakeFileNames 'file$'

# (2.1.1) if 'labels$' is empty then show all sound files
			if (label_flag = label_none)
# fill progress table with data
				wstart = 0
				wend = 0
				cursor = 0
				label$ = ""
				call AddProgressLine
				goto next_sound_file

# (2.1.2) if the label is actually a time, treat it like a point marker
			elsif (label_flag = label_time)
				selectObject: label_list_obj
				nr_strings = Get number of strings
				for i_string to nr_strings
					string$ = Get string: i_string
					cursor = number(string$)
					wstart = cursor - window/2
					wend = cursor + window/2
					label$ = ""
					call AddProgressLine
				endfor
				goto next_sound_file
			endif

# (2.1.3) labels$ given, use it to filter cases
# get the TextGrid file to look for labels
			grid_file$ = grid_directory$ + base_name$ + ".TextGrid"
			grid_exists = fileReadable(grid_file$)
			if (!grid_exists)
				printline No file 'grid_file$' found. File skipped.
				goto next_sound_file
			endif
			grid_obj = Read from file: grid_file$
			nr_tiers = Get number of tiers

# 	when labels are specified, and there are more than one tier, then there must be a tier specification
			if (nr_tiers = 1)
				tier = 1
			endif
			if (tier$ = "")
				printline No tier specification for labels. Please define the tier to use.
				call RemoveObjects
				goto restart
			endif

# specific tier does not exist?
			if ((tier > nr_tiers) or (nr_tiers <= 0))
				printline File 'grid_file$' has only 'nr_tiers' tiers, but tier 'tier' was requested.
				printline File 'grid_file$' will be skipped.
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
						lstart = Get start time of interval: tier, i_interval
						lend = Get end time of interval: tier, i_interval
						wstart = lstart - window
						wend = lend + window
						cursor = (lstart + lend) / 2
					else
						cursor = Get time of point: tier, i_interval
						wstart = cursor - window/2
						wend = cursor + window/2
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
# (2.2) result file given
##

# 'result_table_obj' is actually already a table with a header!
	elsif (file_flag = file_result)

# check whether labels should be filtered but the result_file$ has no labels
##@@ make this smarter: there might be no label specification by the user; i.e. the result file does not need to have a label column
		if ((label_flag <> label_none) and !result_has_label)
			printline Labels specified but the result file 'grid_file$' has no 'label_string$' column.
			printline Processing aborted.
			exit
		endif

		selectObject: result_table_obj
		nr_rows = Get number of rows

# preset mechanisme to avoid identical lines
# (identical lines can happen when the result file lists several measures for the same
#  intervals/points on separate lines)
		last_sound_file$ = ""
		last_start = 0
		last_end = 0

# search for fitting labels (even if no labels are required)
		for i_row to nr_rows
			selectObject: result_table_obj

# no label specification, so we pretend label specification is okay
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
				file$ = Get value: i_row, file_string$
				call MakeFileNames 'file$'
				lstart = Get value: i_row, start_string$

				if (result_has_end)
					lend = Get value: i_row, end_string$
				elsif (result_has_duration)
					duration = Get value: i_row, duration_string$
					if (duration_is_ms)
						duration /= 1000
					endif
					lend = lstart + duration
# neither End nor Duration given -- assume it is a point
				else
					lend = lstart
				endif
				wstart = lstart - window
				wend = lend + window
				cursor = (lstart+lend)/2

# get label from result file (or set label to empty)
				if (result_has_label)
					label$ = Get value: i_row, label_string$
				else
					label$ = ""
				endif

				if ((last_sound_file$ <> sound_file$) or (last_start <> wstart) or (last_end <> wend))
					call AddProgressLine
					last_sound_file$ = sound_file$
					last_start = wstart
					last_end = wend
				endif

# label exists
			endif

# going thru all lines of a result file
		endfor
		removeObject: result_table_obj

##
# (2.3) report file given
#	The report file has the same format as the progress file and is read in like that.
#	But (a) I remove all entries with state=0 (because there cannot be reports on them),
#	(b) delete a header header row (i.e. state = 99) after reading it because a new progress file
#		will be generated, which, in turn, becomes a new rport file.
#	(c) set the state to 0 (because they should be inspected again), and
#	(d) I create a new reports file (so that the user/supervisor gets a 'history' of reports)
##

	elsif (file_flag = file_report)
		progress_obj = Read from file: files$
# get global parameters
		i_row = 1
		first_row = Get value: i_row, progress_start$
		default = Get value: i_row, progress_end$
		tier = Get value: i_row, progress_cursor$
		sound_directory$ = Get value: i_row, progress_label$
		grid_directory$ = Get value: i_row, progress_judgment$
		result_directory$ = Get value: i_row, progress_comment$
		Remove row: i_row
		notes_flag = Get value: i_row, progress_start$
		nr_judgments = Get value: i_row, progress_end$
		comments_flag = Get value: i_row, progress_cursor$
# do not new read reports file nem to force the creation of a new one!
# (remember that reports_file$ is already defined at the beginning
#		reports_file$ = Get value: i_row, progress_label$
		Remove row: i_row
		if (nr_judgments)
  			judgment_name$ = Get value: i_row, progress_file$
 			Remove row: i_row
			for i_judgment to nr_judgments
				Remove row: i_row
				judgment$#[i_judgment] = Get value: i_row, progress_file$
			endfor
		endif
		first_row = i_row

# scan thru rows and remove rows with state = 0 and set state to others to 0
		nr_rows = Get number of rows
		for i_row from first_row to nr_rows
			state = Get value: i_row, progress_state$
			if (state = 0)
				Remove row: i_row
				i_row -= 1
				nr_rows -= 1
			elsif (state = 1)
				Set numeric value: i_row, progress_state$, 0
			else
				printline Impossible state in 'reports_file$' row 'i_row': 'state')
				exit
			endif
		endfor

# illegal file_flag
	else
		printline Fatal programming error. Illegal file_flag: 'file_flag'.
		printline Processing aborted.
		exit
	endif


###
#	End of file parsing. The progress table has now stored all intervals that should be inspected
#	Add global parameters to progress table, which will be stored as progress_file
###

	selectObject: progress_obj
	nr_rows = Get number of rows
	if (nr_rows)
		i_row = 1
		Insert row: i_row
		Set string value: i_row, progress_file$, "."
		Set numeric value: i_row, progress_state$, 99
		Set numeric value: i_row, progress_end$, default
		Set numeric value: i_row, progress_cursor$, tier
		Set string value: i_row, progress_label$, sound_directory$
		Set string value: i_row, progress_judgment$, grid_directory$
		Set string value: i_row, progress_comment$, result_directory$
		i_row += 1
		Insert row: i_row
		Set string value: i_row, progress_file$, "."
		Set numeric value: i_row, progress_state$, 99
		Set numeric value: i_row, progress_start$, notes_flag
		Set numeric value: i_row, progress_end$, nr_judgments
		Set numeric value: i_row, progress_cursor$, comments_flag
		Set string value: i_row, progress_label$, reports_file$
		if (nr_judgments)
			i_row += 1
			Insert row: i_row
			Set numeric value: i_row, progress_state$, 99
			Set string value: i_row, progress_file$, judgment_name$
			for i_judgment to nr_judgments
				i_row += 1
				Insert row: i_row
				Set numeric value: i_row, progress_state$, 99
				Set string value: i_row, progress_file$, judgment$#[i_judgment]
			endfor
		endif
# now mark where the real data starts
		first_row = i_row + 1
		i_row = 1
		Set numeric value: i_row, progress_start$, first_row
# no files to process
	else
		printline No files to process. Program aborted.
		exit
	endif


##########################################################################################
#
#	(3) Progress file exists
#
##########################################################################################

else
	progress_file_exists = 1
	progress_obj = Read from file: progress_file_name$
# get global parameters
	i_row = 1
	first_row = Get value: i_row, progress_start$
	default = Get value: i_row, progress_end$
	tier = Get value: i_row, progress_cursor$
	sound_directory$ = Get value: i_row, progress_label$
	grid_directory$ = Get value: i_row, progress_judgment$
	result_directory$ = Get value: i_row, progress_comment$

	call AddSlash 'sound_directory$'
	sound_directory$ = help$
	call AddSlash 'grid_directory$'
	grid_directory$ = help$
	call AddSlash 'result_directory$'
	result_directory$ = help$

	i_row += 1
	notes_flag = Get value: i_row, progress_start$
	nr_judgments = Get value: i_row, progress_end$
	comments_flag = Get value: i_row, progress_cursor$
	reports_file$ = Get value: i_row, progress_label$
	if (nr_judgments)
		i_row += 1
		judgment_name$ = Get value: i_row, progress_file$
		for i_judgment to nr_judgments
			i_row += 1
			judgment$#[i_judgment] = Get value: i_row, progress_file$
		endfor
	endif
endif


##########################################################################################
#
#	(4) Here starts the real action
# 	There is a table with files names, start and end time, a status flag, and cursor information
#	but start and end time can point beyond actual sound file
#
##########################################################################################

nr_handled_items = 0
abort_flag = 0

# go, row by row, through the table
selectObject: progress_obj
nr_rows = Get number of rows
last_base_name$ = ""

##
# first skip rows that have been handled in a previous session
##

start_row = first_row
repeat
	state = Get value: start_row, progress_state$
	start_row += 1
until ((state = 0) or (start_row > nr_rows))

if (state = 0)
	start_row -= 1
endif

##
# now go thru all (unhandled) rows of the progress table
##

# no signal or textgrid displayed yet
sound = 0
grid = 0

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
	file$ = Get value: i_row, progress_file$
	call MakeFileNames 'file$'
	wstart = Get value: i_row, progress_start$
	wend = Get value: i_row, progress_end$
	cursor = Get value: i_row, progress_cursor$
	label$ = Get value: i_row, progress_label$
	note_flag = Get value: i_row, progress_note$
	judgment$ = Get value: i_row, progress_judgment$
	comment$ = Get value: i_row, progress_comment$

# get sound and grid file names
	grid_file$ = grid_directory$ + base_name$ + ".TextGrid"

# avoid re-reading sound and TextGrid files
	if (base_name$ <> last_base_name$)

# sound file changed. Remove old objects
		if (last_base_name$ <> "")
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
# find out, whether there is a .TextGrid file and open it
			if fileReadable(grid_file$)
				grid_obj = Read from file: grid_file$
				plusObject: sound_obj
				grid = 1
			else
				grid = 0
			endif
		else
			printline No sound file 'sound_file$' found.
			sound = 0
			grid = 0
			goto get_next_item
		endif
		last_base_name$ = base_name$

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
		if (grid)
			editor: grid_obj
		else
			editor: sound_obj
		endif

# reset parameters if required
		if (default)
			Spectrogram settings: 0, 5000, 0.005, 70
			Pitch settings: 75, 500, "Hertz", "autocorrelation", "automatic"
			Formant settings: 5000, 5, 0.025, 30, 1
		endif

# set display window (if 'last_time' == 'first_time', i.e. window = 0, Praat displays whole file)
		Select: wstart, wend
		Zoom to selection
		Move cursor to: cursor

# enable user interaction
		real_nr_rows = nr_rows - first_row + 1
		real_i_row = i_row - first_row + 1
		beginPause ("Do what ever you want")
			comment: "'real_i_row' of 'real_nr_rows' items"
			if (notes_flag)
				boolean: "Note this down", default_note_selection
			endif
			if (comments_flag)
				text: "Comment", comment$
			endif
			if (nr_judgments)
				judgment_default = 1
# if judgment already made, this loop will set judgment_default to that value
				for i to nr_judgments
	    			if (judgment$ = judgment$#[i])
	    	    	  	judgment_default = i
					endif
				endfor
				choice: judgment_name$, judgment_default
					for i to nr_judgments
	    	      		option: judgment$#[i]
					endfor
			endif

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
#
			if (state = 0) or (next_state = 0)
				answer = endPause ("Exit","Previous","Next",3,1)
			elsif (state = 1) and (next_state = 1)
				answer = endPause ("Exit","Previous","Next in list","Next new",3,1)
			else
				printline Impossible situation: state: 'state', next_state: 'next_state'.
				exit
			endif

			cursor = Get cursor
			info$ = Editor info
			wstart = extractNumber (info$, "Window start: ")
			wend = extractNumber (info$, "Window end: ")
# close editor window
	Close

###
# user wants to end session (force end of for-loop by putting i_row beyond nr_rows)
###

	if (answer = 1)
		abort_flag = 1
		i_row = nr_rows + 1
		goto get_next_item
	endif

###
# user wants to go forwards or backwards.
# save data first
###

# update TextGrid
	if (grid)
		selectObject: grid_obj
		Save as text file: grid_file$
	endif

###
# handle now user forward/backward request
# user wants to go backwards (reset 'i_row' by 2 so that after increment by 1 it will be resetted by 1)
###
	if (answer = 2)
		if (i_row > first_row)
			i_row -= 2
		elsif (i_row = first_row)
			i_row -= 1
		else
			printline Impossible 'Previous' situation: i_row: 'i_row', first_row: 'first_row'.
			exit
		endif

# user wants to go one item forward in the list; save any decisions
	elsif (answer = 3)
		selectObject: progress_obj

# save notes
		if (notes_flag)
			Set numeric value: i_row, progress_note$, note_this_down
		endif

# save judgment
		if (nr_judgments)
# make sure the first letter of the string is lower case and convert all non-alphanumeric
# symbols to underline because it will be used as a variable name
			variable_name$ = replace_regex$ (judgment_name$, "^.", "\L&", 1)
			variable_name$ = replace_regex$ (variable_name$, "\W", "_", 0)
# get the value of the variable with the name variable_name$ - this is the number of the selected option
			selected_option = 'variable_name$'
# now store this information
			Set string value: i_row, progress_judgment$, judgment$#[selected_option]
		endif

# save comments
		if (comments_flag)
			Set string value: i_row, progress_comment$, comment$
		endif

# if the present window had not been inspected, mark it now as inspected
		if (state = 0)
			Set numeric value: i_row, progress_state$, 1
			nr_handled_items += 1
		endif
#  update always progress sile
		Save as tab-separated file: progress_file_name$

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

# handling all items in the progress table
	label get_next_item
endfor

# remove sound and TextGrid objects
if (sound)
	removeObject: sound_obj
endif
if (grid)
	removeObject: grid_obj
endif

if (progress_file_exists)
	handling$ = "updated"
else
	handling$ = "created"
endif

# create/update report file
# report only rows of the progresstable where either a note, comment of judgment is made
if (reports_flag)
	selectObject: progress_obj
	nr_rows = Get number of rows
	for i_row from first_row to nr_rows
		if (notes_flag)
			note = Get value: i_row, progress_note$
		else
			note = 0
		endif
		if (nr_judgments)
			judgment$ = Get value: i_row, progress_judgment$
			judgment = 1
		else
			judgment = 0
		endif
		comment=0
		if (comments_flag)
			comment$ = Get value: i_row, progress_comment$
			if (comment$ <> "")
				comment = 1
			endif
		endif
# keep row (i.e. do nothing) if either note, judgment or comment are given
		if (note or judgment or comment)
# otherwise, delete row
		else
			Remove row: i_row
			i_row -= 1
			nr_rows -= 1
		endif
	endfor

	Save as tab-separated file: reports_file$
endif

if (abort_flag)
	printline Inspecting adjourned. 'nr_handled_items' of 'real_nr_rows' items checked.
	printline File 'progress_file_name$' 'handling$' to continue inspection at any time.
else
	deleteFile: progress_file_name$
	printline Inspection finished. Last 'nr_handled_items' of 'real_nr_rows' items checked.
endif

if (reports_flag)
	printline File 'reports_file$' 'handling$'.
endif

call RemoveObjects

############################# End of main program ########################################


##########################################################################################
#
# Procedure to check the 'File' field of the initial form
#
##########################################################################################
##@@ add reports file handling!
procedure CheckFileField

# <nil> => all sound files
	file_all = 0

# sound file (list given)
	file_sound = 1

# result file (list)
	file_result = 2

# report file (list)
	file_report = 3

### now recode the request
# lower case string is sometimes needed
	lc_files$ = replace_regex$ (files$, ".", "\L&", 0)

# report all
	if (files$ = "")

# create list of sound files
		file_list_obj = Create Strings as file list:  "file_list", "'sound_directory$'*'sound_ext$'"
		nr_files = Get number of strings
		file_flag = file_sound

# report a list of sound files or use data from a result or report file
	elsif (endsWith(lc_files$,".txt"))
		files$ = support_directory$+files$
		if (not fileReadable (files$))
			printline File 'files$' not found. Please correct input.
			call RemoveObjects
			goto restart
		endif
		file_list_obj = Read Strings from raw text file: files$
		nr_files = Get number of strings
		if (nr_files < 1)
			printline File 'files$' has no text lines. Script aborted.
			exit
		endif

# find out whether it is just a list of file names (i.e. 1 column) or a result or report file
		line$ = Get string: 1
		help_obj = Create Table with column names: "input_table", 0, line$
		nr_col = Get number of columns

# if there is only one column then check whether it is a list of audio files
		if (nr_col = 1)
# the first line of a text file would become a header,
# so we have to use the raw text file
			removeObject: help_obj
			help_obj = 0
			selectObject: file_list_obj
			for i_line to nr_files
				line$ = Get string: i_line
				line$ = replace_regex$ (line$, "\s", "", 0)
				if (line$ <> "")
# create a full name (with path and extension if missing)
					call MakeFileNames 'line$'
					if (not fileReadable(sound_file$))
						printline The file "'files$'" seems not to contain a list of sound file names.
						printline E.g., the file "'sound_file$'" is not readable.
						printline Please correct the input or the file format.
						exit
					endif
# it is an audio file. re-store name with extension.
					Set string: i_line, sound_file$
				else
					Remove string: i_line
					nr_files -= 1
				endif
			endfor
			file_flag = file_sound

# check whether it is a report file (which has a defined header layout)
# if yes, we just treat it like a progress file
		elsif (line$ = report_header$)
			removeObject: help_obj
			help_obj = 0
			removeObject: file_list_obj
			file_list_obj = 0
			file_flag = file_report

# this could be a result file; remove the raw text file
# check whether all header items are there
		else
			removeObject: file_list_obj
			file_list_obj = 0
			err = 0
			for i_col to max_result_header
				header_col = Get column index: result_header$#[i_col]
				if (header_col)
					hash[result_header$#[i_col]] = header_col
				else
					help$ = result_header$#[i_col]
					printline File 'files$' has no column with the header 'help$'.
					err += 1
				endif
			endfor
			if (err)
				printline Please correct the header specifications in this script.
				exit
			endif
# header seems to be okay; get rid of the help table
			removeObject: help_obj
			help_obj = 0
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
				line$ = sound_directory$ + line$
				if (not fileReadable(line$))
					printline The file 'files$' seems not to be sound file.
					printline Please correct the input or file format.
					call RemoveObjects
					goto restart
				endif
			endif
# it is an audio file. re-store name with extension.
			Set string: i_line, line$
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
			printline File 'labels$' has no text lines. Script aborted.
			exit
		endif
		printline 'nr_labels' labels found in file 'labels$'.
		label_list_obj = To WordList
		removeObject: help_obj
		help_obj = 0
		label_flag = label_list

# treat input as one or more labels or times, separated by comma and pretend they come from a label file
	else
		labels$ = replace_regex$(labels$,","," ",1)
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

	window = number(window$)
	window = window / 1000

# convert window to a number and check whether it is an additional window size
	if (window$ = "")
		window = 0
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
	Set string value: nr_progress_lines, progress_file$, sound_file$
	Set numeric value: nr_progress_lines, progress_start$, wstart
	Set numeric value: nr_progress_lines, progress_end$, wend
	Set numeric value: nr_progress_lines, progress_cursor$, cursor
	Set string value: nr_progress_lines, progress_label$, label$
	Set numeric value: nr_progress_lines, progress_note$, note
	Set string value: nr_progress_lines, progress_judgment$, judgment$
	Set string value: nr_progress_lines, progress_comment$, comment$
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


##########################################################################################
#
# Procedure to convert Praat's date and time to a date-and-time string
#
##########################################################################################

procedure GetDateTime
# from 6.1.51:
# date# () -> { 2021, 7, 7, 12, 5, 46 }

	help# = date#()

# this does NOT work in praat and it would have no leading zeros):
# 	date_time$ = "'help$#[1]''help#[2]''help#[3]'_'help#[4]''help#[5]''help#[6]'"

	date_time$ = ""
	for i to 6
		x = help#['i']
		if (x < 10)
			date_time$ += "0'x'"
		else
			date_time$ += "'x'"
		endif
		if (i = 3)
			date_time$ += "_"
		endif
	endfor

endproc



##########################################################################################
#
# Procedure to check Praat's program version
#
##########################################################################################

procedure CheckPraatVersion
	lowest_praat_version = 6
	lowest_praat_revision = 1
	lowest_praat_fix = 51

	left_dot = index(praatVersion$,".")
	right_dot = rindex(praatVersion$,".")

	praat_version = number(replace_regex$(praatVersion$,"\..*","",1))
	praat_revision$ = replace_regex$(praatVersion$,"\d+?\.","",1)
	praat_revision = number(replace_regex$(praat_revision$,"\..*","",1))
	if (left_dot = right_dot)
		praat_fix = 0
	else
		praat_fix = number(replace_regex$(praatVersion$,"^\d+?\..+?\.","",1))
	endif

	if (praat_version<lowest_praat_version)
		too_low = 1
	elsif (praat_revision<lowest_praat_revision)
		too_low = 1
	elseif (praat_fix<lowest_praat_fix)
		too_low = 1
	else
		too_low = 0
	endif
	if (too_low)
		printline Please update your Praat version to 'lowest_praat_version'.'lowest_praat_revision'.'lowest_praat_fix' or higher (you have 'praatVersion$').
		printline Downlaod newest Praat version from https://praat.org
		exit
	endif

# find out slash type
	system$ = Report system properties
	mac = index(system$,"macintosh")
	pc = index(system$,"WIN")
	linux = index(system$,"linux")

	if (mac or linux)
		slash$ = "/"
	elsif (pc)
		slash$ = "\"
	else
		printline Unknown system version. Please correct "slash" in CheckPraatVersion.
		printline 'system$'
		exit
	endif

endproc


##########################################################################################
#
# Procedure to get base_name$ and file_name$ out of speech file name
#
##########################################################################################

procedure MakeFileNames name$

# find out whether there is a slash as indication for a path
	slash = rindex(name$,slash$)
	if (slash)
		sound_directory$ = left$(name$,slash)
	else
		sound_directory$ = ""
	endif

# remove the extension
	base_name$ = replace$(name$,sound_directory$,"",1)
	base_name$ = base_name$ - sound_ext$

# now build the full name (eventually again)
	sound_file$ = sound_directory$ + base_name$ + sound_ext$

endproc


##########################################################################################
#
# Procedure to add a slash to directory names
#
##########################################################################################

procedure AddSlash help$

	if (help$ = "")
#		help$ = "." + slash$
	elsif (help$ = "?")
		help$ = ""
	elsif (not endsWith(help$,slash$))
		help$ += slash$
	endif

endproc


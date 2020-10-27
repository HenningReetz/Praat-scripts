## @@ generated Viewed all the time??
#	This script opens each .wav (and its .TextGrid) file, and moves
#   to a specific part of the signal with a specific window size.
#	The sequence of files (and their data) are given by the .txt output file of my Formants, Duration or Pitch scripts.
#	This script adds a column "Viewed" to such a .txt file to handle the skipping of .wav/.TextGrid files
#	that have already been inspected (in a previous session).
#
#  	Version 0.0, Henning Reetz, 18-jan-2019
#  	Version 0.1, Henning Reetz, 10-jun-2019,	'previous' option, skip already viewed segements
#  	Version 0.2, Henning Reetz, 18-mar-2020,	open every file only once (not a good solution)
#  	Version 1.0, Henning Reetz, 20-mar-2020,	do not re-open files with same name and start time; relative window times
#
#	Tested with Praat 6.1.09
##

clearinfo
start_string$ = "Start[s]"
file_string$ = "File"
dur_string$ = "Duration[ms]"
dur_is_ms = 1
wav_extension$ = ".wav"

#
## 1) Inquire some parameters
#

form Inspect parameters:
	comment Leave the directory path for wav-files empty if you want to use the current directory.
		word directory
	comment Name of list file (= result file of other scripts) - must be in the current directory.
		word list_file Formants_all.txt
	comment Always use default parameter settings?
		boolean default 0
	comment ______________________________________________________________________________________________________________
	comment Length of window in seconds, "0" for whole signal, "±<time>" adds time to interval
		word window +0.1
endform

# add a slash ("/") to the end of the directory name if necessary
if (directory$ <> "")
	if (!endsWith(directory$,"/"))
		directory$ = directory$ + "/"
	endif
endif 

# change the directories according to your needs
wav_directory$ = directory$
grid_directory$ = directory$
list_directory$ = directory$

list_file$ = list_directory$ + list_file$

# convert 'window$' to a real value
# if there is a "+" or "-" in front set the relative flag
# if the window size is empty, set it to zero (i.e., display whole file) to avoid a crash 
rel_flag = ( (startsWith(window$,"+"))  or  (startsWith(window$,"-")) )
if (window$ = "")
	window$ = "0"
endif
window = number(window$)

# if the whole file should be displyed, do not look for 'start_string$' and  'dur_string$'
whole_file_flag = (window = 0)
	

#
## open file list
#

nr_handled_files = 0

if fileReadable (list_file$)
	table_obj = Read from file: list_file$
	
# find out, whether a 'Viewed' column is there
	i_col = Get column index: "Viewed"

# add column 'Viewed' if not found
	if (i_col = 0)	
		Append column: "Viewed"
	endif

# go, row by row, through the table
	nr_rows = Get number of rows
	back_skip_flag = 0
	last_file$ = ""
	last_middle = -1
	
	for i_row to nr_rows
		selectObject: table_obj
		view$ = Get value: i_row, "Viewed"

# for correct handling of previous/next question later, we need to now the status of the next row
		next_row = i_row+1
		if (next_row <= nr_rows)
			next_view$ = Get value: next_row, "Viewed"
		else
			next_view$ = "0"
		endif
# row has not been handled or it is a back skipping
		if ((view$ = "") or (view$ = "?") or back_skip_flag)
			file_name$ = Get value: i_row, file_string$
			praat_object_name$ = replace$(file_name$,"~","_",0)
			
# start and duration required?			
			if (!whole_file_flag)
				start = Get value: i_row, start_string$
				dur = Get value: i_row, dur_string$
				if (dur_is_ms)
					dur /= 1000
				endif
				middle = start + dur/2

# display whole file
# set middle to a random value to avoid error in first acces of 'middle' in the if statement below
			else
				middle = 0
			endif

# get wav file name and check whether it has already been processed
			wav_file$ = wav_directory$+file_name$+wav_extension$
			grid_file$ = grid_directory$+file_name$+".TextGrid"
			if ((wav_file$ <> last_file$) or (last_middle <> middle))
				last_file$ = wav_file$
				last_middle = middle
				
# at least, .wav file is needed
				if fileReadable (wav_file$)
					wav_obj = Read from file: wav_file$
					end_time = Get end time

# find out, whether there is a .TextGrid file and try to open it		
					if fileReadable (grid_file$)  
						grid_obj = Read from file: grid_file$
						plusObject: wav_obj
						grid = 1
					else
						grid = 0				
					endif

# start and duration given: compute position of display window
					if (!whole_file_flag)
# avoid window going beyond of beginning of file
# for absolute time: shift 'start_time' by half window size to center it at 'middle'
# for relative time: add window to beginneng and end of interval
						if (rel_flag = 0)
							first_time = middle - window/2
						else
							first_time = start - window
						endif
						if (first_time < 0)
							first_time = 0
						endif

# determine end of window	
						if (rel_flag = 0)
							last_time = middle + window/2
						else
							last_time = start + dur + window
						endif
						if (last_time > end_time)
							last_time = end_time
# re-check first_time (only needed for absolyte window sizes)
							if (rel_flag = 0)
								first_time = last_time - window
								if (first_time < 0)
									first_time = 0
								endif
							endif
						endif

# display whole file
					else
						first_time = 0
						last_time = end_time
						middle = end_time / 2
					endif
					
# display signal (and TextGrid, if it is there)
					View & Edit
						if (grid = 0)
							editor Sound 'praat_object_name$'
						elsif (grid = 1)
							editor TextGrid 'praat_object_name$'
						else
							exit Impossible grid value: 'grid''newline$'
						endif

# set display window (if 'last_time' == 'first_time', i.e. window = 0, Praat displays whole file)
# end center cursor
						Select: 'first_time','last_time'
						Zoom to selection
						Move cursor to: 'middle'

# reset parameters if required
						if (default = 1)
							Spectrogram settings: 0, 5000, 0.005, 70
							Pitch settings: 75, 500, "Hertz", "autocorrelation", "automatic"
							Formant settings: 5000, 5, 0.025, 30, 1
						endif

# enable user interaction
						beginPause ("Do what ever you want")
# in a back skip case, the user might want to jump to the next file (in the list) or to the next unviewed file
						if (back_skip_flag = 0) or (next_view$ <> "1")
							answer = endPause ("Exit","Previous","Next",3,1)
						elsif (back_skip_flag = 1)
							answer = endPause ("Exit","Previous","Next new","Next in list",3,1)
						else
							printline Impossible back_skip_flag: 'back_skip_flag', next_view: 'next_view$'. Program aborted.
							exit
						endif

# leave editor, save TextGrid (whether it has been changed or not) and clean up
					endeditor
					removeObject: wav_obj
					if (grid)
						selectObject: grid_obj
						Save as text file: grid_file$
						Remove
					endif
					nr_handled_files += 1

# user wants to end sesseion (force end of for-loop by putting i_row beyond nr_rows)		
					if (answer = 1)
						i_row = nr_rows + 1

# user wants to go backwards (reset i_row by 2 so that after increment by 1 it will be resetted by 1)
					elsif (answer = 2)
						i_row -= 2
						if (i_row <= 0)
							i_row = 0
						endif
						back_skip_flag = 1
						nr_handled_files -= 1
# user wants to go backwards (reset i_row by 2 so that after increment by 1 it will be resetted by 1)
					elsif (back_skip_flag and (answer = 4))
						back_skip_flag = 1
						nr_handled_files -= 1
					else
				
# report, that this row has been handled (save file every time in case script crashes)
						selectObject: table_obj
						Set string value: i_row, "Viewed", "1"
						Save as tab-separated file: list_file$
						back_skip_flag = 0				
					endif

# no wav-file found?
				else
					printline No 'wav_file$' found.
				endif

# file and time has already been viewed - add a 'viewed' flag to the list and skip it
			else
				selectObject: table_obj
				Set string value: i_row, "Viewed", "1"
				Save as tab-separated file: "'list_file$'"
				back_skip_flag = 0		
			endif

# row has already been viewed - skip it
		else
		endif
				
# all lines in list_file handled?
	endfor
	removeObject: table_obj

# list file not found?
else 
	printline No 'list_file$' found.
endif

printline 'nr_handled_files' files of 'list_file$' processed.
	



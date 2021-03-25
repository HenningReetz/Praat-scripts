#########################################################################################
#
# Script to convert Hillenbrand's vowel time information on
# 	<https://homepages.wmich.edu/~hillenbr/voweldata.html>
# from the article
#	Hillenbrand, J., Getty, L. A., Clark, M. J., and Wheeler, K. (1995).
#	Acoustic characteristics of American English vowels.
#	The Journal of the Acoustical Society of America, 97, 3099–3111
# to PRAAT TextGrids.
#
# The created TextGrids have two tiers:
#	Interval tier 1: "Vowel" with the interval label extracted from the file name
#	Point tier 2: "Judges" the positions of the two judges' times (sometimes only one)
#		if both judges have the same time. The label is the vowel label.
#
# The script expects the original files in a directory/folder with the structure
#	timedata.dat			Time start/end and judge information
#		kids				Subdirectory/folder for boy's and girl's wav-files
#		men					Subdirectory/folder for men's wav-files
#		women 				Subdirectory/folder for women's wav-files
# and creates the TextGrids within the subdirectories/folders.
#
# The script temporarily uses a file "zzz.txt" and overides and deletes any file with
# this name without warning.
#
#	Version 0.0, Henning Reetz, 25-mar-2021
#	Tested with PRAAT 6.1.38 on MacOS 11.2.3
#
#	Please report bugs etc. to <reetz.phonetics@gmail.com>
#
#########################################################################################

clearinfo
label_tier = 1
point_tier = 2

# The file 'timedata.dat' has 5 information lines on the top and then the filenames
# (without directory and '.wav' extensions) and timing data
# Read file in as raw text file, remove the first 5 lines, save file as 'zzz.txt' and
# re-read the file as a table.

Read Strings from raw text file: "timedata.dat"
for i to 5
	Remove string: 1
endfor
Save as raw text file: "zzz.txt"
Remove
table_obj = Read Table from whitespace-separated file: "zzz.txt"
deleteFile: "zzz.txt"

# prepare processing: get number of rows (i.e. nr. of files), preset successful creation
# counter (should end up as 'nr_rows', but just to be sure) and preset sub-directory string.
nr_rows = Get number of rows
nr_textgrids = 0
last_gender$ = ""

# Go thru rows (i.e. files)
for i_row to nr_rows
	selectObject: table_obj
	file$ = Get value: i_row, "File"
# dissemble file name <1-char gender><2-digit speaker><2-char vowel>
	gender$ = left$(file$)
	label$ = mid$(file$,4,2)
# change sub-diretory string only if gender changes (i.e. only 3 times)
	if (last_gender$ <> gender$)
		if (gender$ = "m")
			directory$ = "./men/"
		elsif (gender$ = "w")
			directory$ = "./women/"
		elsif ((gender$ = "b") or (gender$ = "g"))
			directory$ = "./kids/"
		else
			printline Unexpected gender code: 'gender$'. Processing aborted.
			exit
		endif
	endif

# add sub-doirectory and '.wav' extension to file name
# and get start, end, and two judges 'center' times.
# The time is given in milliseconds and converted to seconds for PRAAT.
	file$ = directory$ + file$
	wav_file$ = file$ + ".wav"
	start = Get value: i_row, "Start"
	start /=1000
	end = Get value: i_row, "End"
	end /= 1000
	center_1 = Get value: i_row, "Center1"
	center_1 /= 1000
	center_2 = Get value: i_row, "Center2"
	center_2 /= 1000

# OK, do the job. Make sure the list and the files on disk are the same.
	if (fileReadable(wav_file$))
# .wav is no really needed, but to create TextGrid, beginning and end of file are needed.
		wav_obj = Read from file: wav_file$
# Create TextGrid and insert labels
		To TextGrid: "Vowel Judge", "Judge"
		Insert boundary: label_tier, start
		Insert boundary: label_tier, end
		Set interval text: label_tier, 2, label$
		Insert point: point_tier, center_1, label$
# sometimes, both judges have the same time; prevent PRAAT from crashing in this case
		if (center_2 <> center_1)
			Insert point: point_tier, center_2, label$
		endif
# Save TextGrid, count success and clean up
		Save as text file: "'file$'.TextGrid"
		nr_textgrids += 1
		Remove
		removeObject: wav_obj

# This should never happen
	else
		printline File 'wav_file$' not found.
	endif
endfor

# We're done. clena up and inform user

removeObject: table_obj
printline Done. 'newline$''nr_textgrids' TextGrids created.

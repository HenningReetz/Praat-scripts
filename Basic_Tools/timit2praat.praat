#########################################################################################
#
# Script to convert TIMIT files to MS .wav and Praat .TextGrid files
# The script expects the original TIMIT directory hierarchy (TEST/TRAIN - DR - Sentence
# 	with the Speaker-files (and extensions in upper case)
# The script can generate the .wav and .TextGrid files in these original directories,
#	or writes all .wav and .TextGrid files into a subdirectory "praat", where the
#	file names are a concatenation of the directory names with (optional an additional 
#	F and M for female and male speakers. The sequence of these names are defined by 
#	the user in the initial dialog window.
# The script also generates a file "TIMIT_overlap.txt" for overlapping words warnings, 
#	and a file "TIMIT_missing.txt" for words with zero-length.
#
# The created TextGrids have 3 to 5 tiers:
#	Interval tier 1: "Phonemes" TIMIT labels from <file>.PHN
#	Interval tier 2: "Sentence" TIMIT sentence from <file>.TXT
#	Interval tier 3: "Words" TIMIT words from <file>.WRD
#	Interval tier 4 (optional): "Overlap" overlapping TIMIT words from <file>.WRD
#	Point tier 5 (ptional): "Missing" TIMIT words with zero-length from <file>.WRD
#
#	Version 0.0, Henning Reetz, 27-mar-2021	initial hack
#	Tested with PRAAT 6.1.38 on MacOS 11.2.3
#
#	(A more detailed description will be in an additional PDF file in thenear furture)
#	Please report bugs etc. to <reetz.phonetics@gmail.com>
#
#########################################################################################

writeInfo: ""

timit_wav$ = ".WAV"
timit_txt$ = ".TXT"
timit_phn$ = ".PHN"
timit_wrd$ = ".WRD"

# count the nr. of wav fiels to inform user later
nr_wav = 0

phoneme_tier = 1
sentence_tier = 2
word_tier = 3
overlap_tier = 4
missing_tier = 5

# naming parts variables
g = 1
d = 2
sp = 3
s = 4
t = 5
max_naming_part = 5

repeat
	error = 0
	beginPause: "TIMIT-to-PRAAT parameters:"
		comment: "Leave the field empty if you want to leave audio and TextGrid files in the" 
		comment: "Original TIMIT directory structure or specify a string to copy all new"
		comment: ".wav and .TextGrid files into a subdirectory 'praat'"
		comment: "Use letters separated by spaces to define the naming convention:"
		comment: "T: test/train, D: dialect region, G: gender, Sp: speaker, S: sentence type. E.g."
		comment: "G D S Sp T will generate names like M_DR1_SA1_MFAKS0_TEST.wav"
		comment: "S G T D Sp will generate names like SA1_M_TEST_DR1_MFAKS0.wav"
		comment: "T D Sp S will generate names like TEST_DR1_MFAKS0_SA1.wav (i.e. TIMIT hierarchy)"
			sentence: "Naming sequence", "G S D T Sp"
		comment: "__________________________________________________________________________________"
		comment: "Remove DC offset (recommended)?"
			boolean: "Remove DC", 1
		comment: "Scale peak to maximum?"
			boolean: "scale peak", 1
	clicked = endPause: "Stop", "Continue", 2

	if (clicked = 1)
		exit Script aborted by user.
	endif

# if the naming field is empty, put files into original directories
#@@ should I check in that case whether lower case .wav files are there??
naming_sequence$ = replace_regex$ (naming_sequence$, ".", "\L&", 0)
naming_sequence$= replace_regex$ (naming_sequence$, " ", ",", 0)
naming_obj = Create Strings as tokens: naming_sequence$, " ,"
nr_naming_parts = Get number of strings

if (nr_naming_parts = 0)
	wav_directory$ = ""

# use local directory for all files and create pattern for file name
# check naming parameters field (convert to lower case and change spaces to commas first)
else

# go thru input and check whether all are there (gender can be missing)
	for i_part to max_naming_part
		part[i_part] = 0
	endfor
	for i_part to nr_naming_parts
		part$ = Get string: i_part
		part['part$'] += 1
	endfor

	for i_part from d to max_naming_part
		if (part[i_part] <> 1)
			writeInfo: "Error: D S Sp T must appear exactly once (in any sequencing).
			error = 1
		endif
	endfor

# everyting is OK
	if (!error)
		wav_directory$ = "./praat/"
		createDirectory: wav_directory$
	endif
endif

until (!error)
			
sep$ = tab$
report_overlap_file$ = "TIMIT_overlaps.txt"
report_missing_file$ = "TIMIT_missing.txt"
deleteFile: report_overlap_file$
deleteFile: report_missing_file$
fileappend 'report_overlap_file$' PRAAT-file'sep$'Label'sep$'On'sep$'Off'newline$'
fileappend 'report_missing_file$' TIMIT-file'sep$'PRAAT-file'sep$'Label'sep$'At'newline$'
nr_overlap = 0
nr_missing = 0

##########################################################################################
#                  Collect all directories                                               #
##########################################################################################

# start with the present directory
dir_name$ = "./"

# nr. of entry in the directory listing
nr_dir_list = 1

# pointer to the nth directory inserted
now_dir_pnt = 0

# create a table for the directories and insert the present directory in it
table_obj = Create Table with column names: "dir_table", nr_dir_list, "directory"
Set string value: nr_dir_list, "directory", dir_name$

# Get all directories. We use a table of directroy names and add new names to it.
# These names will be used again to list all directories in it.
# this will contiue continue as long as 'now_dir_pnt' has not reached 'nr_dir_list'
repeat
	now_dir_pnt += 1
	selectObject: table_obj

# get the name of the present directory (i.e. the 'now_fir_pnt' directory
	dir_name$ = Get value: 'now_dir_pnt', "directory"

# Create a new list of all sub-directories of the directory to which 'now_dir_pnt' points
# Add th full path to these diretory names and add them to the table
	string_obj = Create Strings as directory list:  "new_dir_list", "'dir_name$'*"

# go thru all directory names it found
	nr_new_dir_list = Get number of strings
	for i_dir to nr_new_dir_list

# get a name of a directory
		selectObject: string_obj
		new_dir_name$ = Get string: i_dir

# add the path of the present directory to it
		new_dir_name$ = dir_name$+new_dir_name$+"/"

# add the new directory name to the table of directory names
		selectObject: table_obj
		Append row
		nr_dir_list += 1
		Set string value: 'nr_dir_list', "directory", "'new_dir_name$'"

# going thru all sub-directory at this level
	endfor

# clean up list of 'now_dir_pnt' directories
	removeObject: string_obj
until (now_dir_pnt >= nr_dir_list)

# now remove all paths that are too short (i.e. not pointing to sound files)
selectObject: table_obj
for i_row to nr_dir_list
	directory$ = Get value: i_dir, "directory"
	if (length(directory$)<17)
		Remove row: i_row
		i_row -= 1
		nr_dir_list -= 1
	endif
endfor

# Report to the user:
writeInfo: "'nr_dir_list' directories found."

##########################################################################################
#                  End of part that collects all directories                             #
##########################################################################################

call Seconds
last_seconds = seconds

##########################################################################################
#                  Go thru all files in all directories and generate TextGrids           #
##########################################################################################

for i_dir to nr_dir_list

# entertain user
	call Seconds
	if (seconds < last_seconds)
		seconds += 60
	endif
	if (seconds - last_seconds > 1)
		writeInfo: "'i_dir' directories processed."		
		last_seconds = seconds
	endif


# get a list of all WAV files i a directory
	selectObject: table_obj
	timit_directory$ = Get value: i_dir, "directory"
	wav_list_obj = Create Strings as file list...  file_list 'timit_directory$'*'timit_wav$'
	nr_wav_files = Get number of strings

# go thru all WAV inside one directory
	for i_wav to nr_wav_files

# read the WAV file and get its sampling rate (needed, because TIMIT has samples numbers and Praat uses seconds)
		selectObject: wav_list_obj
		wav_name$ = Get string: i_wav
		file$ = timit_directory$+wav_name$
		wav_obj = Read from file: file$
		rate = Get sampling frequency
		sample_dur = 1/rate
		nr_wav += 1
		# create basic TextGrid
		grid_obj = To TextGrid: "Phonemes Sentence Words", ""
		nr_tiers = 3

# create output name now already because we might need it for warning/error messages
# dissemble name into its parts 
# does PRAAT knows things like \d(.*) 
		help$ = replace$(file$,timit_wav$,"",1)
		help$ = replace_regex$(help$,"..","",1)
		part_t$ = replace_regex$(help$,"/.*","",1)
		part_d$ = replace_regex$(help$,".*?/","",1)
		part_d$ = replace_regex$(part_d$,"/.*","",1)
		part_sp$ = replace_regex$(help$,".*?/","",2)
		part_sp$ = replace_regex$(part_sp$,"/.*","",1)
		part_g$ = left$(part_sp$)
		part_s$ = replace_regex$(help$,".*?/","",3)

# now assemble the output names
		selectObject: naming_obj
		part$ = Get string: 1
		out_file$ = part_'part$'$
		for i_part from 2 to nr_naming_parts
				part$ = Get string: i_part
				out_file$ += "_"
				out_file$ += part_'part$'$
		endfor

# the labeling for sentences, words and phonemes are not exactly the same
# that's we I do three times 'nearly' the same but have their own peculiarities,
# and do not use a loop for the 3 levels

##
# first put the Sentence into the sentence tier
##
# the sentence is in a file with the extension .TXT
		file$ = replace$(file$,timit_wav$,timit_txt$,1)
		label_obj = Read Strings from raw text file: file$
		line$ = Get string: 1

# remove the beginning and ending sample numbers
		label$ = replace_regex$ (line$,"\d \d* ","",1)
		selectObject: grid_obj
		Set interval text: sentence_tier, 1, label$
		removeObject: label_obj

##
# now insert the phonemes (there is no overlap in the phone,es; i.e. they are simpler than words
##
# phonemes are strictly left-to-right in TIMIT, just like in Praat
		file$ = replace$(file$,timit_txt$,timit_phn$,1)
		label_obj = Read Strings from raw text file: file$
		nr_labels = Get number of strings

# note that the left boundary (= beginning of file) is already there. 
# We only insert the label and then the right boundary
# (the boundary is given in sample number, we convert it to seconds)
		for i_label to nr_labels
			selectObject: label_obj
			line$ = Get string: i_label
# get label
			label$ = replace_regex$(line$,"\d* \d* ","",1)
# get right boundary (removeirst the 'label$' string, then the 'on' sample number
			off$ = replace_regex$(line$," 'label$'","",1)
			off$ = replace_regex$(off$,"\d* ","",1)
# convert the sample nymber in 'off$' into seconds in 'off'
			off = number(off$) / rate
# insert label and boundary into TextGrid
			selectObject: grid_obj
			Set interval text: phoneme_tier, i_label, label$
#@@@ should I really do this - better check for end-of-file?
			if (i_label <> nr_labels)
				Insert boundary: phoneme_tier, off
			endif
		endfor
		removeObject: label_obj

##
# now insert the words (there are overlaps and gaps, they need special handling)
# This becomes messy now...
##
# put all word labels into tiers
		file$ = replace$(file$,timit_phn$,timit_wrd$,1)
		label_obj = Read Strings from raw text file: file$
		nr_labels = Get number of strings

# we need to check whether labels are continuing, overlapping or gapping
# so we need the previous on/off information to find out what is going on
# the strings hold the sample numbers, the numbers the seconds
		last_on = 0
		last_off = 0
		last_on$ = ""
		last_off$ = ""

# the number of labels in Praat might differ from the sequence in TIMIT, so we need extra counters for them
# (and we have one or two alternative tiers)
		new_label = 1
		alt_label = 1
	
# go thru all TIMIT labels
		for i_label to nr_labels
			selectObject: label_obj
			line$ = Get string: i_label

# get left boundary (first part of 'line$')
			on$ = replace_regex$(line$," .*","",1)
			on = number(on$) / rate
			line$ = replace_regex$ (line$,"\d* ","",1)

# get label (after second number in 'line$', which is now in front)
			label$ = replace_regex$ (line$,"\d* ","",1)

# get right boundary (just 'line$' without 'label$'
			off$ = replace_regex$(line$," 'label$'","",1)
			off = number(off$) / rate

# now we try to insert the labels
			selectObject: grid_obj
# the first label must not start at '0'
# if that is the case, insert a bouadry (but no label)
			if (i_label = 1) and (on <> 0)
				Insert boundary: word_tier, on
				last_off = on
			endif
#
# the new onset is left from the last offset; i.e. we have an overlap
#

# skip intervals with zero length			
			if (on = off)
				if (nr_tiers = 3)
					overlap_tier = nr_tiers + 1
					Insert interval tier: overlap_tier, "Overlap"
					nr_tiers += 1
				endif
				if (nr_tiers = 4)
					missing_tier = nr_tiers + 1
					Insert point tier: missing_tier, "Missing"
					nr_tiers += 1
				endif
				Insert point: missing_tier, on, label$
				fileappend 'report_missing_file$' 'file$''sep$''out_file$''sep$''label$''sep$''on''newline$'
				nr_missing += 1
				goto next
			endif
			
# overlap
			if (on < last_off)
				fileappend 'report_overlap_file$' 'out_file$''sep$''label$''sep$''on''sep$''off''newline$'
				nr_overlap += 1
# insert the phoneme name into the alternate word tier; we might create new tier for this
				if (nr_tiers = 3)
					overlap_tier = nr_tiers + 1
					Insert interval tier: overlap_tier, "Overlap"
					nr_tiers += 1
				endif
				Insert boundary: overlap_tier, on
				alt_label += 1
				Set interval text: overlap_tier, alt_label, label$
				Insert boundary: overlap_tier, off

# now we insert the new label to the right from it
				new_label += 1
				Set interval text: word_tier, new_label, label$

				at = Get interval at time: word_tier, off
				at = Get start time of interval: word_tier, at
				if (at <> off)
					Insert boundary: word_tier, off
				else
					new_label -= 1
				endif
				
# We have a gap
			elsif (on > last_off)
				selectObject: grid_obj

# just insert the new interval with a left boundary; leave the gap without a name
				Insert boundary: word_tier, on
				new_label += 1
# now we insert the new label to the right from it
				new_label += 1
				Set interval text: word_tier, new_label, label$
				Insert boundary: word_tier, off

# otherwise, it is just a continuation of intervals
			else
				new_label += 1
				Set interval text: word_tier, new_label, label$
				Insert boundary: word_tier, off

# end of the situations for new intervals
			endif

			
# update 'last' information			
			last_on = on
			last_off = off
			last_on$ = on$
			last_off$ = off$

label next

# going thru all intervals in a file
		endfor
		removeObject: label_obj
	
		out_file$ = "'wav_directory$'/'out_file$'.TextGrid"
		selectObject: grid_obj
		Save as text file: out_file$
		Remove

		selectObject: wav_obj
		if (remove_DC)
			Subtract mean
		endif
		if (scale_peak)
			Scale peak: 0.99
		endif
		out_file$ = replace$(out_file$,".TextGrid",".wav",1)		
		Save as WAV file: out_file$
		Remove

# going thru all WAV file in a directory
	endfor
	removeObject: wav_list_obj

# going thru all directories
endfor
removeObject: table_obj, naming_obj

# clean up and inform user
writeInfoLine: "Done.'newline$''nr_wav' files in 'nr_dir_list' directories processed."
if (nr_overlap)
	appendInfoLine: "'nr_overlap' overlap warnings written to 'report_overlap_file$'."
endif
if (nr_missing)
	appendInfoLine: "'nr_missing' zero-length warnings wriiten to 'report_missing_file$'."
endif


procedure Seconds
	date_time$ = date$()
	seconds$ = mid$(date_time$,18,2)
	seconds = number(seconds$)
endproc

##
#
# This script takes labels from a text file and puts them 
# consecutively on the interval/point marks that are interactively
# set by a user on one tier. 
#
#	Version 1.5, Henning Reetz, 13-nov-2009
#	Version 1.6, HR, 3-dec-2009, removed bug in filename concatenation, more comments
#	Version 2.0, Henning Reetz, 07-dec-2014 adapted to new Praat script syntax
#	Version 2.1, Henning Reetz, 16-dec-2014 'selectObject' etc. added
#	Version 2.2, Henning Reetz, 17-jan-2020 zerocrossing and default extension .txt added
#
#	Tested with Praat 6.1.08
#
##

#
# 0) clear info screen and preset constants
#

clearinfo
# true and false values
c_true = 1
c_false = 0
# interval- or point-tier constant
c_interval_tier = 1
c_point_tier = 2
# gaps or no-gaps between intervals constant
c_no_gap = 1
c_gap = 2
# flag constant, whether first interval should start at time 0.0 or not
## not yet implemented
c_immediate_start = 1
c_delayed_start = 2
# at the moment, only start of intervals at 0.0 is implemented (but this is a gap for the intervals with 'gaps') 
zero_start = c_immediate_start

#
## 1) Inquire some parameters from user
#
## remove two comments in case you use different directories for sounds, textgrids and text files
## and comment-out the two lines after 'endform'

form Label parameters:
	comment Leave the directory path empty if you want to use the current directory.
	word Directory
#	word Label_directory
#	word Textgrid_directory
	word Sound_file Recording_x
	comment The "Label_file" is a .txt file with the names of the segments/points.
	word Label_file Recording_x
	comment __________________________________________________________________________________________________
	comment Type of tier?
	choice Tier_type 1
		button Interval tier (segments)
		button Point tier
	comment Name of tier? 
	word Tier_name Sentence
	comment __________________________________________________________________________________________________
	comment For intervals tier only:
	comment Should there be gaps between intervals?
	choice Gap_type 2
		button No gaps (|segment|segment|)
		button Gaps (|    |segment|    |segment|)
	boolean zero_crossings 1
#	comment Should the first interval label start immediately at zero seconds?
#	choice Zero_start 2
#		button Yes (0|segment|...)
#		button No (0|   |segment|...)
endform

## comment-out the next two line in case you use different directories for sounds, textgrids and text files
label_directory$ = directory$
textgrid_directory$ = directory$

# Point tiers are always without gaps - override anything a user changed

if tier_type = c_point_tier
	gap_type = c_no_gap
	zero_start = c_immediate_start
endif

#
## 2) Construct file names
#

# check whether (non-empty) directory path ends in a slash

if (length(directory$)>0) and (!endsWith (directory$,"/"))
	directory$ = directory$+"/"
endif
if (length(label_directory$)>0) and (!endsWith (label_directory$,"/"))
	label_directory$ = label_directory$+"/"
endif
if (length(textgrid_directory$)>0) and (!endsWith (textgrid_directory$,"/"))
	textgrid_directory$ = textgrid_directory$+"/"
endif

# add (.)wav to a sound file name if no extension is given

if length(sound_file$) = 0
	printline No Sound_file name given!
	exit
endif
if !index(sound_file$,".")
	sound_file$ = sound_file$+".wav"
elsif endsWith (sound_file$,".")
	sound_file$ = sound_file$+"wav"
endif	

# add (.)txt to a label file name if no extension is given

if length(label_file$) = 0
	printline No Label_file name given!
	exit
endif
if !index(label_file$,".")
	label_file$ = label_file$+".txt"
elsif endsWith (label_file$,".")
	label_file$ = label_file$+"txt"
endif	


# construct filenames with paths (sound_ile$ must not end in '.wav')!
textgrid_file$ = replace_regex$(sound_file$,"\..*$","\.TextGrid",1)
textgrid_file$ = textgrid_directory$ + textgrid_file$

#
## 3) check existens of files 
#

# check whether label file exists

label_file$ = label_directory$+label_file$
if !fileReadable (label_file$)
	printline File "'label_file$'" not found!
	exit
endif

# sound file must exist

sound_file$ = directory$+sound_file$
if !fileReadable (sound_file$)
	printline File "'sound_file$'" not found!
	exit
endif

#
## 4) pre-set variables for labelling
#

# nr. of labels in the label file / Strings list (e.g. Label.txt)
nr_labels = 0
# pointer to the next label in the Strings list to be used
label_pnt = 1
# pointer to the label in the Strings list (increments, whereas 'label_pnt' is computed)
i_label = 1
# nr. of items in the TextGrid file / TextGrid object
# (remember that in an interval tier there is always one interval (from beginning to end, or at the end)
nr_textgrid_items = 0

# if no name for a tier is given, use default names

if length(tier_name$) = 0
	if tier_type = c_interval_tier
		tier_name$ = "Segment"
	elsif tier_type = c_point_tier
		tier_name$ = "Point"
	endif
	printline Default tier name "'tier_name$'" will be used!
endif

#
## 5) Read files
#

# read (new) labels

Read Strings from raw text file: "'label_file$'"
base_label$ = selected$ ("Strings")
nr_labels = Get number of strings

# check whether the TextGrid has already labels, and if the tier
# already exists, get the number of segments/points in it:
# in that case, I assume that the user wants to continue after the 
# last segment/point. I deliberately do NOT check in such a case 
# whether the names in the label file are the same as in the TextGrid,
# since the user might have changed the labels in the TextGrid (e.g. to
# indicate that the realized items where different from the names 
# expected in the label file)!

# pre-set variables (as if nothing exists)
# We will use different pointers for 'items' (= points or intervals) and 'labels' (= points/intervals with names)

textgrid_exists = c_false
tier_exists = c_false
use_tier = 1

# check whether a TextGrid exists, and if yes, whether the tier name exists 

if fileReadable (textgrid_file$)
	textgrid_exists = c_true
	Read from file: "'textgrid_file$'"
	nr_tiers = Get number of tiers
# go thru tiers and compare tier names with the one set by the user
	for i_tier to nr_tiers
		file_tier_name$ = Get tier name: 'i_tier'
# tier name found - check whether type is the same and there is space for labels
		if file_tier_name$ = tier_name$
			x_type = Is interval tier: 'i_tier'
			if (tier_type = c_point_tier) and (x_type = c_true)
				printline 'newline$'You requested a point tier, but the file has an interval tier "'tier_name$'".
				printline Since I don't know what you would like to have,
				printline I ask you to restart this script with a different tier name 
				printline or adjusted settings.
				plusObject: "Strings 'base_label$'"
				Remove
				exit
			elsif (tier_type = c_interval_tier) and (x_type = c_false)
				printline 'newline$'You requested an interval tier, but the file has a point tier "'tier_name$'".
				printline Since I don't know what you would like to have,
				printline I ask you to restart this script with a different tier name 
				printline or adjusted settings.
				plusObject: "Strings 'base_label$'"
				Remove
				exit
			endif
			tier_exists = c_true
			use_tier = i_tier
# tier is an interval tier?
			if (x_type = c_true)
				nr_textgrid_items = Get number of intervals: 'use_tier'
# check whether all labels might already be set
# handle the following situations
!  |seg|	|seg|		|seg|		|		interval, gap, delayed_start
## not implemented ## !seg|		|seg|		|seg|		|		interval, gap, immediate_start
## not implemented ## !  |seg|seg|seg|		|					interval, no_gap, delayed_start
!seg|seg|seg|		|					interval, no_gap, immediate_start
!pnt|pnt|pnt|								point (always no_gap, immediate_start

# remember that there is always an empty interval at the end!
				if gap_type = c_no_gap
					nr_items = nr_labels + 1
				elsif gap_type = c_gap
					nr_items = nr_labels * 2
				endif		
				if zero_start = c_delayed_start
					nr_items += 1
				endif
# tier is a point tier!
			else
				nr_textgrid_items = Get number of points: 'use_tier'
				nr_items = nr_labels
			endif
# nr. of items in tier is larg(er) than nr. of labels in label file?
			if nr_textgrid_items >= nr_items
				printline 'newline$'All labels are already set in file "'textgrid_file$'"!
				plusObject: "Strings 'base_label$'"
				Remove
				exit
			endif

# force loop (which is looking for the tier name) to exit 

			i_tier = nr_tiers + 1
		endif
	endfor
endif

# okay, it seems to be worth to open the sound file finally

Read from file: "'sound_file$'"
base_name$ = selected$("Sound")

#
## 6) Go thru file
#

# create TextGrid if it does not exist (otherwise, it's loaded already)

if textgrid_exists = c_false
	if tier_type = c_interval_tier
		To TextGrid: "'tier_name$'", ""
		nr_textgrid_items = 1
	elsif tier_type = c_point_tier
		To TextGrid: "'tier_name$'", "'tier_name$'"
		nr_textgrid_items = 0
	endif

# create tier if it doesn't exist (but TextGrid is already loaded in this case!)

elsif tier_exists = c_false
	selectObject: "TextGrid 'base_name$'"
	if tier_type = c_interval_tier
		Insert interval tier: 'use_tier', "'tier_name$'"
		nr_textgrid_items = 1
	elsif tier_type = c_point_tier
		Insert point tier: 'use_tier', "'tier_name$'"
		nr_textgrid_items = 0
	endif
endif

# okay, we can finally start setting marks

selectObject: "Sound 'base_name$'"
plusObject: "TextGrid 'base_name$'"
Edit

# nr_textgrid_items are the items in the TextGrid, label_pnt has to point to the next label in the label file
# handle the following situations:
## not yet ## !  |seg|	|seg|		|seg|		|		interval, gap, delayed_start
!seg|		|seg|		|seg|		|				interval, gap, immediate_start
## not yet ## !  |seg|seg|seg|		|					interval, no_gap, delayed_start
!seg|seg|seg|		|								interval, no_gap, immediate_start
!pnt|pnt|pnt|											point (always no_gap, immediate_start

# now we compute the pointer into the label file accordingly 
# (we want to hande the next TextGrid label, i.e. we have to increase it by one eventually)

if tier_type = c_point_tier
	label_pnt = nr_textgrid_items + 1
elsif gap_type = c_no_gap
	label_pnt = nr_textgrid_items
elsif gap_type = c_gap
	label_pnt = floor((nr_textgrid_items+1) / 2)
endif

# insert 'zero_start' handling eventually here

# labelling loop
c_first_mark = 0
c_second_mark = 1
state = c_first_mark
if (tier_type = c_interval_tier) and (gap_type = c_gap)
	selectObject: "TextGrid 'base_name$'"
	before = Get number of intervals: 'use_tier'
	even = ((2 * floor(before/2)) = before)
	if even
		state = c_second_mark
	endif
endif

last_time = 0
for i_label from label_pnt to nr_labels
	selectObject: "Strings 'base_label$'"
	label$ = Get string: 'i_label'

# ask for user iteraction. find out whether the user inserted a mark or not

	if tier_type = c_point_tier
		beginPause ("'label$': Please move cursor to next point and then press 'Set Point'")
		answer = endPause ("Continue later/Exit","Set Point",2)
	elsif (gap_type = c_no_gap) or (state = c_second_mark)
		selectObject: "TextGrid 'base_name$'"
		before = Get number of intervals: 'use_tier'
		Set interval text: 'use_tier', 'before', "'label$'"
		beginPause ("'label$': Please move cursor to end of interval and then press 'Set Right Boundary'")
		answer = endPause ("Continue later/Exit","Set Right Boundary",2)
	elsif state = c_first_mark
		beginPause ("'label$': Please move cursor to next beginning of interval and then press 'Set Left Boundary'")
		answer = endPause ("Continue later/Exit","Set Left Boundary",2)
	else
		printline 'newline$'"Inconsistent point/gap/no gap logic (1); please inform a programmer"
		exit
	endif

# get cursor position
	editor TextGrid 'base_name$'
		if (zero_crossings = 1)
			Move cursor to nearest zero crossing
		endif	
		x_time = Get cursor
	endeditor

	if answer = 1
# the user pressed the 'continue later' button, i.e. s/he wants to leave the script
# force exit
		now_label = i_label - 1
		i_label = nr_labels + 10

# handle input
	elsif x_time = last_time
		printline Please move the cursor first to a new position.
		i_label -= 1 
	else
		last_time = x_time
		selectObject: "TextGrid 'base_name$'"

# handling point tier?
		if tier_type = c_point_tier
			Insert point: 'use_tier', 'x_time', "'label$'"
			Write to text file: "'textgrid_file$'"

# setting intervals!
# no gaps between intervals? 
		elsif (gap_type = c_no_gap) or (state = c_second_mark)
			Insert boundary: 'use_tier', 'x_time'
			Write to text file: "'textgrid_file$'"
			state = c_first_mark

# there are gaps between intervals (the number of intervals must be uneven (since there is always one interval after the last segment))!
		elsif state = c_first_mark
			Insert boundary: 'use_tier', 'x_time'
			state = c_second_mark
			i_label -= 1
		else
			printline 'newline$'"Inconsistent point/gap/no gap logic (2); please inform a programmer"
			exit
		endif

	endif

endfor

# save file and clean up

selectObject: "TextGrid 'base_name$'"
Write to text file: "'textgrid_file$'"
plusObject: "Sound 'base_name$'"
plusObject: "Strings 'base_label$'"
Remove

if i_label = (nr_labels+1)
	if tier_type = c_point_tier
		printline 'newline$'All 'nr_labels' points are set in 'textgrid_file$'!
	else
		printline 'newline$'All 'nr_labels' intervals are set in 'textgrid_file$'!
	endif
elsif answer = 1
	printline 'newline$'Script aborted by user!'newline$''now_label' label(s) saved.
endif

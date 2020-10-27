##
# This script is intended to generate 'pitch contours' of segments to support
# the comparison / evaluation of contours.
#
#	This script opens all sound files in a directory and their associated TextGrids,
#	computes the pitch of all segments (in Hz, ERB or st) in steps that have a name
#	and writes the results (eventually converted into z-scores) as a percentage of the time 
# to the text file "pitch_contour_results<date_time>.txt" at the same directory of the sound file.
#
#   Version 1.0, Henning Reetz, 05-sep-2016; modified version of pitsch_mean_1_1.praat
#   Version 2.0, Henning Reetz, 19-sep-2016; data is now centered at analysis steps
#   Version 2.1, Henning Reetz, 22-sep-2016; fast option added
#   Version 2.2, Henning Reetz, 22-sep-2016; subtract mean option added
#   Version 2.3, Henning Reetz, 04-oct-2016; dummy data line (forcing JMP to get correct data type) option added
#   Version 2.4, Henning Reetz, 06-oct-2016; missing data indicator added; FO as 'range' in form
#   Version 2.5, Henning Reetz, 13-oct-2016; for n intervals, n+1 data points are reported; unique output file name
#   Version 2.6, Henning Reetz, 16-oct-2016; corrected timing computation of innermost loop
##

clearinfo

## 0) preset some parameters
# change these as yiou prefer them (and/or add things from the form menu below)

# dummy = 0: no extra data line at the beginning of the output file 
# dummy = 1: additional line of data to force automatic data-type detection (e.g. in JMP) to set the correct data type 
dummy = 0

# missing-data indicator of your spreadsheet/statistics program
missing$ = "NA"

# extension of the audio files
ext$ = ".wav"

# maximal number of intervals for reporting the contour
max_step = 50

## 1) Inquire some parameters
# ! Note that 'form' may only be used once in a script!

form Pitch contour parameters (Vers. 2.6):
	comment Leave the directory path empty if you want to use the current directory.
	text directory
	comment Which tier should be analyzed?
	integer tier 1
	comment ______________________________________________________________________________________________________________
	integer Number_of_intervals 10
	choice Unit: 3
		button Hertz
		button ERB
		button semitones
	choice Method: 1
		button mean around position
		button median around position
		button at position
	choice Normalizing: 2
		button none
		button z_score
		button subtract mean
	comment Fast processing (no screen output)?
		boolean fast 1
	comment ______________________________________________________________________________________________________________
	real step_rate 0.005
	real left_F0_range 50.0
	real right_F0_range 500.0
endform

# pitch mean and st.dev. need different units for semitones

if unit$ = "semitones"
	unit_mean$ = "semitones re 1 Hz"
else 
	unit_mean$ = unit$
endif

## check consistency

if (number_of_intervals < 1) or (number_of_intervals > max_step)
	printline Only between 1 (= whole segment) and 'max_step' intervals per segment are possible.
	printline Script aborted.
	exit
endif

## 2) crate result file and write a header line

call GetDate date_time$
result_file$ = directory$+"pitch_contour_results_"+date_time$+".txt"
#filedelete 'result_file$'
fileappend 'result_file$' File'tab$'Label'tab$'Beginning[s]'tab$'Duration[ms]

# intervals as percentage
perc_step = 100.0 / number_of_intervals
perc = 0
for i to (number_of_intervals+1)
	fileappend 'result_file$' 'tab$''perc:0'%
	perc = perc + perc_step
endfor

# report computational method
fileappend 'result_file$' 'tab$'('normalizing$' normalizing 'method$' in 'unit_mean$')'newline$'

# add dummy data- row if requested
if (dummy = 1) 
	fileappend 'result_file$' Dummy'tab$'Dummy'tab$'0.0'tab$'0.0
	for i to (number_of_intervals+1)
		fileappend 'result_file$' 'tab$'0.0
		perc = perc + perc_step
	endfor
	fileappend 'result_file$' 'newline$'
endif

#  3) Get file names from a directory
#	We assume here that it is more likely that a '.TextGrid' file exists if there is a sound file 
#	(whereas sound files often exist without a '.TextGrid' file)

Create Strings as file list...  file_list 'directory$'*.TextGrid
number_of_files = Get number of strings

if (fast = 1)
	print Computing... 
endif

# go thru files
for i_file to number_of_files
	select Strings file_list
	grid_file_name$ = Get string... i_file
	Read from file: "'directory$''grid_file_name$'"
	base_name$ = selected$("TextGrid")
	if (fast <> 1) 
		print Handling 'base_name$' 
	endif

# try to open .wav files for this TextGrid

	sound_file_name$ = directory$+base_name$+ext$
	if fileReadable (sound_file_name$) 
# next line not really necessary - just to prevent errors if we cut-n-paste this part into another script where things might be different
		select TextGrid 'base_name$'

# check whether tier 1 is an interval tier.

		tier_is_interval = Is interval tier... tier
		if  tier_is_interval = 1

# Compute the pitch of the selected sound (whole file). 

			Read from file: "'sound_file_name$'"
			end_of_file = Get end time
			if (fast = 1)
				noprogress To Pitch: 'step_rate', 'left_F0_range', 'right_F0_range'
			elsif (fast <> 1)
				To Pitch: 'step_rate', 'left_F0_range', 'right_F0_range'
			endif

# Use the TextGrid to find all labeled segments.

			select TextGrid 'base_name$'
			nr_segments = Get number of intervals: 'tier'
			for i to nr_segments
				select TextGrid 'base_name$'
				interval_label$ = Get label of interval: 'tier', 'i'
				if interval_label$ <> ""

# Report segment positions 

					begin_segment = Get starting point: 'tier', 'i'
					end_segment   = Get end point:      'tier', 'i'
					duration = (end_segment - begin_segment) * 1000
					fileappend 'result_file$' 'base_name$''tab$''interval_label$''tab$''begin_segment:4''tab$''duration:3'
					select Pitch 'base_name$'

# Get the mean pitch value for normalizing

					if (normalizing$ <> "none")
						f0_mean = Get mean: 'begin_segment', 'end_segment', "'unit_mean$'"
						f0_stdev = Get standard deviation: 'begin_segment', 'end_segment', "'unit$'"
					endif

# Get pitch chunks of segment; use 'mid' as guiding time

					dur = (end_segment - begin_segment) / number_of_intervals
					mid = begin_segment

# go thru interval in n+1 steps, starting at the left edge (= 'mid')
# make sure not to go beyond borders of recording 
# (needed only for first and last segments for median/mean methods, but doesn't hurt otherwise) 

					for i_step to (number_of_intervals+1)
						beg = mid - dur/2
						beg = max(0,beg)
						end = beg + dur
						end = min(end_of_file,end)

# get data depending on method

						if (method$ = "mean around position")
							f0 = Get mean: 'beg', 'end', "'unit_mean$'"
						elsif (method$ = "median around position")
							f0 = Get quantile: 'beg', 'end', 0.5, "'unit_mean$'"
						elsif (method$ = "at position")
							f0 = Get value at time: 'mid', "'unit_mean$'", "Linear"
						else
							exit Unknown method. Program aborted.
						endif
						
# pitch value exists?
						if f0 <> undefined
# z-score requested?
							if (normalizing$ = "z_score")
# avoid division by zero
								if ((f0_stdev <> undefined) and (f0_mean <> undefined))
									z = (f0 - f0_mean) / f0_stdev								
									fileappend 'result_file$' 'tab$''z:2'
								else
									fileappend 'result_file$' 'tab$''missing$'
								endif
# mean subtract requested?
							elsif (normalizing$ = "subtract mean")
								if (f0_mean <> undefined)
									d = (f0 - f0_mean)								
									fileappend 'result_file$' 'tab$''d:2'
								else
									fileappend 'result_file$' 'tab$''missing$'
								endif
# no normalization requested
							else
								fileappend 'result_file$' 'tab$''f0:1'
							endif
# no pitch value found							
						else
							fileappend 'result_file$' 'tab$''missing$'
						endif
# update positions for next chunk						
						mid = mid + dur
					endfor
					
# now we have reached the right edge					
# add a newline for this data set
					fileappend 'result_file$' 'newline$'
				endif									# interval has a label

			endfor									# going thru all intervals

		else											# tier 1 is not an interval tier
			print 'newline$' Tier 1 of 'base_name$'.TextGrid is not an interval tier. File ignored. 'newline$' 
		endif										# test whether tier 1 is an interval tier
# clean up
		select TextGrid 'base_name$'
		plus Sound 'base_name$'
		plus Pitch 'base_name$'
		Remove
		if (fast <> 1) 
			printline finished.
		endif
		
	else											# no '.wav' file found
		if (fast = 1)
			printline Handling 'base_name$'
		endif
		printline failed! No sound file "'directory$''base_name$''ext$'" found. <***
		Remove
	endif											# test for readable sound file
endfor											# going thru all '.TextGrid' files

# clean up

select Strings file_list
Remove
if (number_of_files = 1)
	printline Done.'newline$''number_of_files' file processed, F0 data written to 'result_file$'.
else
	printline Done.'newline$''number_of_files' files processed, F0 data written to 'result_file$'.
endif

#convert Praat's date and time to a date-and-time string

procedure GetDate date_time$

	date_time$ = date$()
	year$ = right$(date_time$,2)
	month$ = mid$(date_time$,5,3)
	day$ = mid$(date_time$,9,2)
	time$ = mid$(date_time$,12,8)

	if (month$ = "Jan")
		month$ = "01"
	elsif (month$ = "Feb")
		month$ = "02"
	elsif (month$ = "Mar")
		month$ = "03"
	elsif (month$ = "Apr")
		month$ = "04"
	elsif (month$ = "May")
		month$ = "05"
	elsif (month$ = "Jun")
		month$ = "06"
	elsif (month$ = "Jul")
		month$ = "07"
	elsif (month$ = "Aug")
		month$ = "08"
	elsif (month$ = "Sep")
		month$ = "09"
	elsif (month$ = "Oct")
		month$ = "10"
	elsif (month$ = "Nov")
		month$ = "11"
	elsif (month$ = "Dec")
		month$ = "12"
	else
		month$ = "xx"
	endif
	time$ = replace$(time$,":","",0)
	date_time$ = year$+month$+day$+"_"+time$

endproc
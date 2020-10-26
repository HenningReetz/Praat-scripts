##
# Get a list of all directories and subdirectories
#
# This is a bit tricky since PRAAT does not support recursiveness with local variables.
#	I programmed the following using a Table:
#
#	1) Get a list of directories starting at the present directory (= 'dir_list')
#	2) set a pointer to the beginning (= 'now_dir_pnt') of this list and another to the end of the list (= 'nr_dir_list')
#	3) while the 'now_dir_pnt' has not gone beyond 'nr_dir_list', do the following
#		3a) get all directories in the directory to which 'now_dir_pnt' points
#		3b) append this list to 'dir_list' and increase the end_pointer (= 'nr_dir_list')
#		3c) increase 'now_dir_pnt' (i.e. point to the next (dub-)directory in the list
#
# After this is done (marked by a line of hashes ##), I added here two versions to show what can be 
# done with this list:
#
# 10) Go thru this list and open all TextGrid- and wav-files in the resp. (sub-)directories
#			This part may be helpful in case you want to add your specific code (e.g. compute formants) for each file.
#
# 20)	Build a list of all 'basic' names and write it to a file
# 		(Doing this under Unix/Mac with an ls command is much simpler, but we're here in Praat)
#
# 21) Read the file again and open all TextGrid- and wav-files
#			This part may be helpful if you want to list all files in all (sub-)directory once (using part 20)
#			and then read in another script the list (using part 21) and do your work. This makes sense in case
#			different scripts should be run thru all files without the need to collect all files again and 
#			again (which itself is rather fast, but the script is very long).
#
#	Note that the latter parts (10 and 20+21) assume that wav- and TextGrid files are in the same (sub-)directory,
# and that they end in ".wav" and ".TextGrid" (with exactly this spelling and capitalization)!
#
# Version 1.0, Henning Reetz, 31-jan.-2009	first version
#	Version 2.0, Henning Reetz, 13-june-2009	use Tables to create a list of all directories and files
#	Version 3.0, Henning Reetz, 07-dec.-2014	use new Praat script syntax
#	Version 3.1, Henning Reetz, 16-dec.-2014	added 'removeObject:'
#
#	Tested with Praat 5.4.0
#
##

# clear the info window
clearinfo

# Initiate the procedure by creating a table with the present 'starting' directory as seed.
# This 'dir_table' becomes an object in PRAAT and has 'nr_dir_list' rows.
#	'now_dir_pnt' points into this table to the directory which will be searched for sub-directories;
#	if there are sub-directories, they will be added to the end of this table. Eventually, 
#	'now_dir_pnt' will point to the first, second, third... of these sub-directories, which themselves 
#	will be investigated for sub-directories. By this procedure, the search will go deeper and deeper
#	into the tree of (sub-)directories.

# Start with the present directory (must end with a slash (/) !)
dir_name$ = "./"

# total number of directories already found (at present only the starting directories)
nr_dir_list = 1

# create a Table with one line as a seed for the directory list
# (I use the dummy row header 'xxx' to identify the one row. I haven't found a way to handle all this
#  without a name for the row.)
Create Table with column names: "dir_table", 'nr_dir_list', "xxx"
Set string value: 'nr_dir_list', "xxx", "'dir_name$'"

# pointer to the directory in the table of directories under investigation
# (actually points one to low)
now_dir_pnt = 0

# Continue as long as 'now_dir_pnt' has not reached 'nr_dir_list'
#	Note, that at the beginning, 'now_dir_pnt' points to '0', i.e. below the beginning of the table.
#	'now_dir_pnt' will be incremented inside the loop; i.e. 'now_dir_pnt' will be incremented by '1'
# and points then to the first directory in the table (which is the starting directory). 
# This might contain hundreds of sub-directories, which all will be investigated, because any newly 
# found sub-directory will increase 'nr_dir_list' and the next time the while-loop will compare this
# new value of 'nr_dir_list' with	'now_dir_pnt' (still at '1' at the beginning) and the loop will be
# entered again.
while now_dir_pnt < nr_dir_list

# Point to the next directory in the list to be investigated (at the beginning, this is '1',
# i.e. the first directory in the list). The test of the while-loop makes sure that we cannot
# go beyond 'nr_dir_list'.
	now_dir_pnt += 1

# Make sure that we point to the table (= 'dir_table')
	selectObject: "Table dir_table"
	
# Now get the name of the directory to which 'now_dir_pnt' points to 	
	dir_name$ = Get value: 'now_dir_pnt', "xxx"

# Now create a new list of all sub-directories of the directory to which 'now_dir_pnt' points
	Create Strings as directory list:  "new_dir_list", "'dir_name$'*"

# Get the number of sub-directories ('new_dir_list' is automatically selected by the previous command)
	nr_new_dir_list = Get number of strings
	
# The command "Create Strings as directory list:" started from the directory to which
# 'now_dir_pnt' pointed. We will need the full path-name and add therefore the name
# of the 'now_dir_pnt' directory in front of the newly found names inside 'new_dir_list'.
# To do so, we go thru all 'nr_new_dir_list' names in 'new_dir_list'
# Get the 'i'th name from the new list and then we add them to the table.
	for i to nr_new_dir_list

# Point to the list of strings of directory names
		selectObject: "Strings new_dir_list"

# Get one directory name		
		new_dir_name$ = Get string: 'i'

# Add the 'now_dir_pnt' name (which is in 'dir_name$') in front of it.
# Remember, that 'dir_name$' ends already with a slash ("/") to mark the end of a directory name!
# Note further, that 'dir_name$' might be a sub-sub-sub-directory already (i.e., there might be several
#	slashes in it), i.e., we construct here the full directory path.			
		new_dir_name$ = dir_name$+new_dir_name$+"/"

# Now add this name to the directory table
# Select this table first...
		selectObject: "Table dir_table"

# ...add a row...
		Append row

# ...count this row (and point to it)...
		nr_dir_list += 1

# ...and finally insert the new directory name.
		Set string value: 'nr_dir_list', "xxx", "'new_dir_name$'"

# looping thru all names in the 'new_dir_list'
	endfor

# We remove the (empty) 'new_dir_list'
	removeObject: "Strings new_dir_list"

# Okay, we have done everything for the present 'now_dir_pnt' directory. The "while" on top
# will check whether there are any more directories in 'dir_list_ to be investigated.
endwhile

# The algorithm above will investigate first all directories in the 'starting' directory,
# then it goes down one sub-directory level thru all these directories, then it will investigate
# the next level for all sub-directories, etc.
# But you might want to go from one directory first into all its sub-(sub-..)directories and after 
# that to the next directory (and all its sub-directories). To do so, we sort the 'dir_list' which 
# will bring related names closer together.
# Select 'dir_list' first...
selectObject: "Table dir_table"

# ... and sort it.
Sort rows: "xxx"

# Report to the user:
printline 'nr_dir_list' directories found.
printline

####################################################################################################
#                  End of part that collects all directories                                       #
####################################################################################################
####################################################################################################
#             Beginning of part (10) that opens TextGrid- and wav-files                            #
####################################################################################################

# un-comment the next line if you want to test section (20) of this script
goto PART_2

##
#
# There is now a table 'dir_table' with a row named 'xxx' of all sub-sub-...-directories.
#
#	Here comes now the first example how to use the directory table:
#	The following script goes thru all sub-directories we have found and looks for all 
# '.TextGrid' to which '.wav' files exist. 
# 
##

# 'nr_total' is the number of all '.TextGrid' files
nr_total = 0

# 'nr_pairs' is the number of all '.TextGrid' and '.wav' pairs
nr_pairs = 0

# Now go thru all (sub-)directories we have found
for i_dir to nr_dir_list

# select the directory table (since we change to other objects in this loop)
	selectObject: "Table dir_table"

# get the 'i_dir'.th (sub-)directory name	
	dir_name$ = Get value: 'i_dir', "xxx"

# create a list of all files in this (sub-)directory that end in ".TextGrid"
	Create Strings as file list: "textgrid_list", "'dir_name$'*.TextGrid"

# get the number of TextGrid-files in this (sub-)directory
	nr_of_textgrids = Get number of strings

# add it to the total number of TextGrid files
	nr_total += nr_of_textgrids

# inform user what we will do next
	printline Handling 'dir_name$' with 'nr_of_textgrids' TextGrids.

# go thru all TextGrid files of this (sub-)directory
	for i_file to nr_of_textgrids

# select list of TextGrid file names 
		selectObject: "Strings textgrid_list"
		
# get the 'i_file'.th name (it's without the full path)
		textgrid_file_name$ = Get string: 'i_file'

# add the path in front
		textgrid_file_name$ = dir_name$+textgrid_file_name$

#	read the TextGrid file
		Read from file: "'textgrid_file_name$'"

# extract the 'base' name (i.e., the file name without path and '.TextGrid' extension, as it is used in Praat's object-list
		base_name$ = selected$ ("TextGrid")

# If you are handling several hundreds short files, you might want to comment the next line out
		print Handling 'dir_name$''base_name$' 
		
# try to open a .wav file for this TextGrid: construct the fiel name and check whether file exists
		ext$ = ".wav"
		sound_file_name$ = dir_name$+base_name$+ext$
		if fileReadable (sound_file_name$) 

# count this '.wav' pair
			nr_pairs += 1

# .TextGrid and .wav file exists. Read the .wav file. 
			Read from file: "'sound_file_name$'"

#### --> Do whatever you want to do here <--

# remove TextGrid and sound objects from object list			
			removeObject: "Sound 'base_name$'"
			removeObject: "TextGrid 'base_name$'"

# tell user that we're done
			printline finished. 
			
# normal file handling finished.
# This 'else' part is entered when there is no '.wav'-file for a '.TextGrid' file
		else
		
# inform user about missing '.wav' file
			printline failed! No sound file 'sound_file_name$' found. <***

# TextGrid object is still selected; remove it
			Remove

# 'endif' of test whether '.wav'-file exists			
		endif
		
# 'endfor' of loop going thru all files in a (sub-)directory		
	endfor

# Remove the list of TextGrid-files for this (sub-)directory
	removeObject: "Strings textgrid_list"

# 'endfor' of loop going thru all (sub-)directories
endfor

# remove the Table of all directory names
removeObject: "Table dir_table"

# inform user
printline
if nr_pairs != nr_total
	printline Done. 'nr_pairs' sound files for 'nr_total' TextGrid files found.
else
	printline Done. 'nr_pairs' TextGrid files processed.
endif


# This exit is here to prevent that this demo-version runs into the next section, which demonstrates 
# how to write a list of .TextGrid and .wav file into a text file.
exit

####################################################################################################
#                  End of part (10) that opens TextGrid- and wav-files                             #
####################################################################################################
####################################################################################################
#  Beginning of part (20) that puts all base names (when TextGrid- and wav-files exist) in a Table #
####################################################################################################

label PART_2

##
#
# There is now a table 'dir_table' with a row named 'xxx' of all sub-sub-...-directories.
#
#	Here comes now the second example how to use the directory table:
#	The following script goes thru all sub-directories we have found and looks for all 
# '.TextGrid' to which '.wav' files exist. A table with 'base' names of these file-pairs 
# is put into a table which is eventually written to a raw text file. Is is actually a 
# good point to end this script, since it creates a file with a list of all files that might be 
# analysed by another Praat script.
#
# However, here I added at the end such a script (as a third part), that reads this raw text file 
# and does something with it.

# 'nr_total' is the number of all '.TextGrid' files
nr_total = 0

# 'nr_pairs' is the number of all '.TextGrid' and '.wav' pairs
nr_pairs = 0

# Create a table for all (base) file names
Create Table with column names: "file_table", 0, "xxx"

# Now go thru all (sub-)directories we have found
for i_dir to nr_dir_list

# select the directory table (since we change to other objects in this loop)
	selectObject: "Table dir_table"

# get the 'i_dir'.th (sub-)directory name	
	dir_name$ = Get value: 'i_dir', "xxx"

# create a list of all files in this (sub-)directory that end in ".TextGrid"
	Create Strings as file list:  "textgrid_list", "'dir_name$'*.TextGrid"

# get the number of TextGrid-files in this (sub-)directory
	nr_of_textgrids = Get number of strings

# add it to the total number of TextGrid files
	nr_total += nr_of_textgrids

# inform user what we will do next
	printline Handling 'dir_name$' with 'nr_of_textgrids' TextGrids.

# go thru all TextGrid files of this (sub-)directory
	for i_file to nr_of_textgrids

# select list of TextGrid file names 
		selectObject: "Strings textgrid_list"
		
# get the 'i_file'.th name (it's without the full path)
		textgrid_file_name$ = Get string: 'i_file'

# add the path in front
		textgrid_file_name$ = dir_name$+textgrid_file_name$

#
# the file name has the extension '.TextGrid' - this file must be there, 
# otherwise it would have not been put into this list. I actually do not want to do
# anything with this file (at the moment) but I only want to check whether the
# associated '.wav' file is there. Hence, I replace the "TextGrid" at the end of the
# file name with "wav" (Note, that ".TextGrid" could exist several times in the file name,
# but only the last should be replaced - that's why I use this 'regular expression' function
#
		wav_file_name$ = replace_regex$(textgrid_file_name$,"TextGrid$","wav",1)

# check whether this file there
		if fileReadable (wav_file_name$) 

# Okay. '.TextGrid' and '.wav' files exist. Count this case.
			nr_pairs += 1

# Put the 'base' name (with path) into the table of all file names
# Construct first a base-name...
			base_file_name$ = replace_regex$(wav_file_name$,".wav$","",1)

# ... select the file_list Table...
			selectObject: "Table file_table"
			
# ... make space for a new entry ...
			Append row

# ... and write the base name into this table
			Set string value: 'nr_pairs', "xxx", "'base_file_name$'"

# We're done with this pair.
# This 'else' part is entered when there is no '.wav'-file for a '.TextGrid' file
		else
		
# inform user about missing '.wav' file
			printline No sound file 'wav_file_name$' found . <***

# 'endif' of test whether '.wav'-file exists			
		endif
		
# 'endfor' of loop going thru all files in a (sub-)directory		
	endfor

# Remove the list of TextGrid-files for this (sub-)directory
	removeObject: "Strings textgrid_list"

# 'endfor' of loop going thru all (sub-)directories
endfor

# remove the Table of all directory names
removeObject: "Table dir_table"

# Now write the Table to a file. First select the table
selectObject: "Table file_table"

# ... then write it to the file 'file_list.Table'
Write to table file: "file_list.Table"

# clean up: Remove Table
Remove

# inform user
printline
if nr_pairs != nr_total
	printline Done. 'nr_pairs' sound files for 'nr_total' TextGrid files found.
else
	printline Done. 'nr_pairs' TextGrid files processed.
endif
printline The names of these 'nr_pairs' TextGrid files written to "file_list.Table".


####################################################################################################
#       End of part (20) that creates a text file with all .TextGrid / .wav file pairs             #
####################################################################################################
####################################################################################################
#              Beginning of part (21) that uses this text file to do something with it             #
####################################################################################################

# read in the table
Read Table from table file: "file_list.Table"

# get number of rows
nr_files = Get number of rows

# go thru each file (= row)
for i_file to nr_files

# select the table (it might have been de-selected in the loop)
	selectObject: "Table file_list"

# get one line (= base file name) from the table
	base$ = Get value: 'i_file', "xxx"

# inform user (note that there is a space after 'base$'
	print Handling 'base$' 

# construct files names, e.g. .wav and .TextGrid file names
	wav_file_name$ = base$+".wav"
	textgrid_file_name$ = base$+".TextGrid"
	
# read the files
	Read from file: "'wav_file_name$'"
	Read from file: "'textgrid_file_name$'"

# the 'base$' has the ful path in it, which Praat does not list in the object list.
# To address the objects, we have to remove the path from the name (with another regular expression)!
	base$ = replace_regex$(base$,".*/","",1)


## ---> Do whatever you want to do here


# now we remove the objects
	removeObject: "Sound 'base$'"
	removeObject: "TextGrid 'base$'"
	
# inform user
	printline finished.
	
# end of file-loop
endfor

# clean up
removeObject: "Table file_list"

# inform user
printline
printline Done. 'nr_files' files processed.
	
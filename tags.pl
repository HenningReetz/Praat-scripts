#/usr/bin/perl -w

## build in 
## - Unix-like switches? 
## - implement @@ comments

##@@ add /seg  switch: report each segment in an own line.
##@@!! get rate for each file seperately!!

use strict;

my $version=0;								# 03-may-05, hr (henning reetz): first implementation
my $revision=1;								# 19-sep-06, hr: include PRAAT files
my $bugfix=0;									# not extensively tested

# pre-set switches to control the behavior of the program

my $trace = 0; 								# trace for NSP-header

my $out_file;									# name of result file
my $out_type;									# 'position', 'distance'
my $out_t;										# used for output header
my $out_form;									# 'samples', 'ms', 'hz'
my $out_f;										# used for output header
my $mark_type = 'tag';				# 'tag', 'impulse'
my $sub_directories=0;				# no subdirectory handling 
my $full_names=0;							# no full names with paths
my $sort_by_tags=0;						# sort by number of tags

my $buf;											# general purpose buffer
my %nr_tag_hash;							# hash for nr. of tags
my @out_buf;									# output buffer

my $rate = 0;
my ($bytes,$samples,$level_a,$level_b);	# important header information
my @tag_buf;													# buffer for tags/impulses

my ($pos,$down);							# used for subdirectory search
my (@file_name, @segment_name);	# filename (with path) and segmentname (without path)

# read switches from the user

while ($#ARGV >= 0) {					# as long as there are command line arguments
	my $command = shift(@ARGV);		# get one
	if ($command =~ /^he/) {				# help?
		print "\n";
		print "tags.pl extracts the tags or impulses of NSP or PRAAT files.\n\n";
		print "tags.pl computes the distances between tags in ms.\n";
		print "possible switches:\n\n";
		print " dist   compute distances between tags (default)\n";
		print " dur    compute durations between tags (same as dist)\n";
		print " pos    compute positions form beginning of file\n";
		print "\n";
		print " ms	   report in ms (default)\n";
		print " hz	   report in hz (not  valid for positions)\n";
		print " sam	   report in samples\n";
		print "\n";
		print " sub	   go through all subdirectories\n";
		print " full   report full names (including subdirectory path)\n";
		print "\n";
		print " sort	 sort output by least nr. of segments first\n";
		print "\n";
		print " imp	 	use impulse-marks, not tags (only for NSP files)\n";
		print "\n\n";
		print "For example:\n";
		print "	tags.pl pos sam sub sort\n";
		print "Reports all positions of tags in samples of all NSP files in all sub-directories and reports those files first, that have the least nr. of tags.\n";
		die "\n";
		
	} elsif (($command =~ /^di/) || ($command =~ /du/)) {		# distance or duration
		$out_type = 'distance';
		$out_t = 'd';
	} elsif ($command =~ /^fu/) {		# report full names (with path)
		$full_names = 1;
	} elsif ($command =~ /^hz/) {		# report distances in Hz
		$out_form = 'hz';
		$out_f = 'hz';
	} elsif ($command =~ /^im/) {		# use impulse marks (and not tags)
		$mark_type = 'impulse';
	} elsif ($command =~ /^ms/) {		# report results in ms
		$out_form = 'ms';
		$out_f = 'ms';
	} elsif ($command =~ /^po/) {		# report positions
		$out_type = 'position';
		$out_t = 'p';
	} elsif ($command =~ /^sa/) {		# report results in sample number (@@start at 0 or 1?? )
		$out_form = 'samples';
		$out_f = 'sm';
	} elsif ($command =~ /^so/) {		# sort output (least number of tags first)
		$sort_by_tags = 1;
	} elsif ($command =~ /^su/) {		# include all subdirectories
		$sub_directories = 1;
	} else {												# unknown switch
		print "Argument \"$command\" ignored.\n";
	}																# if-ten-elsing commands
}																	# analysing command line

if (($out_type eq '') || ($out_form eq '')) {
	if ($out_type eq '') {
		$out_type = 'distance';
		$out_t='d';										# used for output header
	}
	if ($out_form eq '') {
		if (($mark_type eq 'impulse') && ($out_type ne 'position')) {
			$out_form = 'hz';
			$out_f='hz';								# used for output header
		} else {
			$out_form = 'ms';
			$out_f='ms';								# used for output header
		}
	}
}

if ($mark_type eq 'tag') {
	$out_file = 'tags.txt'
} elsif ($mark_type eq 'impulse') {
	$out_file = 'impulses.txt'
} else {
	die "Programming error: Illegal mark_type: \"$mark_type\" at out_file assignment.\n\n";		
}

print "\ntags.pl, Vers. $version.$revision.$bugfix\n";
if (($out_type eq 'position') && ($out_form eq 'hz')) {
	die "Positions cannot be reported in Hz.\n";
}

# recursive subroutine to find all files with uppercase or lowercase .NSP in their name

sub SubDir {							# go into subdirectory
	my $curdir = $_[0];			# name of directory
	if ($curdir ne ".") {		# not present one?
		$pos .= "$curdir/";		# make it a full path name
		$down++;							# count the depth
		chdir "$curdir";			# change directory
	}												# test for present directory
	my @content = <*>;			# all file names
	foreach my $file (@content) {		#	go thru each file
		if (-d $file) {								# is it a subdirectory?
			if ($sub_directories==1) {	# and if subdirectory search is on (do not 'and' this with subdirectory test!!)
				&SubDir($file);						# go into subdirectory
			}														# going into subdirectory
		} else {											# otherwise (could be a directory here!!)
			my $help = $pos.$file;			# path with filename
			if ((lc($help) =~ /\.nsp$/) || (lc($help) =~ /\.textgrid$/)) {# filename ends in .nsp or .textgrid?
				push (@file_name,$help);	# put it onto the stack
				if ($full_names == 0) {		# no fullnames report wanted?
					$help = $file;					# use only file name (without path)
				}													# fullname required?
				$help =~ s/.nsp//i;				# remove .nsp from names
				$help =~ s/.textgrid//i;	# remove .textgrid from names
				push (@segment_name,$help);	# store segment name
			}														# name with .nsp at the end?
		}															# file or subdirectory test
	}																# going thru all file of a directory

	if ($down>0) {						# are we in a subdirectory?
		chdir "..";							# go up again 
		$pos =~ s/(.*\/).*\///;	# remove path, but store first part in $1
		$pos = $1;							# restore first part of path
		$down--;								# step up in depth counter
	}													# stepping up

}														# subaroutine for subdirectory handling

sub GetNspHeader {
	my $in_file = $_[0];

	my $file_length;											# length of file (needed only for trace)
	my $header;														# NSP-header flag (only one allowed)
	my $block;														# NSP-block (MKA, SDA, etc.)
	my ($tot_len,$sum);										# length of data in file

	if ($trace == 1) {										# trace required
		print "$in_file\t";									# report filename
		$file_length = -s $in_file;					# length of file
	}

	if (open (IN, "<$in_file") != 1) {
		print "can't open \"$in_file\"\n";
		return 0;
	}																			# open nsp file (but continue if it fails)
	binmode IN;														# go into bin-mode (i.e., it's not character i/o)
	
# read file header (put it in a subroutine)	
	
	read (IN, $buf, 4);										# get first 4 bytes
	$sum += 4;														# count bytes
	if ($buf ne 'FORM') {									# NSP files start with 'FORM'
		print "File $in_file does not contain CSL/MultiSpeech data header (\"FORM\").\n";
		return 0;
	}

	read (IN, $buf, 4);										# get next 4 bytes
	$sum += 4;														# count bytes
	if ($buf ne 'DS16') {									# must be 'DS16'
		print "File $in_file does not contain CSL/MultiSpeech data header (\"DS16\").\n";
		return 0;
	}
	
	read (IN, $buf, 4);										# get next 4 bytes
	$sum += 4;														# count bytes
	$tot_len = unpack('V',$buf);					# data length of file (can be shorter than MSDOS-file length!) 'VMS' format (it's INTEL)
	if ($trace == 1) {										# trace wanted?
		print "File_length: $file_length, Tot_len: $tot_len\n";	
	}
	$tot_len += $sum;											# total length of NSP-data in file

	while  ($tot_len > $sum) {						# still data in file?

# read block code and length of block

		read (IN, $block, 4);								# read next block header
		$sum += 4;													# 4 bytes read
		if ($trace == 1) {									# trace wanted?
			print "$block, ";
		}
		read (IN, $buf, 4);									# length of block
		$sum += 4;													# 4 bytes read
		my $len = unpack('V',$buf);					# length of block in integer
		if ($trace == 1) {									# trace wanted?
			print "$len\n";
		}
		
# check blocks		
		
		if ($block eq 'HEDR') {							# header block
			if ($header != 0) {								# only one header allowed
				print "File $in_file has more than one CSL/MultiSpeech data headers.\n";
				return 0;
			}
			$header = 1;											# set header-found flag
		
			if ($len != 32) {									# header must be 32 bytes long
				print "File $in_file has an invalid CSL/MultiSpeech data header (\"HEDR\" is $len).\n";
				return 0;
			}
			read (IN, $buf, 20);							# date; format is "Dec 21 12:04:21 2004"
			read (IN, $buf, 4);								# next 4 bytes
			$rate = unpack('V',$buf);					# are the sampling rate
			read (IN, $buf, 4);								# next 4 bytes
			$bytes = unpack('V',$buf);				# length of data part in samples
			read (IN, $buf, 2);								# next 2 bytes
			$level_a = unpack('v',$buf);			# maximal level of left channel
			read (IN, $buf, 2);								# next 2 bytes
			$level_b = unpack('v',$buf);			# maximal level of right channel
			if ($trace == 1) {								# trace wanted?
				print "Rate: $rate, Length: $bytes, level_a: $level_a, level_b: $level_b\n";
			}
			$sum += 32;												# add header bytes

		} elsif (($block eq 'SDA_') || ($block eq 'SD_B')) {	# sample block (mono)
			$samples = $len / 2;							# 16-bit samples, i.e. 2 bytes = 1 sample
#			print "Samples: $samples\n";
			seek (IN,$len,1);									# skip data
#			read (IN, $buf, $len);						# read samples
			$sum += $len;											# add data bytes
		
		} elsif ($block eq 'SDAB') {				# 2-channel sample block
			$samples = $len / 4;							# 2 * 16-bit samples, i.e., 4 bytes = 1 samples
#			print "Samples: $samples\n";
			seek (IN,$len,1);									# skip samples
#			read (IN, $buf, $len);
			$sum += $len;											# add data bytes

		} elsif ($block eq 'NOTE') {				# note-block
			$len = int(($len+1)/2) * 2;				# make it an even number of bytes 1=>2; 2=>2
			read (IN, $buf, $len);						# read even number of bytes
			$sum += $len;											# add bytes
#			print "Note: $buf $len\n";
		
		} elsif (($block eq 'MKA_') || ($block eq 'MK_B') || ($block eq 'MKAB')) {	# tag
			$len = (int(($len+1)/2) * 2) - 4;	# make length even and subtract 4 byes for position
			read (IN, $buf, 4);								# read 4 bytes (position of tag)
			$sum += 4;												# add 4 bytes
			if ($mark_type eq 'tag') {				# if tags are evaluated (and not impulses)
				my $pos = unpack('V',$buf);			# get position of tag (in sample number)
				push (@tag_buf,$pos);						# store tag
			}
			read (IN, $buf, $len);						# read name of tag
			$sum += $len;											# add length of tag
#			print "MKA: $buf $pos $len\n";

		} elsif (($block eq 'PKA_') || ($block eq 'PK_B') || ($block eq 'PKAB')) {	# tag
			if ($mark_type eq 'impulse') {		# if impulsess are evaluated (and not tags)
				for (my $i=0; $i < $len; $i+=4) {
					read (IN, $buf, 4);						# read impulses
					my $pos = unpack('V',$buf);		# get position of impulse (in sample number)
					push (@tag_buf,$pos);					# store impulse
				}
			} else {
				seek (IN,$len,1);								# skip pulses
			}
			$sum += $len;											# add length of data section
#			print "PKA: $len\n";

		} else {
			print "File $in_file has an unrecognized block type (\"$block\") at byte $sum.\n";
			read (IN, $buf, $len);						# hope that the length was stored in 'len'
		}
	}																			# handling header blocks

	return $rate;									# successful return
}

sub GetPraatTextgrid {
	my $in_file = $_[0];

	my @input;
	my ($file_length, $help);

	if ($trace == 1) {										# trace required
		print "$in_file\t";									# report filename
		$file_length = -s $in_file;					# length of file
	}

	if (open (IN, "<$in_file") != 1) {
		print "can't open \"$in_file\"\n";
		return 0;
	}																			# open nsp file (but continue if it fails)

	$/ = "\n";									# works with UNIX and DOS (reset, since $/ might have changed before
	@input = <IN>;							# read file linewise into array
	if ($#input == 0) {					# last array-element is 0 => mac file?
		$/ = "\r";								# use MAC EOL
		seek (IN,0,0);				# wind file back to beginning
	  @input = <IN>;				# read file again
	}

##@@ this input method removes the nr_line info, that might be helpful for the user!

	my $state=0;
	my ($pos, $mark);
	
	foreach (@input) {
		my $help = $_;

# skip lines until 'TextTier' is found	

		if ($trace == 1) {									# trace wanted?
			print "$help\n";
		}
		$help =~ s/\n|\r//g;

		if ($help =~ /TextTier/) {
			$state = 1;
		}
		
		if ($state == 0) {
			next;
		} elsif ($state == 1) {
			if ($help =~ /time = /) {
				$pos = $';
				print "time: $pos\n"; 		
				$state = 2;
			}
		} elsif ($state == 2) {
			if ($help =~ /mark = /) {
				$mark = $';
				print "mark: $mark\n"; 		
				push (@tag_buf,$pos);						# store tag
##@@				push (@mark_buf,$pos);						# store tag
				$state = 1;
			} else {
				print "Mark after Time missing in $in_file.\n";	
			}
		}
	}
		
	if ($state == 0) {
		print "No TextTier found in $in_file.\n";	
	}

	return 1;									# successful return
}


# here's the main program

&SubDir('.');							# get all .nsp file names (probably with subdirectories)

# treat each NSP-file

foreach my $in_file (@file_name) {			# handle all files

# extract header (including tags and impulses) of file
##@@@ get rate for each file!!!
	$rate = -1;
	if (lc($in_file) =~ /\.nsp$/) {
		$rate = &GetNspHeader($in_file);
	}	elsif (lc($in_file) =~ /\.textgrid$/) {			# filename ends in .textgrid?
		$rate = &GetPraatTextgrid($in_file);
	}
print $rate.' ';
=pod
	prepare tags for output:
	put 'nr. of tags', 'file/segment name', 'tag data' together into one line, separated by '#' 
	sorting this line will put the files with the least 'nr. of tags' first (if there are less than 10)
	dissembling this line, gives the sorted or unsorted output fro the user
	(in other words, this concatenation with '#' and splitting later is unnecessary if there is no sorting involved.
	but by this procedure, the activity is the same, and only one 'sort' is missed.)
=cut

	my $nr_tag = $#tag_buf + 1;						# first tag is in position '0'
	$nr_tag_hash{$nr_tag}++;							# increase "how many files have <nr. of tages"

	my $segment = shift(@segment_name);		# get tag name (might be without path if wanted)
	my $out_line;
	
	if ($sort_by_tags == 1) {							# if the lowest nr. of tags should be on top
		if ($nr_tag < 10) {									# only one decimal position?
			$out_line = "00$nr_tag#";					# start with nr_tag for alphabetic sort
		} elsif ($nr_tag < 100) {						# only two decimal positions?
			$out_line = "0$nr_tag#";					# start with nr_tag for alphabetic sort
		} else {														# three or more more decimal positions (more than three are unlikely, sop I don't bother)
			$out_line = "$nr_tag#";						# start with nr_tag for alphabetic sort
		}																		# adding zeros in front to get nice sort results
	} else {															# sort only alphabetically (and not by number of tags/impulses)
		$out_line = "0#";										# add the same dummy number for each file to block sorting by number-of-tags
	}
	$out_line .= "$segment";							# add segment name for alphabetic sort

	@tag_buf = sort({$a <=> $b} @tag_buf);# sort tags them by position

	my $last;															# used to compute distances
	if ($out_type eq 'distance') {				# report distances?
		$last = shift(@tag_buf);						# get first 'left' sample
	}
	while (my $pos = shift(@tag_buf)) {		# get next tag
		if ($out_type eq 'distance') {			# report distances?
			$last = $pos - $last;							# distance between samples
		} elsif ($out_type eq 'position') {														# otherwise report positions
			$last = $pos;											# just the position
		} else {
			die "Programming error: Illegal out_type: \"$out_type\" in data generation.\n\n";		
		}
if ($rate == 0) { $rate = -1; }  ##@@@ why is rate here zero?
		if ($out_form eq 'ms') {						# report in ms?
			$last = ($last / $rate) * 1000;		# convert position/distance to ms
		} elsif ($out_form eq 'hz') {				# report in hz?
			$last = ($rate / $last);					# convert to hz (positions are excluded at the beginning of the program in this condition!)
		}																		# format conversion handling
		$out_line .= "#$last";							# report position/distance
		$last = $pos;												# present tag is 'left' of next tag (needed for distance handling; useless operation for positions)
	}																			# going thru all tags
	push (@out_buf,$out_line);						# save output line

}																				# going thru all files

# all data of all files read in and are prepared for output
# construct a nice header taht codes what in the columns
# on the way, tell the user how many files with how many tags you have found

my $max_tag = -1;												# highest number of tags in any file
print ("\n");
foreach my $nr_tag (sort { $nr_tag_hash{$a} <=> $nr_tag_hash{$b} } keys %nr_tag_hash) {	# sort all tags; least nr. of tags first
	if ($mark_type eq 'tag') {
		printf ("%3d files with %2d tags found.\n",$nr_tag_hash{$nr_tag},$nr_tag);					# how many times are there <nr_tag? tags
	} elsif ($mark_type eq 'impulse') {
		printf ("%3d files with %2d impulses found.\n",$nr_tag_hash{$nr_tag},$nr_tag);			# how many times are there <nr_tag? tags
	} else {
		die "Programming error: Illegal mark_type: \"$mark_type\" in data reporting.\n\n";		
	}
	if ($nr_tag > $max_tag) {
		$max_tag = $nr_tag;			# last nr_tag has highest number (since it's sorted) but still I need the ($nr_tag > $max_tag)... no idea why (probably they optimize something wrongly)
	}
}

# generate output file

if ($max_tag <= 0) {
	die "\nNo output file generated.\n\n";	
}

open OUT,">$out_file";

if ($out_type eq 'distance') {			# distances have one distance less than there are tags
	$max_tag--;												# subtract this one nr. of tag
}

# generate nice header to make obvious, what the columns represent:
# {d|p}{sm|ms|hz}{1|1-2} i.e.
#	{distance or position}{samples or milliseconds or hertz}{#position or #from-#to}

my $label = "File";									# file name (i.e. segment; can be without path)
for (my $i=1; $i<=$max_tag;) {			# go thru all possible positions/distances
	$label .= "\t$out_t$out_f$i";			# gives 'psm' or 'dhz' etc. followed by tag nr.
	$i++;
	if ($out_type eq 'distance') {		# for distances
		$label .= "-$i"									# use from-to numbers
	}																	# 'distance' handling
}																		# constructing names for columns
print OUT "$label\n";								# print header line

# sort lines

#if ($sort_by_tags == 1) {						# sort wanted?
	@out_buf = sort(@out_buf);				# sort output liunes
#}

# report lines

foreach my $line (@out_buf) {												# for each line
	my @element = split('#',$line);										# dissemble it by the hash-symbol inserted
																										# zero element is nr. of positions/distances and can be a dummy - ignore it
	print OUT $element[1];														# report segment/file name
	for (my $i=2; $i<=$#element; $i++) {							# go thru positions/durations
		if ($out_form eq 'samples') {										# report samples
			printf (OUT "\t%10d",$element[$i]);						# as fixed point
		} elsif (($out_form eq 'ms') || ($out_form eq 'hz')) {	# ms and hz
			printf (OUT "\t%8.2f",$element[$i]);					# as loating point with 2 decimals 
		} else {
			die "Programming error: Illegal out_form: \"$out_form\" in output routine.\n\n";		
		}
	}																									# goint thru positions/durations

	print OUT "\t."x($max_tag - $#element + 1)."\n";	# fill up rest with dots

}

if ($mark_type eq 'tag') {
	print "\nTag data was written to \"$out_file\"\n\n";
} elsif ($mark_type eq 'impulse') {
	print "\nImpulse data was written to \"$out_file\"\n\n";
} else {
	die "Programming error: Illegal mark_type: \"$mark_type\" at the end of program.\n\n";		
}

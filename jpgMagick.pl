#!/usr/bin/perl
# This script does various transformations on jpegs in the directory that it's in.
# The original jpegs are moved out to a folder (which is cleared first if it's not empty).
# Uses PerlMagick API.

# Prerequisites:  a system with Perl on, and a folder of jpegs (without spaces in the names).

# Drop this file into the parent folder that you want to work on, open a Terminal there,
# enter the name of this file, hit return, and watch the progress!

use strict;  use warnings;
use File::Basename;
use File::Copy 'move';
use File::Path qw(make_path remove_tree);
use Image::Magick;
use POSIX;
use Scalar::Util qw(looks_like_number);

# First, create a time check:
END { print "\nThis Perl program ran for ", time() - $^T, " seconds.  All changes reported.\n"}

# And a response hash for the conversions:
my $imgdone;
my %resph = (
	'c' => '$image->Charcoal($param); $imgdone = $image->[0]',
	'g' => '$image->Resize(geometry => \'1000x800\'); $imgdone = $image->[0]',
#	- preserves ratio, never exceeding either of these dimensions.
	'k' => '$image->Sketch(0); $imgdone = $image->[0]',
#   'p' => '$imgdone = $image->Preview(\'Charcoal\')',
	's' => '$image->Resize(geometry => \'1150\'); $imgdone = $image->[0]',
);

# Next, request input for conversions:
my ($scrbn,$dir,$ext) = fileparse($0, qr/\.[^.]*/);
my $ors = "./$scrbn"."_originals";
print "You are about to move all jpegs in the current folder to $ors !!\n";
print "hit Enter to quit, or go ahead with one of these ImageMagick conversion choices:\n";
foreach my $key (sort keys %resph){print "  Enter $key for $resph{$key}\n";}
my $resp = <STDIN>;
chomp $resp; # Get rid of newline character at the end
my @params = (0);  # - this array needs at least one value for later
unless ($resph{$resp}) {print "Quit!  "; exit 0;}  # - if there's no response hash value chosen
# in special case requiring a parameter list, fill out more values:
if ($resp eq 'c') {
	if ($resp eq 'c') {@params = (0, 90)}
	else {@params = (1, 2, 3, 4, 5, 6, 7, 8, 9)}  # - not actually used, but left in
	print "Enter to go ahead with these factor values: @params\n",
		"  or Enter your own space-separated list of factor value(s):\n";
	my @fresp = split(/\s+/, <>);  # - get the response into an array (even a null array)
	if (@fresp) {  # - user's fed in a factor list of some sort, so check & possibly tidy it:
		my @userf =();
		foreach my $entry (@fresp) {
			if (looks_like_number($entry)) {
				if ($resp eq 'c') {$entry = int($entry)}
				if ($entry >= 0 && $entry <= 99){push @userf, $entry}
			}
		}
		@params = @userf
	}
}
print "Okay, working.  ";

# Create an image object:
my $image = Image::Magick->new;

# Empty or create the directory to move the originals into:
remove_tree($ors,{keep_root=>1});
mkdir $ors;  # - made it anyway if it weren't there...
print "Originals will be moved to $ors\n";

# Now work through the directory collecting jpeg file names:
opendir(DIR, '.');
my @jpegs = grep { /\.jpg$/ && -f "./$_" } readdir(DIR);
closedir(DIR);

# Finally, work through the list of jpegs, applying the relevant conversion:
print "  $resph{$resp}";
local $| = 1;  # - turns off line buffering on STDOUT
my $jpgname;
foreach my $jpeg (@jpegs) {
	print "\n  Converting $jpeg ";
	my $jpegbn = substr $jpeg, 0, -4;
    $image->Read($jpeg);
	foreach my $param (@params) {
		my $tmstmp = POSIX::strftime("%H%M%S", localtime);
		if ($params[1]) {print $param." ".$tmstmp." "}
		eval $resph{$resp}; warn $@ if $@;
		$jpgname = "./$jpegbn"."_$param$resp.jpg";  # - adding in parameter tag to jpeg name
		$imgdone->Write(filename => "./$jpgname");
	}
	move $jpeg, "$ors/$jpeg";
	unless ($params[1]) {move $jpgname, "$jpegbn$resp.jpg"}  # - remove an unused parameter tag
	@$image = ();  # - empty the object, ready for next i/o
#print " - done!\n"
}
undef $image;

#!/usr/bin/perl
# Joseph Harriott  http://momentary.eu/ Wed 11 Apr 2018

# This script was useful while building a website,
# but has since got into a tangle and needs repairs, at least for GNU/Linux.
# It won't work on Windows 10 because PerlMagick won't install...

# This script does various transformations on jpegs in the directory that it's in.
# The original jpegs are moved out to a folder (which is cleared first if it's not empty).
# Uses PerlMagick API.

# Prerequisites:  a system with Perl on, and a folder of jpegs (without spaces in the names).

# Drop this file into the parent folder that you want to work on, and run it.

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
my $label;
my %resph = (
	'b' => '$imageObject->Border(width=>\'9\', height=>\'9\', bordercolor=>\'goldenrod4\'); $imgdone = $imageObject->[0]',
	'c' => '$imageObject->Composite(image=>$label, gravity=>\'southeast\'); $imgdone = $imageObject->[0]',
	'g' => '$imageObject->Resize(geometry => \'1000x800\'); $imgdone = $imageObject->[0]',
#	- preserves ratio, never exceeding either of these dimensions.
#	- badly degrades pencil sketches...
	'h' => '$imageObject->Charcoal($param); $imgdone = $imageObject->[0]',
	'k' => '$imageObject->Sketch(0); $imgdone = $imageObject->[0]',
	'l' => '$imageObject->Resize(geometry => \'314\'); $imgdone = $imageObject->[0]',
	'n' => '$imageObject->Negate(); $imgdone = $imageObject->[0]',
	'o' => '$imageObject->OilPaint($param); $imgdone = $imageObject->[0]',
#   'p' => '$imgdone = $imageObject->Preview(\'Charcoal\')',
    'p' => '$imgdone = $imageObject->Preview(\'OilPaint\')',
	'r' => '$imageObject->Chop(geometry => \'0x1000\'); $imageObject->Chop(geometry => \'0x300\', gravity => \'South\'); $imageObject->Chop(geometry => \'1000x0\', gravity => \'East\'); $imageObject->Chop(geometry => \'300x0\', gravity => \'West\'); $imgdone = $imageObject->[0]',
	's' => '$imageObject->Resize(geometry => \'1150\'); $imgdone = $imageObject->[0]',
	't' => '$imageObject->Resize(geometry => \'90\'); $imgdone = $imageObject->[0]',
#   'v' => '$imageObject->Level(levels=>\'0,50%,7.0\'); $imgdone = $imageObject->[0]',
#                                 = black and white points, then gamma
    'v' => '$imageObject->Level(levels=>\'0,100%,\'.$param); $imgdone = $imageObject->[0]',
#                                 - using a range, defined below.
);

# Next, request input for conversions:
my ($scrbn,$dir,$ext) = fileparse($0, qr/\.[^.]*/);
my $ors = "./$scrbn"."_originals";
print "You are about to move all jpegs in the current folder to $ors !!\n";
print "hit Enter to quit, or go ahead with one of these ImageMagick conversion choices:\n";
foreach my $key (sort keys %resph){print "  Enter $key for $resph{$key}\n";}
my $resp = <STDIN>;
chomp $resp; # Get rid of newline character at the end
my @params = (-1);  # - this array prep'd with a negative number for later.
unless ($resph{$resp}) {print "Quit!  "; exit 0;}  # - if there's no response hash value chosen
# in special case requiring a parameter list, fill out more values:
if ($resp eq 'h' || $resp eq 'o' || $resp eq 'v') {
	if ($resp eq 'h') {@params = (0, 90)}
	elsif ($resp eq 'o') {@params = (0, 0.5, 1, 1.5, 2, 3, 5)}
	elsif ($resp eq 'v') {@params = (3.3, 3.4)}
	print "Enter to go ahead with these factor values: @params\n",
		"  or Enter your own space-separated list of factor value(s):\n";
	my @fresp = split(/\s+/, <>);  # - get the response into an array (even a null array)
	if (@fresp) {  # - user's fed in a factor list of some sort, so check & possibly tidy it:
		my @userf =();
		foreach my $entry (@fresp) {
			if (looks_like_number($entry)) {
				if ($resp eq 'h') {$entry = int($entry)}
				if ($entry >= 0 && $entry <= 99){push @userf, $entry}
			}
		}
		@params = @userf
	}
} elsif ($resp eq 'c') { # load in the label:
	if (-e "label.png") {
		$label = Image::Magick->new;
		$label->Read("label.png")}
	else {
		print "No label.png here!"; exit 0}
}
print "Okay, working.  ";

# Create an image object:
my $imageObject = Image::Magick->new;

# Empty or create the directory to move the originals into:
remove_tree($ors,{keep_root=>1});
mkdir $ors;  # - made it anyway if it weren't there...
print "Originals will be moved to $ors\n";

# Now work through the directory collecting jpeg file names:
opendir(DIR, '.');
my @jpegs = grep { /\.jpg$/i && -f "./$_" } readdir(DIR);
closedir(DIR);
print "\nThe images: @jpegs\n\n"; # debug

# Finally, work through the list of jpegs, applying the relevant conversion:
print "  $resph{$resp}";
local $| = 1;  # - turns off line buffering on STDOUT
my $jpgname;
my $prmstr;
my $jpgA = "jpgMagickinputASCII.jpg"; # - an unambiguous temporary ASCII name
# (a precaution: if Image::Magick's Read method is used on a filename containing `é`
# on Windows 7, this script fails at the Write method)
foreach my $jpeg (@jpegs) {
	print "\n  Converting $jpeg ";
	my $jpegbn = substr $jpeg, 0, -4; # the jpeg's basename
	# temporarily move the jpeg to an uncomplicated filename:
	move $jpeg, $jpgA;
#   $imageObject->Read($jpeg);
    $imageObject->Read($jpgA);
	foreach my $param (@params) {
		my $tmstmp = POSIX::strftime("%H%M%S", localtime);
		# neatly format the parameter strings for adding to changed filename:
		if ($resp eq 'o' || $resp eq 'v') {$prmstr = sprintf("%.1f", $param)}
		else {$prmstr = sprintf("%02s", $param)}
		print "\n\n\$prmstr = $prmstr\n\n"; # debug
		if ($params[1]) {
			print $prmstr." ".$tmstmp." "  # - just reporting time as a progress check
		}
		# eval $resph{$resp}; warn $@ if $@; # - do the conversion!
		$imageObject->Negate(); $imgdone = $imageObject->[0]; warn $@ if $@; # - do the conversion!
		$jpgname = "$jpegbn"."_$prmstr$resp.jpg";  # - adding in parameter tag to jpeg name
		# Here I'm again taking care not to feed a filename that might contain
		# something like an `é` to Image::Magick because on Windows 7,
		# that character becomes the Replacement character, fffd:
		$imgdone->Write(filename => "./$prmstr.jpg");
		move "$prmstr.jpg", $jpgname;
	}
	move $jpgA, "$ors/$jpeg";
	if ($params[0] < 0) {move $jpgname, "$jpegbn$resp.jpg"}  # - remove an unused parameter tag
	@$imageObject = ();  # - empty the object, ready for next i/o
#print " - done!\n"
}
undef $imageObject;

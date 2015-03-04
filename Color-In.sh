#!/bin/bash
# vim: set tw=0

# Joseph Harriott http://momentary.eu/ Wed 04 Mar 2015
# Convert images to Children's Color-In Outline Image
# ----------------------------------------------------
# as at http://www.imagemagick.org/Usage/photos/#texture
# haven't figured how to include this in jpgMagick.pl yet...

outd="Originals-$(date +%Y%m%d-%H%M%S)"
echo $outd
mkdir $outd
for inf in *jpg
do
outf="${inf%.*}-CI.jpg"
echo -en "\r$outf"
convert $inf -edge 1 -negate -normalize -colorspace Gray -blur 0x.5 -contrast-stretch 0x50% $outf
mv $inf $outd
done
echo


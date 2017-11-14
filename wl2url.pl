#!/usr/bin/perl -wT
# wl2url - create .url files from .webloc files
# $Id: wl2url 400 2005-12-31 08:13:13Z ranga $
#
# wl2url converts MacOS X .webloc files to Microsoft style .url files.
#
# MacOS X .webloc files store the url in the resource fork while .url 
# files are simple text documents with the following format:
#
# [InternetShortcut]
# URL=<url>
#
# wl2url extracts the url from a .webloc file using DeRez as follows:
# 
# /Developer/Tools/DeRez -e [file] -only 'url '
# 
# The output is similar to the following:
#
# data 'url ' (256, "Sriranga Veeraraghavan.webloc") {
#   $"6874 7470 3A2F 2F77 7777 2E63 7375 612E"       /* http://www.csua. */
#   $"6265 726B 656C 6579 2E65 6475 2F7E 7261"       /* berkeley.edu/~ra */
#   $"6E67 612F"                                     /* nga/ */
# };
#
# The url is stored in the c-style comment at the end of the line. 
#
# For more information see:
#
# http://www.macosxhints.com/article.php?story=20040111200114634&mode=print
# http://www.macosxhints.com/article.php?story=20040728185233128&mode=print
#
# If DeRez is not available, then strings is used instead:
#
# /usr/bin/strings [file]/rsrc
#
# The first line that starts with a ';' contains the url
#
# Copyright (c) 2003-2005 Sriranga Veeraraghavan <ranga@alum.berkeley.edu>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use, copy,
# modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

use strict;
use Getopt::Std;
use File::Spec;
use vars qw/ %OPTS /;

#
# main
#

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
$ENV{'PATH'} = "/bin:/sbin:/usr/bin:/usr/sbin";

my %PGMINFO = ( 'NAME'    => 'wl2url',
                'VERSION' => '0.3' );
            
my $DEREZ="/Developer/Tools/DeRez";
my $STRINGS="/usr/bin/strings";
my $FILE = "";
my $OUTFILE = "";
my $RC = 0;
my $URL = "";
my $NOFILE = 0;
my $DELFILE = 0;
my $QUIET = 0;
my $USESTRINGS = 0;
my @TMPFILES = ();
my $OPTSTR = "o:ndqhvs";
my $OUTDIR = "";

if (getopts($OPTSTR, \%OPTS)) {

    $NOFILE = 1 if ($OPTS{'n'});
    $DELFILE = 1 if ($OPTS{'d'});
    $QUIET = 1 if ($OPTS{'q'});
    $USESTRINGS = 1 if ($OPTS{'s'});
    
    if ($OPTS{'h'}) {
        printUsage();
        exit(0);
    }

    if ($OPTS{'v'}) {
        printVersion();
        exit(0);
    }
    
    $OUTDIR = $OPTS{'o'};
    if (defined($OUTDIR)) {
        if (! -d $OUTDIR) {
            printError("No such directory: '$OUTDIR'");
            exit(1);
        }    
    } else {
        $OUTDIR = "";
    }

} else {
    printUsage();
    exit(1);
}

if (scalar(@ARGV) < 1) {
    printUsage();
    exit(1);
}

foreach $FILE (@ARGV) {

    $URL = extractUrl($FILE);
    
    unless (defined($URL) && $URL ne "") {
        $RC = 1;
        next;
    }

    print "$URL\n" unless ($QUIET);
    
    next if ($NOFILE);

    $OUTFILE = $FILE;
    if ($OUTDIR ne "" && -d $OUTDIR) {
        $OUTFILE =~ s/^.*\///;
        $OUTFILE = "$OUTDIR/$OUTFILE";
    }
    $OUTFILE =~ s/\.webloc$//i;
    $OUTFILE =~ s/\.ftploc$//i;
    $OUTFILE .= ".url";

    if (createInternetShortcut($URL, $OUTFILE) < 0) {
        $RC = 1;
    } elsif ($DELFILE) {
        $RC = 1 if (deleteWebloc($FILE) < 0);
    }
}

exit($RC);

#
# subroutines
#

# extractUrl - extract the url from a webloc file

sub extractUrl
{
    my $haveDeRez = 0;
    my $url = "";
    my @parts = ();
    my $wlf = shift @_;

    $haveDeRez = 1 if (-x $DEREZ && $USESTRINGS == 0);

    if (defined($wlf) && -f $wlf && -r $wlf) {
        if ($wlf =~ /^(.*)$/) {
            $wlf = $1;
        } else {
            return $url;
        }
    } else {
        printError("Cannot read webloc file: '$wlf'");
        return $url;
    }
    
    # Open a pipe to use for DeRez (implicit fork)

    my $pid = open(FH,"-|");
    
    # Check if open/fork worked

    if (!defined($pid)) {
        printError("Cannot fork()");
        return $url;
    }

    # If pid is 0, this is the child, exec the cmd 

    if ($pid == 0) {
        if ($haveDeRez == 1) {
            exec($DEREZ, '-e', $wlf, '-only', "'url '");
        } else {
            exec($STRINGS, $wlf . '/rsrc');
        }
        exit(127);
    } 
    
    # This is the parent
    #
    # If we have DeRez then look for the url in a c-style
    # comment. Otherwise use strings and /rsrc to get at
    # the resource fork
    
    if ($haveDeRez == 1) {
        while (<FH>) {
            next unless (/\/\*/);
            @parts = split;
            $url .= "$parts[$#parts-1]"
                if (defined($parts[$#parts-1]));
        }
    } else {
        while (<FH>) {
            next unless (/^\;/);
            chomp();
            s/^\;//;
            $url = $_;
            last;
        }
    }

    close(FH);

    return $url;
}

# createInternetShortcut - creates an internet shortcut file

sub createInternetShortcut
{
    my $url = shift @_;
    return -1 unless (defined($url) && $url ne "");

    my $file = shift @_;
    return -1 unless (defined($file) && $file ne "");

    if (-f $file || -r $file) {
        printError("Outfile file already exists: '$file'");
        return -1;
    }

    if ($file =~ /^(.*)$/) {
        $file = $1;
    } else {
        return -1;
    }

    if (open(OUTFILE,">$file")) {
        print OUTFILE "[InternetShortcut]\r\nURL=$url\r\n";
        close(OUTFILE);
    } else {
        return -1;
    }
    
    return 0;
}

# deleteWebloc - delete the webloc file

sub deleteWebloc
{
    my $file = shift @_;
    return -1 unless (defined($file) && -f $file);

    if ($file =~ /^(.*)$/) {
        $file = $1;
    } else {
        return -1;
    }

    return (unlink($file) != 1 ? -1 : 0)
}

# printError - format and print an error message

sub printError
{
    print STDERR "ERROR: @_\n";
}

# printUsage - print the usage statement

sub printUsage
{
    print STDERR "$PGMINFO{'NAME'} [-dhnqsv] [-o dir] files\n"
}

# printVersion - print the version number

sub printVersion
{
    print "$PGMINFO{'NAME'} version $PGMINFO{'VERSION'}\n";
}

README
------

wl2url.pl v0.4
By Sriranga Veeraraghavan <ranga@calalum.org>

Homepage:

    https://github.com/srirangav/wl2url

Overview:

    wl2url converts MacOS X .webloc files to Microsoft style .url files.

    On MacOSX .webloc files historically stored the url in their resource 
    fork while .url files were simple text documents with the following 
    format:

        [InternetShortcut]
        URL=<url>
    
Usage:

    wl2url [-dhnqsv] [-o dir] [files]
    
        -d       - delete the webloc file
        -h       - print help and exit
        -n       - don't create a .url file
        -q       - quiet mode, don't print out any messages
        -s       - use strings (even if DeRez is available)
        -v       - print version and exit
        -o [dir] - put the url files in the specific directory
    
Install:

    1. Copy wl2url.pl to a directory in your $PATH.  For example:
    
        $ cp wl2url.pl ~/bin

    2. Copy wl2url.1 to a man page directory in you $MANPATH.  For
       example:

        $ cp wl2url.1 ~/man/man1

Supported MacOSX Versions:

    MacOSX 10.4+

History:

    v0.4 - update to look for DeRez in /usr/bin and to use the 
           path suffix "/..namedfork/rsrc" to access the resource
           fork because accessing the resource fork using the 
           suffix "/rsrc" was deprecated in MacOSX 10.7 
    v0.3 - initial GitHub release

License:

    Please see LICENSE.txt

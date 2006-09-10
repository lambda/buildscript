In order to be able to run build scripts created with Buildscript, you will
need Cygwin, Ruby and mkisofs. Follow these steps to install and run the
builder. These instructions assume that you already have a working Cygwin. 

1. Run Cygwin setup, select ruby, gcc, make, and rsync, and install them. 
2. Download cdrtools from ftp://ftp.berlios.de/pub/cdrecord/
3. Extract cdrtools, enter directory, make, make install,
   Note: If errors occur, see the message at the end of this readme, apply the 
         patch, and try again. 
4. Add the following line to your .bash_profile in your Cygwin home directory:
   export PATH=/opt/schily/bin:$PATH
5. Install Inno Setup Version 4 QuickStart Pack <ispack-4.2.7.exe>. 
   Note: Make sure you install the preprocessor and ISTool, and that it's all
         installed in C:\Program Files\.
   Note: This may be hard to find, as it's obsolete now. Inno Setup 5 may
   or may not be an acceptable substitute. 
6. Install RubyGems <http://rubygems.rubyforge.org>.
7. gem install rake
8. Run rake in this directory to execute the test suite, make sure the tests 
   pass. 
   Note: If there are errors about being unable to remap DLLs, then install
         the Cygwin package utils/rebase, and read the readme in 
         /usr/share/doc/Cygwin/rebase-#.#.README. If you get errors about 
         permissions being messed up, then fix your permissions with 
         "chmod 755 ~ /home".

== Trouble with cdrtools == 
From <http://www.mail-archive.com/cygwin@cygwin.com/msg64885.html>:

> I do not want to heat the discussion, but getline() in cygwin played
> very hard against me.

Like I said in the other thread, you can fix this in Apache (and
cdrtools for that matter -- see attached patch) with a couple of
#defines in the offending files.  It's really simple.

... snip ...

diff -upr cdrtools-2.01/cdrecord/cue.c /usr/src/cdrtools-2.01/cdrecord/cue.c
--- cdrtools-2.01/cdrecord/cue.c        2004-03-02 12:00:53.000000000 -0800
+++ /usr/src/cdrtools-2.01/cdrecord/cue.c       2005-12-17 16:22:53.796875000 
-0800
@@ -44,6 +44,8 @@ static        char sccsid[] =
 #include "auheader.h"
 #include "libport.h"
 
+#define getdelim schily_getdelim
+
 typedef struct state {
        char    *filename;
        void    *xfp;
diff -upr cdrtools-2.01/include/schily.h /usr/src/cdrtools-2.01/include/schily.h
--- cdrtools-2.01/include/schily.h      2004-03-04 16:30:40.000000000 -0800
+++ /usr/src/cdrtools-2.01/include/schily.h     2005-12-17 16:19:09.015625000 
-0800
@@ -39,6 +39,8 @@
 #ifndef _SCHILY_H
 #define        _SCHILY_H
 
+#define getline schily_getline
+
 #ifndef _STANDARD_H
 #include <standard.h>
 #endif


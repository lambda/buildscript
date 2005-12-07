[Files]
;; This file is used by the installer itself.
Source: helper.txt; Flags: dontcopy
Source: README.txt; DestDir: {app}; Components: base
Source: Media\*.txt; DestDir: {app}\Media; Excludes: CVS,.cvsignore,*.bak,.#*,#*,*~; Flags: recursesubdirs; Components: media
Source: Media2\*; DestDir: {app}\Media; Excludes: CVS,.cvsignore,*.bak,.#*,#*,*~; Flags: recursesubdirs; Components: media

[Components]
Name: base; Description: Base Files; Flags: fixed; Types: custom regular full
Name: media; Description: Media Files; Types: custom regular
#ifdef BLUE_MOON
Name: debug; Description: Debugging Support
#endif

[Files]
;; This file is used by the installer itself.
Source: foo.txt; DestDir: {app}; Components: base
Source: bar.txt; DestDir: {app}; Components: base
Source: sub\*.txt; DestDir: {app}\sub; Excludes: CVS,.cvsignore,*.bak,.#*,#*,*~; Flags: recursesubdirs; Components: sub
Source: MANIFEST.base; DestDir: {app}; Flags: skipifsourcedoesntexist; Components: base
Source: MANIFEST.sub; DestDir: {app}; Flags: skipifsourcedoesntexist; Components: sub

[Components]
Name: base; Description: Base Files; Flags: fixed; Types: custom regular full
Name: sub; Description: Sub-Directory Files; Types: custom regular full
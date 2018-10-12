Neverending Party
=====
Script to automate the Neverending Party IOTM

Installation
----------------
Run this command in the graphical CLI:
<pre>
svn checkout https://github.com/Ezandora/Neverending-Party/trunk/Release/
</pre>
Will require [a recent build of KoLMafia](http://builds.kolmafia.us/job/Kolmafia/lastSuccessfulBuild/).

Usage
----------------
Commands:  
__free__: only complete free fights  
__quest__: complete quest (on by default)  
__noquest__: only complete free fights, do not start quest (best for in-run)  
__hard__: hard mode, if available  
__mall__: open favors and sell results in mall  
  
Example usage:  
__party quest__: complete quest  
__party hard__: complete hard mode quest  
__party noquest__: use when in-run - won't complete quest.  
__party free__: only use free fights, but will complete the quest if it can.  
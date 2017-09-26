#///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////#
# 
# The automated backup "script" consists of two files: a Perl 5 module source cpanelAutobackup.pm and a Perl 5 script fullcpBackup.pl
# Having a separate module has a number of pros, such as:
#
#	- Less chance of side effects;
#	- Better error-handling;
#	- Object Oriented (classic, without any postmodern Perl OOP modules, such as: Moose, Moo etc. Ensures compatibility);
#	- Simpler script structure;
#   - Full SSL support;
#
# The cons include:
#
#   - The scripts have been written to have least side effects possible; however, there can be issues with using it on DSs and VPSs
#     that might have corrupted cPanel Perl libraries;
#   - The script focuses on not using ecnrypted connections, it might seem as a advantage; although, not quite as non-ssl support
#     would give it more versatility;
#
#////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////#
# 
# Pre-usage disclaimer:
# 
# The duo works fine on our Shared servers as the cPanel installations provide with the necessary Perl modules for the cpanelAutobackup's
# proper functioning. 
#
# How to use it?
# 
# Using is rather easy. There is option to use it both from the command line/shell interface and as a cron job. 
# First thing to do is check your local Perl module/library directories added to the Perl 5 environment, this can be done several ways: 
# 
# 1) In your cPanel account => Perl Modules => under "Module Include Path";
# 2) In the Shell env. just by printing out the contents of the modules includes array:
#
#    perl -e 'print join "\n", @INC, "\n";'
# 
# The .pm files put into the directories are avaiable to be loaded from any Perl script that loads them with "use" built-in function.
# The location of the .pl file may vary, there are options to make is executable and add to one of the $PATH directories or just call
# it using the absolute path.
#
#////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////#
#
# Passed arguments:
#
# The scripts supports passing arguments from the command line to be able to:
#
# - Upload the backups to a remote location;
# - Specify another email address to sent the report to;
# 
# ! The passwords are better to be hardcoded and not passed as arguments as this is not a very good practice !
#
# Arguments that can be passed to the script:
#
#  1) Remote hostname/IPv4 address specification:
#
#     - server=
#     - host=
#     - servername=
#     - hostname=
# 
#  2) Remote user specification:
#
#     - user=
#     - username=
#
#  3) Remote port specification:
#
#     - port=
#
#  4) Remote target directory specification:
#
#     - dir=
#     - rdir=
#     - targetdir=
#
#  5) Email to send the backup report to specification:
#
#     - email=
#
#  6) Silent mode:
#
#     - silent
#     - quiet
#
#  ! The arguments have validation, so that no one tries to try supplying hostname value into "port" or not valid email address !
#
#////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////#
#
# In order to have the script upload to a remote machine, there are the following *mandatory* arguments to be passed to the script:
#
# -> 'remotePassword' => 'Your_Remote_User_Password' <- Should be specified during the object creation on line 30.
# ->  server <- 
# ->  user   <-
# ->  port   <-
# ->  dir    <-
#
# Otherwise the script will store the archive in the home directory.
#
#////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////#
#
# Email reporting
# 
# By default, the script will try getting the cPanel Contact Email if no "email=" argument supplied. In case of the account not having
# the contact email address, no report will be sent out.
#
# "email=" argument is not mandatory and be changed or not supplied at all ( this got me an idea to add a "silent" feature ).
#
# 
#
#
#
#
#
#
#////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////#
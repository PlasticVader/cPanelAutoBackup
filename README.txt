#///////////////////////////////////////////////////////////////////////////////#
# 
# The automated backup "script" consists of two files:
# module: AutoBackup.pm and script: cpbackup.pl
# Having a separate module has a number of pros, such as:
#
#	- Less chance of side effects;
#	- Better error-handling;
#	- Object Oriented (classic, without any postmodern 
#      Perl OOP modules, such as: Moose, Moo etc.
#      Ensures compatibility);
#	- Simpler script structure;
#   - Full SSL support;
#
# The cons include:
#
#   - The scripts have been written to have least side effects possible;
#      however, there can be issues with using it on DSs and VPSs
#      that might have corrupted cPanel Perl libraries;
#   - The script focuses on not using ecnrypted connections, 
#      it might seem as a advantage; although, not quite as non-ssl support
#      would give it more versatility;
#
#///////////////////////////////////////////////////////////////////////////////#
# 
# How to use it?
# 
# Using it is quite easy and straightforward. To quickly install it in the cPanel
# account, run the following command either from the command line or a cron job:
# 

curl -sO https://raw.githubusercontent.com/PlasticVader/cPanelAutoBackup/master/cpbackup_install.sh && bash cpbackup_install.sh


# This will install the script into ~/cPanelAutoBackup
# and the module into one of the module directories in the @INC array.
# 
# The next step is to just copy your cPanel account password after the 'local:' 
# line in ~/cPanelAutoBackup/.cpbackup-auto.conf
#
#///////////////////////////////////////////////////////////////////////////////#
#
# Passed arguments:
#
# The script supports passing arguments from the command line to:
#
# - Upload the backup to a remote location;
# - Specify another email address to sent the report to or disable sending email;
# 
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
#  7) Output file (default is ~/cpbackup-report.txt):
#
#     - file=
#
#
#///////////////////////////////////////////////////////////////////////////////#
#
# In order to have the script upload remotely,
# there is a need to make sure that the following
# arguments have been supplied to the script:
#
# ->  server <- 
# ->  user   <-
# ->  port   <-
# ->  dir    <-
#
# As well as 'remote:' line contains the password for
# the remote user.
#
#///////////////////////////////////////////////////////////////////////////////#
#////////////////////////////////////////////////////////////////////////////////////////#
# 
# The automated backup "script" consists of two files:
# a module: AutoBackup.pm and a script: cpbackup.pl
# 
#////////////////////////////////////////////////////////////////////////////////////////#
# 
# How to install?
# 
# To quickly install it in the cPanel account, run the following command either
# from the command line or a using a cron job:
# +------------------------------------------------------------+
# |       curl -sOL https://git.io/vd0vs && bash vd0vs         |
# +------------------------------------------------------------+
#
# This will:
#
#    1) Install the script into ~/cPanelAutoBackup directory;
#    2) Install the module into one of the module directories in the @INC array;
#    3) Create the ~/cPanelAutoBackup/backups directory as a default storage of
#       backup archives;
#    4) Create am empty configuration file ~/cPanelAutoBackup/.cpbackup.conf;
#    5) Delete itself on finish;
#
#////////////////////////////////////////////////////////////////////////////////////////#
#
# How to use?
#
# The script does not require you making changes to the code, unless you really
# want to (there is always an option to run the installation cron/command again)
#
# The main configuration is in ~/cPanelAutoBackup/.cpbackup.conf
# The following configuration details are read by the script after "=":
#
# 1) local=           <= Your cPanel account password
# 2) remote=          <= Remote user password
# 3) email=           <= Email address to send the report to
# 4) host=            <= The remote host to copy the backup to
# 5) port=            <= Remote host port to connect to
# 6) user=            <= Remote user to login to
# 7) dir=             <= Remote directory path of the remote user
# 8) silent|quiet     <= This will disable sending a report via an email
#                      +---------------------------------------------------+
#                      | the script will check your cPanel contact email   |
#                      | in case of it not being specified                 |
#                      | silent|quiet will disable this so no mail is sent |
#                      +---------------------------------------------------+
#
#////////////////////////////////////////////////////////////////////////////////////////#
#
# Small notes:
#
# - The script checks you cPanel backup exclusion file and adds the necessary
#   lines in order for the backup to ommit already created full backup archives
#   as well as the default backup storate directory ~/cPanelAutoBackup/backups
#
# - There is an option to pass configuration details as arguments to the script
#   *except* passwords "local=" and "remote=".
#   If the argument passed is already present in the configuration file it will
#   be overwritten.
#
# - If you wish not to always store the backups in the home folder, make sure to
#   enter the cPanel password "local=your_password" and "host=localhost"
#   this will store the backups in the default directory ~/cPanelAutoBackup/backups
#   +---------------------------------Important----------------------------------+
#   ! Please keep in mind that cPanel will first create the archive in home dir  !
#   ! and after that move it to the default storage directory, this can cause    !
#   ! *above par I/O usage* in the account, pretty much as any backup script     !
#   +----------------------------------------------------------------------------+
#
# - When specifying the configuration details for the remote backup upload, please note
#   that if the remote username was set as "user@domain.tld" the script will adjust 
#   itself for an FTP upload otherwise it adjusts itself for a secure copy upload (scp).
#   +-----------------------------------------------------------------------------------+
#   | If one of the remote upload config detail was missed then the script will put the |
#   | backup into the homedirectory                                                     |
#   +-----------------------------------------------------------------------------------+
#
#////////////////////////////////////////////////////////////////////////////////////////#
#
# Future versions are planned to have the following features:
#
# - Another Perl module that would catch the PIDs of initialized services in order to
#   move the backup without using secure copy to localhost;
#
# - Choose your storage directory without code editing
#   (this will be added sooner that you think);
#
# - Non-SSL support;
#
#////////////////////////////////////////////////////////////////////////////////////////#

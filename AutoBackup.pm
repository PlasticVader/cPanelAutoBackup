package AutoBackup;

use strict;
use warnings;

use Carp;
use LWP::UserAgent;

our $VERSION = '1.0.8';

#######################################
#       [ Object constructor ]        #
#        Returns this object          #
#######################################

sub new {
    my ($class, %arguments) = @_;
    my $self = \%arguments;
    bless $self, $class;
    return $self;
}

###########################################################################
#                          [ Passwords Checker ]                          #
#        Checks the configuration file for passwords and sets them        #
#                            Returns boolean                              #
###########################################################################

sub check_passwords {
    my $self = shift;
    my ($ret_val, $passwd);

    if (defined $self->{passwd}) {
        $passwd = $self->{passwd};
    }

    if (-f $passwd) {
        open my $fh, '<', $passwd or croak;
        while (<$fh>) {
            if ( m/^(?:local:\s*)([[:graph:]]+)$/ ) {
                $self->{password} = "$1";
            }
            elsif ( m/^(?:remote:\s*)([[:graph:]]+)$/ ) {
                $self->{remote_password} = "$1";
            }
        }
        close $fh or croak;
        $ret_val = '1';
    }
    else {
        $ret_val = '0';
    }
    return $ret_val;
}

#################################################################################
#                  [ Remote Backup Upload Details Checker ]                     #
#      Checks the passed argument list (an array) for remote backup details     #
#                               Returns a boolean                               #
#################################################################################

sub check_remote_arguments {
    my ($self, @cli_options) = @_;
    my (@remote_arguments, $size, $pass_size, $ret_val);

    if (defined $self->{remote_password}) {
        @remote_arguments =
          grep { m/(?:server|host|user|r?dir|port)/ } @cli_options;
        $size = @remote_arguments;
        $pass_size = '4';
        $ret_val = ($size == $pass_size) ? '1' : '0';
    }
    else {
        $ret_val = '0';
    }
    return $ret_val;
}

###################################################################
#                     [ User Agent Setter ]                       #
#           Creates LWP object to be used in this module          #
#                          Returns true                           #
###################################################################

sub set_user_agent {
    my $self = shift;
    my ($cookiejar, %user_agent_options);

    $cookiejar = $self->{homepath} . '/.fullbackup_cookie.txt';
    %user_agent_options = (
        'timeout'              => '45',
        'cookie_jar'           => {
            'file'
               => $cookiejar,
            'autosave'
               => '1',
        },
        'protocols_allowed'     => [ 'http', 'https' ],
        'max_redirect'          => '5',
        'default_header'        => {
            'Connection'
               => 'keep_alive',
        },
        'requests_redirectable' => [ 'GET', 'HEAD', 'POST', ],
    );

    $self->{useragent} = LWP::UserAgent->new(%user_agent_options);
    return '1';
}

#########################################
#       [ User Agent getter ]           #
#         Returns LWP object            #
#########################################

sub get_user_agent {
    my $self = shift;
    if (defined $self->{useragent}) {
        return $self->{useragent};
    }
}

##########################################################################
#                   [ Exclude Config File Checker ]                      #
# Checks whether:                                                        #
# - the exclusion file exists;                                           #
# - the exclusion pattern exists;                                        #
# Appends/creates the file with exclusion pattern if necessary           #
# Returns boolean                                                        #
##########################################################################

sub check_exclude_conf_file {
    my $self = shift;
    my ($filename, $ret_val, @matched_lines, $size);

    if (defined $self->{excludeFile}) {
        $filename = $self->{excludeFile};
    }

    if (-f $filename) {
        open my $fh, '<', $filename or croak;
        @matched_lines = grep { m/^(?:backup-[*] [.] tar [.] gz)$/x } <$fh>;
        close $fh or croak;
        $size = @matched_lines;
        if ($size == 1) {
            $self->write_exclude_conf_file($filename);
            $ret_val = '1';
        }
        else {
            $ret_val = '0';
        }
    }
    else {
        $self->write_exclude_conf_file($filename);
        $ret_val = '0'
    }
    return $ret_val;
}

#############################################
#      [ Exclude Config File Writer ]       #
# Appends/creates exclusion file and adds   #
# the exclusion glob into it                #
# Returns true                              #
#############################################

sub write_exclude_conf_file {
    my ($self, $filename) = @_;
    my $exclusion_pattern = 'backup-*.tar.gz';
    open my $fh, '+>>', $filename or croak;
    printf {$fh} "%s\n", $exclusion_pattern;
    close $fh or croak;
    return '1';
}

###########################################################
#                   [ cPanel Login ]                      #
# Logs into the cPanel account and sets cpsession URL     #
# Returns boolean                                         #
###########################################################

sub cpanel_login {
    my $self = shift;
    my ( $url, $user_agent, $response, $ret_val, %data );

    if ($self->set_user_agent) {
        $user_agent = $self->get_user_agent;
    }

    %data = (
        'user' => $self->{username},
        'pass' => $self->{password},
    );

    $url      = $self->{baseURL} . '/login';
    $response = $user_agent->post($url, \%data);

    if ($response->is_success) {
        $response->base =~ m/^(.+?)(?:\/[^\/]+)$/;
        $self->{session_url} = "$1";
        $ret_val = '1';
    }
    else {
        $self->{session_url}
            = 'Failed to log into the cPanel account: '
            . $response->status_line;
        $ret_val = '0';
    }
    return $ret_val;

}
###########################################
#          [ Cpsession getter ]           #
#          Returns logged-in URL          #
###########################################

sub get_session_url {
    my $self = shift;
    if (defined $self->{session_url}) {
        return $self->{session_url};
    }
}

###########################################################################
#                     [ cPanel Contact Email setter ]                     #
# Checks passed command line arguments for email & silence values         #
# Sets contact email if not set in the CLI arguments                      #
# Returns boolean                                                         #
###########################################################################

sub check_contact_email {
    my ($self, @cli_options) = @_;
    my ($ret_val, @email, @silence);

    if (@cli_options) {
        @email   = grep { m/(?i:email=)/ } @cli_options;
        @silence = grep { m/(?i:silen(?:ce|t)|quiet)/ } @cli_options;
    }

    if (@silence) {
        $ret_val = '0';
    }
    elsif (@email) {
        $email[0] =~ m/^(?:email=)(.+)$/;
        $self->{contactEmail} = "$1";
        $ret_val = '1';
    }
    else {
        my ($url, $user_agent, $response);
        $url        = $self->get_session_url . '/contact/index.html';
        $user_agent = $self->get_user_agent;
        $response   = $user_agent->get($url);
        if ($response->is_success) {
            $response->decoded_content =~ m/([\w.-]+?@[[:alnum:].-]+)/;
            $self->{contactEmail} = "$1";
            $ret_val = '1';
        }
        else {
            $self->{contactEmail}
                = 'Failed to get Contact Email from cPanel Contact Info: '
                . $response->status_line;
            $ret_val = '0';
        }
    }
    return $ret_val;
}

############################################
#    [ cPanel Contact Email Getter ]       #
#  Returns the contact email as a string   #
############################################

sub get_contact_email {
    my $self = shift;
    if (defined $self->{contactEmail}) {
        return $self->{contactEmail};
    }
}

########################################################################################
#                               [ Backup Generator ]                                   #
########################################################################################
sub generate_backup {
    my ($self, @cli_options) = @_;
    my (%default_options, $ret_val, $url, $user_agent, $response);

    %default_options  = (
        'dest'        => 'homedir',
        'email_radio' => '0',
        'email'       => undef,
        'server'      => undef,
        'user'        => undef,
        'pass'        => undef,
        'port'        => undef,
        'rdir'        => undef,
        'silent'      => undef,
    );

    $url        = $self->get_session_url . '/backup/dofullbackup.html';
    $user_agent = $self->get_user_agent;

    if ( $self->check_contact_email(@cli_options) ) {
        $default_options{email_radio} = '1';
        $default_options{email}       = $self->get_contact_email;
        $self->{backup_status}
            = "The backup report will be sent out to [ $default_options{email} ]\n";
    }
    else {
        $default_options{email_radio} = '0';
        $self->{backup_status}
            = "The backup report will not be sent out.\n";
    }

    if ( $self->check_remote_arguments(@cli_options) ) {
        $default_options{pass} = $self->{remote_password};
        $default_options{dest} = 'scp';

        foreach (@cli_options) {
            $default_options{server}
                = ( m/^(?i:(?:server|host)(?:name)?=)([[:alnum:].-]+)$/ ) ? "$1" : undef;
            $default_options{user}
                = ( m/^(?i:user(?:name)?=)([\w@.-]+)$/ ) ? "$1" : undef;
            $default_options{port}
                = ( m/^(?i:port=)(\d+)$/ ) ? "$1" : undef;
            $default_options{rdir}
                = ( m/^(?i:(?:(?:r|target)?dir)=)([\w\s\/.-]+)$/ ) ? "$1" : undef;
        }

        $self->{backup_status}
            .= "  The backup archive will be moved to [ $default_options{server} ]\n"
            . "  Via the port [ $default_options{port} ]\n"
            . "  Into the remote directory [ $default_options{rdir} ]\n"
            . "  Of the remote user [ $default_options{user} ]\n";
    }
    else {
        $self->{backup_status}
            .= "  The backup archive will be stored in [ $self->{homepath} ]\n";
    }

    $response = $user_agent->post($url, \%default_options);
    if ($response->is_success) {
        $ret_val = '1';
    }
    else {
        $self->{backup_status}
            .= "\n[ $response->status_line ]\n";
        $ret_val = '0';
    }
    return $ret_val;
}

##############################################
#         [ Backup Status Getter ]           #
##############################################

sub get_backup_status {

    my $self = shift;
    if (defined $self->{backup_status}) {
        return $self->{backup_status};
    }
}

############################################################################
#                         [ Pre-defined replies ]                          #
############################################################################

sub predefined {
    my ($self, $type) = @_;
    my ($reply_1, $reply_2, $reply_3);
    my ($exclude_conf, $exclude_success, $exclude_no_need);
    my ($session_url, $login_success, $login_failure);
    my ($backup_status, $backup_success, $backup_failure);
    my ($passwd, $password_okay, $password_failure);
    my (%reply_types);

    if (defined $self->{excludeFile}) {
        $exclude_conf = $self->{excludeFile};
    }

    $session_url   = $self->get_session_url;
    $backup_status = $self->get_backup_status;
    $passwd        = $self->{passwd};

    $reply_1
        = "\n+------------------------------------------------------+"
        . "\n| Autobackup initiated, checking the exclusion file... |"
        . "\n+------------------------------------------------------+\n\n";
    $reply_2
        = "\n+------------------------------------+"
        . "\n| Logging into the cPanel account... |"
        . "\n+------------------------------------+\n\n";
    $reply_3
        = "\n+----------------------------------------------------------------------+"
        . "\n| Checking the passed arguments and starting full backup generation... |"
        . "\n+----------------------------------------------------------------------+\n\n";
    $exclude_success
        = "  The exclude pattern has been added to the configuration file:\n\n $exclude_conf\n";
    $exclude_no_need
        = "  The exclude pattern is already present in the configuration file:\n\n $exclude_conf\n";
    $login_success
        = "  Login successful, cpsession URL has been acquired:\n\n $session_url\n";
    $login_failure
        = "  Login failed:\n\n  $session_url\n";
    $backup_success
        = "  Full cPanel backup has been successfully initialized:\n\n  $backup_status\n";
    $backup_failure
        = "  Full cPanel backup initialization failed:\n\n  $backup_status\n";
    $password_failure
        = "\n\n  The passwords file $passwd is not present:\n\n  Aborting...\n";
    $password_okay
        = "\n\n  The passwords file $passwd is present:\n\n  Proceeding...\n";

    %reply_types = (
        'reply_1'          => $reply_1,
        'reply_2'          => $reply_2,
        'reply_3'          => $reply_3,
        'exclude_success'  => $exclude_success,
        'exclude_no_need'  => $exclude_no_need,
        'login_success'    => $login_success,
        'login_failure'    => $login_failure,
        'generate_success' => $backup_success,
        'generate_failure' => $backup_failure,
        'password_okay'    => $password_okay,
        'password_failure' => $password_failure,
    );
    return $reply_types{$type};
}

############################################################
#                 [ Inner Initializer ]                    #
#             Returns output of the program                #
############################################################

sub init {
    my ($self , @options) = @_;
    my $out;

    if ($self->check_passwords) {
        $out .= $self->predefined('password_okay');
    }
    else {
       croak $self->predefined('password_failure'); 
    }

    $out .= $self->predefined('reply_1');

    if ($self->check_exclude_conf_file) {
        $out .= $self->predefined('exclude_success');
    }
    else {
	    $out .= $self->predefined('exclude_no_need');
    }

    $out .= $self->predefined('reply_2');

    if ($self->cpanel_login) {
        $out .= $self->predefined('login_success');
    }
    else {
        croak $self->predefined('login_failure');
    }

    $out .= $self->predefined('reply_3');

    if ( $self->generate_backup(@options) ) {
    	$out .= $self->predefined('generate_success');
    }
    else {
    	croak $self->predefined('generate_failure');
    }

return $out;
}

########################################################################
#                        [ Outer initializer ]                         #
# Additionally checks for an output file to write                      #
# or writes to a default report file                                   #
# Returns true                                                         #
########################################################################

sub run_backup {
    my ($self, @options) = @_;
    my %output;

    foreach (@options) {
        if ( m/^(?:file=)(.+)$/ ) {
            $output{file} = "$1";
        }
        else {
            $output{file} = $self->{homepath} . '/cPanelAutoBackup' . '/cpbackup-report.txt';
        }
    }

    $output{out} = $self->init(@options);
    open STDOUT, '>', $output{file} or croak;
    printf $output{out};
    close STDOUT or croak;
    return '1';
}

#####################################################################################################################
# END #
#######
1; #
####

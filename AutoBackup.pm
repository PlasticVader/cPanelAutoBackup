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

#######################################
#       [ Concatenate arrays ]        #
#        Returns merged array         #
#######################################

sub concat_array {
    my ($self, $ref1, $ref2) = @_;
    my ($size1, $size2);
    my (@merged, @lead, @diff);

    $size1 = @{$ref1};
    $size2 = @{$ref2};

    if ($size1 >= $size2) {
        @merged = @{$ref1};
        @lead   = @{$ref2};
    }
    else {
        @merged = @{$ref2};
        @lead   = @{$ref1};
    }

    foreach my $el (@lead) {
        my $cmp
            = ($el =~ m/^(\w+=)(?:.+)$/xms)
            ? "$1"
            : undef
            ;

        @diff = grep { m/\Q$cmp\E/xms } @merged;
        if (@diff) {
            @merged = grep { ! m/\Q$cmp\E/xms } @merged;
            push @merged, $el;
        }
        else {
            push @merged, $el;
        }
    }
    return @merged;
}

##################################################################
#              [ Script configuration checker ]                  #
# Returns a hash reference with applied options from both        #
# the passed command cline arguments and configuration file      #
##################################################################

sub check_config {
    my ($self, @cli_arguments) = @_;
    my ($ret_val, @config, $config_file, @lines);

    if (defined $self->{configFile}) {
        $config_file = $self->{configFile};
    }
    else {
        croak 'The configuration file was not defined';
    }

    if (-f $config_file) {
        open my $fh, '<', $config_file or croak;
        @lines   = <$fh>;
        close $fh or croak;
        @config  = $self->concat_array(\@lines, \@cli_arguments);
        $ret_val = $self->apply_config(@config);
    }
    else {
        croak 'The configuration file does not exist';
    }
    return $ret_val;
}

##############################################################################
#                      [ Script Configuration Setter ]                       #
# Applies the configuration from the merged array and returns the hash       #
# reference with configuration options                                       #
##############################################################################

sub apply_config {
    my ($self, @config) = @_;
    my ($size, $pass_size, $ret_val);
    my (@remote_arguments, @email, @pass, @file);
    my %options;

    @email
        = grep { m/(?i:email|silen(?:t|ce)|quiet)/xms } @config;

    if (@email) {
        foreach (@email) {
            if ( m/^(?i:silen(?:t|ce)|quiet)$/xms ) {
                $options{email_radio} = '0';
            }
            if ( m/^(?i:email=)([\w.-]+@[[:alnum:].-]+)$/xms ) {
                $options{email} = "$1";
                $options{email_radio} = '1';
            }
        }
    }
    elsif ($self->check_contact_email) {
        $options{email} = $self->get_contact_email;
        $options{email_radio} = '1';
    }
    else {
        $options{email_radio} = '0';
    }

    @remote_arguments
        = grep { m/(?i:server|host|user|r?dir|port)/xms } @config;
    $size = @remote_arguments;
    $pass_size = '4';
    if ($size == $pass_size) {
        foreach (@remote_arguments) {
            if ( m/^(?i:(?:server|host)(?:name)?=)([[:alnum:].-]+)$/xms ) {
                $options{server} = "$1";
                next;
            }
            if ( m/^(?i:user(?:name)?=)([\w@.-]+)$/xms ) {
                $options{user} = "$1";
                next;
            }
            if ( m/^(?i:port=)(\d+)$/xms ) {
                $options{port} = "$1";
                next;
            }
            if ( m/^(?i:(?:(?:r|target)?dir)=)([\w\/.-]+)$/xms ) {
                $options{rdir} = "$1";
            }
        }

        if ( $options{user} =~ m/^(?i:[\w.-]+@[[:alnum:].-]+)$/xms ) {
            $options{dest} = 'ftp';
            $options{port} = '21';
        }
        else {
            $options{dest} = 'scp';
        }
    }
    else {
        $options{dest} = 'homedir';
    }

    @pass
        = grep { m/(?i:local|remote)/xms } @config;

    if (@pass) {
        foreach (@pass) {
            if ( m/^(?i:local=)([[:graph:]]+)$/xms ) {
                $options{local} = "$1";
                next;
            }
            if ( m/^(?i:remote=)([[:graph:]]+)$/xms ) {
                $options{pass} = "$1";
            }
        }
    }
    else {
        croak 'No passwords in the configuration';
    }

    @file
        = grep { m/(?:file|report)/xms } @config;

    if (@file) {
        $options{file}
            = ( $file[0] =~ m/^(?i:(?:file|report)=)(.+)$/xms )
            ? "$1"
            : undef
            ;
    }
    else {
        $options{file}
            = $self->{homepath}
            . '/cPanelAutoBackup'
            . '/cpbackup-report.txt';
    }
    $ret_val = \%options;
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

    $cookiejar
        = $self->{homepath}
        . '/cPanelAutoBackup'
        . '/.fullbackup_cookie.txt';
    %user_agent_options = (
        'timeout'              => '45',
        'cookie_jar'           => {
            'file'
               => $cookiejar,
            'autosave'
               => '0',
        },
        'protocols_allowed'     => [ 'http', 'https' ],
        'max_redirect'          => '5',
        'default_header'        => {
            'Connection'
               => 'keep_alive',
        },
        'requests_redirectable' => [ 'GET', 'POST', ],
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
    my ($filename, $ret_val, @matched_lines);

    if (defined $self->{excludeFile}) {
        $filename = $self->{excludeFile};
    }

    if (-f $filename) {
        open my $fh, '<', $filename or croak;
        @matched_lines
            = grep { m/^(?:backup-[*][.]tar[.]gz)$/xms } <$fh>;
        close $fh or croak;

        if (@matched_lines) {
            $ret_val = '0';
        }
        else {
            $self->write_exclude_conf_file($filename);
            $ret_val = '1';
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
    my ($self, $passwd) = @_;
    my ($url, $user_agent, $response, $ret_val);
    my %login_data;

    if ($self->set_user_agent) {
        $user_agent = $self->get_user_agent;
    }

    %login_data = (
        'user' => $self->{username},
        'pass' => $passwd,
    );

    $url      = $self->{baseURL} . '/login';
    $response = $user_agent->post($url, \%login_data);

    if ($response->is_success) {
        $response->base =~ m{ ^(.+?)(?:/[^/]+)$ }xms;
        $self->{session_url} = "$1";
        $ret_val = '1';
    }
    else {
        $self->{session_url}
            = 'Failed to log into the cPanel account: '
            . $response->status_line
            . ' please double-check the provided password in '
            . $self->{passwd};
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
    my $self = shift;
    my ($url, $user_agent, $response, $ret_val);

    $url        = $self->get_session_url . '/contact/index.html';
    $user_agent = $self->get_user_agent;
    $response   = $user_agent->get($url);
    if ($response->is_success) {
        $response->decoded_content =~ m/([\w.-]+?@[[:alnum:].-]+)/xms;
        $self->{contactEmail} = "$1";
        $ret_val = '1';
    }
    else {
        $self->{contactEmail}
            = 'Failed to get Contact Email from cPanel Contact Info: '
            . $response->status_line;
        $ret_val = '0';
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
    my ($self, $options) = @_;
    my (%default_options, $ret_val, $url, $user_agent, $response);

    %default_options = %{$options};

    $url        = $self->get_session_url . '/backup/dofullbackup.html';
    $user_agent = $self->get_user_agent;

    if ($default_options{email}) {
        $self->{backup_status}
            = "The backup report will be sent out to [ $default_options{email} ]\n";
    }
    else {
        $self->{backup_status}
            = "The backup report will not be sent out.\n";
    }

    if (
        $default_options{pass}
        && $default_options{server}
        && $default_options{port}
        && $default_options{user}
        && $default_options{rdir}
       ) {
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
    my ($password_okay, $password_failure);
    my (%reply_types);

    $exclude_conf  = $self->{excludeFile};
    $session_url   = $self->get_session_url;
    $backup_status = $self->get_backup_status;

    $reply_1
        = "\n+----------------------------------------------------------+"
        . "\n| Autobackup initiated, checking the configuration file... |"
        . "\n+----------------------------------------------------------+\n\n";
    $reply_2
        = "\n+------------------------------------+"
        . "\n| Logging into the cPanel account... |"
        . "\n+------------------------------------+\n\n";
    $reply_3
        = "\n+------------------------------------+"
        . "\n| Starting full backup generation... |"
        . "\n+------------------------------------+\n\n";
    $exclude_success
        = "  The exclude pattern has been added to the configuration file:\n\n $exclude_conf\n";
    $exclude_no_need
        = "  The exclude pattern is already present in the configuration file:\n\n $exclude_conf\n";
    $login_success
        = "  Login successful, cpsession URL has been acquired\n";
    $login_failure
        = "  Login failed:\n\n  $session_url\n";
    $backup_success
        = "  Full cPanel backup has been successfully initialized:\n\n  $backup_status\n";
    $backup_failure
        = "  Full cPanel backup initialization failed:\n\n  $backup_status\n";
    $password_failure
        = "  No local cPanel account password in the script configuration file\n";
    $password_okay
        = "  cPanel account password is present in the configuration file\n";

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
#                     [ Initializer ]                      #
#             Returns true, runs the program               #
############################################################

sub run_backup {
    my ($self, @cli_arguments) = @_;
    my ($out, $options, $local_password, $output_file);

    $out .= $self->predefined('reply_1');

    $options = $self->check_config(@cli_arguments);
    $local_password = ${$options}{local};

    if ($local_password) {
        $out .= $self->predefined('password_okay');
        ${$options}{local} = undef;
    }
    else {
       croak $self->predefined('password_failure');
    }

    if ($self->check_exclude_conf_file) {
        $out .= $self->predefined('exclude_success');
    }
    else {
	    $out .= $self->predefined('exclude_no_need');
    }

    $out .= $self->predefined('reply_2');

    if ( $self->cpanel_login($local_password) ) {
        $out .= $self->predefined('login_success');
    }
    else {
        croak $self->predefined('login_failure');
    }

    $output_file = ${$options}{file};
    ${$options}{file} = undef;

    $out .= $self->predefined('reply_3');

    if ( $self->generate_backup($options) ) {
    	$out .= $self->predefined('generate_success');
    }
    else {
    	croak $self->predefined('generate_failure');
    }

    open STDOUT, '>', $output_file or croak;
    printf $out;
    close STDOUT or croak;
    return '1';
}

#####################################################################################################################
# END #
#######
1; #
####

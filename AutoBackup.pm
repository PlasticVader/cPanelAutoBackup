package AutoBackup;

use strict;
use warnings;

use Carp;
use LWP::UserAgent;

our $VERSION = '1.1.0';

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
# replaces the command line arguments #
# if they are already present in the  #
# configuration file as if there will #
# be support for both, there should   #
# be priorities programmed by default #
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

    foreach my $element (@lead) {
        my $comparison
            = ($element =~ m/^(\w{3,9})(?:=)?(?:.*)$/)
            ? "$1"
            : undef
            ;

        if ($comparison) {
            @diff = grep { m/\Q$comparison\E/ } @merged;
            if (@diff) {
                # If there is already a matched element - replace it.
                @merged = grep { ! m/\Q$comparison\E/ } @merged;
                push @merged, $element;
            }
            else {
                # In all other cases, there will no such element;
                # and thus - add it.
                push @merged, $element;
            }
        }
        else {
            # If there was no comparison matched,
            # jump to the next iteration.
            next;
        }
    }
    return @merged;
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
        # Non-SSL option to be added soon
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

###########################################################
#                   [ cPanel Login ]                      #
# Logs into the cPanel account and sets cpsession URL     #
# Returns boolean                                         #
###########################################################

sub cpanel_login {
    my ($self, $passwd) = @_;
    my ($url, $user_agent, $response, $user);
    my $ret_val;
    my %login_data;

    if (defined $self->{username}) {
        $user = $self->{username};
    }
    else {
        croak 'The cPanel username was not defined!';
    }

    if ($self->set_user_agent) {
        $user_agent = $self->get_user_agent;
    }

    %login_data = (
        'user' => $user,
        'pass' => $passwd,
    );

    $url      = $self->{baseURL} . '/login';
    $response = $user_agent->post($url, \%login_data);

    if ($response->is_success) {
        $response->base =~ m/^(.+?)(?:\/[^\/]+)$/;
        $self->{session_url} = "$1";
        $ret_val = '1';
    }
    else {
        $self->{session_url}
            = 'Failed to log into the cPanel account, the server responded with: '
            . "[ $response->status_line ]"
            . ' please double-check the provided password in '
            . "[ $self->{configFile} ]";
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
        $response->decoded_content =~ m/([\w.-]+?@[[:alnum:].-]+)/;
        $self->{contactEmail} = "$1";
        $ret_val = '1';
    }
    else {
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

##############################################################################
#                     [ Applying configuration methods ]                     #
# Checks the remote upload, email, password and output file                  #
# in the config options array and returns a hash reference with the options  #
##############################################################################
sub is_locahost {
    my ($self, $config) = @_;
    my @localhost;
    my $ret_val;
    @localhost = grep { m/^(?i:(?:server|host)=localhost)$/ } @{$config};
    if (@localhost) {
        $ret_val = '1';
    }
    else {
        $ret_val = '0';
    }
    return $ret_val;
}

##############################################################################
sub set_localhost_options {
    my ($self, $pass) = @_;
    my ($home, $dir, $user);
    my %ret_val;

    $home    = $self->{homepath};
    $user    = $self->{username};
    $dir     = $home . '/cPanelAutoBackup/backups';
    %ret_val = (
        'rdir'   => $dir,
        'pass'   => $pass,
        'port'   => '21098',
        'server' => 'localhost',
        'user'   => $user,
        'dest'   => 'scp',
    );
    return \%ret_val;
}

##############################################################################
sub check_remote_options {
    my ($self, $config) = @_;

    if ( ${$config}{pass}  &&  ${$config}{server} &&
         ${$config}{port}  &&  ${$config}{user}   &&
         ${$config}{rdir} ) { return '1'; }
    else { return '0'; }
}

##############################################################################
sub get_remote_options {
    my ($self, $config) = @_;
    my ($size, $size_okay, $user_has_at);
    my @remote_options;
    my %ret_val;

    @remote_options
        = grep { m/(?<![#])(?i:server|host|user|r?dir|port|remote)/ } @{$config};

    $size = @remote_options;
    $size_okay = '5';

    if ($size == $size_okay) {
        foreach (@remote_options) {
            if ( m/^(?i:(?:server|host)(?:name)?=)([[:alnum:].-]+)$/ ) {
                $ret_val{server} = "$1";
                next;
            }
            if ( m/^(?i:user(?:name)?=)((?:[\w.-]+)([@]?)(?:[\w.-]+))$/ ) {
                $user_has_at = ($2) ? '1' : '0';
                $ret_val{user} = "$1";
                next;
            }
            if ( m/^(?i:port=)(\d+)$/ ) {
                $ret_val{port} = "$1";
                next;
            }
            if ( m/^(?i:dir=)(.+)$/ ) {
                $ret_val{rdir} = "$1";
                next;
            }
            if ( m/^(?i:remote=)(.+)$/ ) {
                $ret_val{pass} = "$1";
            }
        }
        $ret_val{dest} = ($user_has_at) ? 'ftp' : 'scp';
    }
    else {
        $ret_val{dest} = 'homedir';
    }
    return \%ret_val;
}

##############################################################################
sub get_email_options {
    my ($self, $config) = @_;
    my @email;
    my %ret_val;

    @email
        = grep { m/(?<![#])(?i:email|silent|quiet)/ } @{$config};

    if (@email) {
        foreach (@email) {
            if ( m/^(?i:silent|quiet)$/ ) {
                $ret_val{email_radio} = '0';
                $ret_val{email} = undef;
                last;
            }
            if ( m/^(?i:email=)([\w.-]+@[[:alnum:].-]+)$/ ) {
                $ret_val{email} = "$1";
                $ret_val{email_radio} = '1';
            }
        }
    }
    elsif ($self->check_contact_email) {
        $ret_val{email} = $self->get_contact_email;
        $ret_val{email_radio} = '1';
    }
    else {
        $ret_val{email_radio} = '0';
    }
    return \%ret_val;
}

##############################################################################
sub get_output_file {
    my ($self, $config) = @_;
    my @file;
    my $ret_val;

    @file
        = grep { m/(?<![#])(?:file|report)/ } @{$config};

    if (@file) {
        $file[0] =~ m/^(?i:(?:file|report)=)(.+)$/;
        $ret_val = "$1";
    }
    else {
        $ret_val
            = $self->{homepath}
            . '/cPanelAutoBackup'
            . '/cpbackup-report.txt';
    }
    return $ret_val;
}

##############################################################################
sub get_password {
    my ($self, $config) = @_;
    my @pass;
    my $ret_val;

    @pass
        = grep { m/(?<![#])(?i:local)/ } @{$config};

    if (@pass) {
        $pass[0] =~ m/^(?i:local=)([[:graph:]]+)$/;
        $ret_val = "$1";
    }
    else {
        croak "No cPanel password in the configuration file $self->{configFile}!";
    }
    return $ret_val;
}

##############################################################################
sub apply_config {
    my ($self, @config) = @_;
    my ($remote, $email, $pass, $file);
    my %ret_val;

    $pass = $self->get_password(\@config);

    if ( $self->cpanel_login($pass) ) {
         $email = $self->get_email_options(\@config);

         while(my ($key, $val) = each %{$email}) {
             $ret_val{$key} = $val;
         }
    }
    else {
        croak $self->verbose('login_failure');
    }

    if ( $self->is_locahost(\@config) ) {
        $remote = $self->set_localhost_options($pass);
    }
    else {
        $remote = $self->get_remote_options(\@config);
    }
    while(my ($key, $val) = each %{$remote}) {
        $ret_val{$key} = $val;
    }

    $file = $self->get_output_file(\@config);
    $self->{output_file} = $file;

    return \%ret_val;
}

##################################################################
#              [ Script configuration checker ]                  #
# Returns a hash reference with applied options from both        #
# the passed command line arguments and the configuration file   #
##################################################################

sub check_config {
    my ($self, @cli_arguments) = @_;
    my ($ret_val, $config_file);
    my (@config, @lines);

    if (defined $self->{configFile}) {
        $config_file = $self->{configFile};
    }
    else {
        croak 'The configuration file was not defined';
    }

    if (-f $config_file) {
        open my $fh, '<', $config_file
            or croak "Could not open $config_file for reading!";
        @lines   = <$fh>;
        close $fh
            or croak "Could not close $config_file after reading!";
        @config  = $self->concat_array(\@lines, \@cli_arguments);
        $ret_val = $self->apply_config(@config);
    }
    else {
        croak 'The configuration file does not exist';
    }
    return $ret_val;
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
    my ($exclude_conf, $ret_val);
    my ($pattern, %patterns);
    my (@matched_lines, $size, $size_miss, $size_okay);

    if (defined $self->{excludeFile}) {
        $exclude_conf = $self->{excludeFile};
    }

    %patterns = (
        'archive' => 'backup-*.tar.gz',
        'dir'     => 'cPanelAutoBackup/',
    );

    if (-f $exclude_conf) {
        open my $fh, '<', $exclude_conf
            or croak "Could not open $exclude_conf for reading!";
        @matched_lines
            = grep { m/(?:backup-|cPanel)/ } <$fh>;
        close $fh or croak "Could not close $exclude_conf after reading!";

        $size_okay = '2';
        $size_miss = '1';
        $size      = @matched_lines;

        if ($size == $size_okay) {
            $ret_val = '0';
        }
        elsif ($size == $size_miss) {
            $pattern = ($matched_lines[0] =~ m/(?:backup-)/)
                     ? "$patterns{dir}\n"
                     : "$patterns{archive}\n"
                     ;
        }
        else {
            $pattern = "$patterns{archive}\n$patterns{dir}\n";
        }
        $self->write_exclude_conf_file($exclude_conf, $pattern);
        $ret_val = '1';
    }
    else {
        $pattern = "$patterns{archive}\n$patterns{dir}\n";
        $self->write_exclude_conf_file($exclude_conf, $pattern);
        $ret_val = '1'
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
    my ($self, $filename, $pattern) = @_;
    open my $fh, '>>', $filename
        or croak "Could not open $filename for writing!";
    printf {$fh} $pattern;
    close $fh
        or croak "Could not close $filename after writing!";
    return '1';
}

########################################################################################
#                               [ Backup Generator ]                                   #
# Deferences the configuration options hash and sends out the request for backup       #
# generation.                                                                          #
# Returns boolean.                                                                     #
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

    if ( $self->check_remote_options(\%default_options) ) {
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
            = "Could not send the POST request!\n"
            . "The server responded with: [ $response->status_line ]";
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

sub verbose {
    my ($self, $type) = @_;
    my ($reply_1, $reply_2);
    my ($exclude_conf, $exclude_success, $exclude_no_need);
    my ($session_url, $login_failure);
    my ($backup_status, $backup_success, $backup_failure);
    my %reply_types;

    $exclude_conf  = $self->{excludeFile};
    $session_url   = $self->get_session_url;
    $backup_status = $self->get_backup_status;

    $reply_1
        = "\n+----------------------------------------------------------+"
        . "\n| Autobackup initiated, checking the configuration file... |"
        . "\n+----------------------------------------------------------+\n\n";
    $reply_2
        = "\n+------------------------------------+"
        . "\n| Starting full backup generation... |"
        . "\n+------------------------------------+\n\n";
    $exclude_success
        = "  The exclude pattern has been added to the configuration file:\n\n $exclude_conf\n";
    $exclude_no_need
        = "  The exclude pattern is already present in the configuration file:\n\n $exclude_conf\n";
    $login_failure
        = "  Login failed:\n\n  $session_url\n";
    $backup_success
        = "  Full cPanel backup has been successfully initialized:\n\n  $backup_status\n";
    $backup_failure
        = "  Full cPanel backup initialization failed:\n\n  $backup_status\n";

    %reply_types = (
        'reply_1'          => $reply_1,
        'reply_2'          => $reply_2,
        'exclude_success'  => $exclude_success,
        'exclude_no_need'  => $exclude_no_need,
        'login_failure'    => $login_failure,
        'generate_success' => $backup_success,
        'generate_failure' => $backup_failure,
    );
    return $reply_types{$type};
}

############################################################
#                     [ Initializer ]                      #
#             Returns true, runs the program               #
############################################################

sub run_backup {
    my ($self, @cli_arguments) = @_;
    my ($out, $options);

        $out .= $self->verbose('reply_1');
    $options = $self->check_config(@cli_arguments);
    if ($self->check_exclude_conf_file) {
        $out .= $self->verbose('exclude_success');
    }
    else {
	    $out .= $self->verbose('exclude_no_need');
    }
        $out .= $self->verbose('reply_2');
    if ( $self->generate_backup($options) ) {
    	$out .= $self->verbose('generate_success');
    }
    else {
    	croak $self->verbose('generate_failure');
    }
    open STDOUT, '>', $self->{output_file} or croak;
    printf $out;
    close STDOUT or croak;
    return '1';
}

#####################################################################################################################
# END #
#######
1; #
####

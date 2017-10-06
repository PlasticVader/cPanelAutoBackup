#!/usr/bin/env perl

use strict;
use warnings;

use AutoBackup;

our $VERSION = '1.1.0';

sub get_hostname {
    my $hosts_file = '/etc/hosts';
    my ($hostname, $pattern);

    $pattern
        = '((?:server|business|host|premium)'
        . '(?:\d+[.])'
        . '(?:web-hosting|registrar-servers)'
        . '(?:[.]com))'
        ;

    if (defined $ENV{HOSTNAME}) {
        $hostname = $ENV{HOSTNAME};
    }
    else {
        open my $fh, '<', $hosts_file
            or die "Could not open $hosts_file for reading!";
        while (<$fh>) {
            m/$pattern/;
            $hostname = "$1";
        }
        close $fh
            or die "Could not close $hosts_file after reading!";
    }
    return $hostname;
}

my ($homepath, $installdir, $hostname, $autoback);

$homepath = $ENV{HOME};
$hostname = get_hostname();
$installdir = '/cPanelAutoBackup';
$autoback = AutoBackup->new(
    'homepath'       => $homepath,
    'username'       => $ENV{USER},
    'configFile'     => $homepath . $installdir . '/.cpbackup.conf',
    'baseURL'        => 'https://' . $hostname . ':2083',
    'excludeFile'    => $homepath . '/cpbackup-exclude.conf',
);
$autoback->run_backup(@ARGV);

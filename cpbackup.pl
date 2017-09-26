#!/usr/bin/env perl

use strict;
use warnings;

use AutoBackup;

sub get_hostname {
    my $hosts_file = '/etc/hosts';
    my $hostname;
    if (defined $ENV{HOSTNAME}) {
        $hostname = $ENV{HOSTNAME};
    }
    else {
        open my $fh, '<', $hosts_file or die;
        while (<$fh>) {
                m{
                    (
                        (?:server|business|host|premium)
                        (?:\d+)
                        [.]
                        (?:web-hosting|registrar-servers)
                        [.]
                        (?:com)
                    )
                }x;
                $hostname = "$1";
        }
        close $fh or die;
    }
    return $hostname;
}

my ($homepath, $installdir, $hostname, $autoback);

$homepath = $ENV{HOME};
$hostname = get_hostname();
$installdir = '/cPanel-AutoBackup';
$autoback = AutoBackup->new(
    'homepath'       => $homepath,
    'username'       => $ENV{USER},
    'passwd'         => $homepath . $installdir . '/.cpbackup-auto.conf',
    'baseURL'        => 'https://' . $hostname . ':2083',
    'excludeFile'    => $homepath . '/cpbackup-exclude.conf',
);

$autoback->run_backup(@ARGV);

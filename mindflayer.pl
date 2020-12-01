#!/usr/bin/env perl

use strict;
use warnings;

use Parallel::Forker;
my $Fork = new Parallel::Forker (use_sig_child=>1, max_proc=>15);
$SIG{CHLD} = sub { Parallel::Forker::sig_child($Fork); };
$SIG{TERM} = sub { $Fork->kill_tree_all('TERM') if $Fork && $Fork->in_parent; die "Quitting...\n"; };

use Net::CIDR::Lite;
use MaxMind::DB::Reader;
use Time::Moment;

my $servers = {};
my $timeline = {};

$|=1;

print "Loading IPs\n";
open(FILE, "<hosts-resolved.txt") || die $!;
while(<FILE>) {
    if (/^(.*?)\t(.*?)$/) {
        $servers->{$1} = {
            server => $1,
            ip => $2,
        }
    }
}
close(FILE);

print "Loading history\n";
open(FILE, "<historical-stats.tsv") || die $!;
<FILE>;
while(<FILE>) {
    chomp;
    my ($server, $local_timestamp, $dau) = split(/\t/);
    my $tm = Time::Moment->from_epoch($local_timestamp);
    my $day = $tm->strftime("%F");
    $servers->{$server}->{dau}->{$day} = $dau;
    $timeline->{$day}->{$server} = 1;
}
close(FILE);

print "Fixing up matrix.org entry\n";
my $matrixdotorg = 0;
foreach my $day (sort keys %$timeline) {
    if ($servers->{'matrix.org'}->{dau}->{$day}) {
        $matrixdotorg = $servers->{'matrix.org'}->{dau}->{$day};
    }
    else {
        $servers->{'matrix.org'}->{dau}->{$day} = $matrixdotorg;
        $timeline->{$day}->{'matrix.org'} = 1;
    }
}

my $reader = MaxMind::DB::Reader->new( file => 'GeoLite2-City_20201124/GeoLite2-City.mmdb' );

print "Geolocating\n";
foreach my $server (keys %$servers) {
    next unless $servers->{$server}->{ip};
    my $record = $reader->record_for_address($servers->{$server}->{ip});
    $servers->{$server}->{long} = $record->{location}->{longitude};
    $servers->{$server}->{lat}  = $record->{location}->{latitude};
    # print join("\t", map { $servers->{$server}->{$_} } qw (server ip weight long lat));
    # print "\n";
}

foreach my $day (sort keys %$timeline) {
    print "Processing $day\n";
    open(FILE, ">conns/conns-$day.tsv") || die $!;
    print FILE join("\t", qw(weight server_a ip_a weight_a long_a lat_a server_b ip_b weight_b long_b lat_b)), "\n";

    my @serverlist = keys %{$timeline->{$day}};
    @serverlist = sort { $servers->{$b}->{dau}->{$day} <=> $servers->{$a}->{dau}->{$day} } @serverlist;
    if (scalar @serverlist > 100) {
        @serverlist = @serverlist[0..99];
    }

    # use Data::Dumper;
    # print Dumper(@serverlist);

    my $lines = 0;
    foreach my $a (@serverlist) {
        foreach my $b (@serverlist) {
            next if ($a eq $b);
            my $sa = $servers->{$a};
            my $sb = $servers->{$b};
            next unless ($sa->{ip});
            next unless ($sb->{ip});
            next unless (defined $sa->{long} && defined $sa->{lat} && defined $sb->{long} && defined $sb->{lat});
            next unless ($sa->{long} != $sb->{long} && $sa->{lat} != $sb->{lat});
            $sa->{weight} = $sa->{dau}->{$day};
            $sb->{weight} = $sb->{dau}->{$day};
            my $weight = sqrt($sa->{weight} ** 2 + $sb->{weight} ** 2);
            print FILE join("\t",
                       $weight,
                       (map { $sa->{$_} } (qw (server ip weight long lat))),
                       (map { $sb->{$_} } (qw (server ip weight long lat)))
                      );
            print FILE "\n";
            $lines++;
        }
    }
    close(FILE);
    if ($lines > 1) {
        $Fork->schedule(
            run_on_start => sub { system("Rscript matrix-timeline.R $day"); }
        )->ready;
    }
}

$Fork->wait_all;

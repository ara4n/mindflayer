#!/usr/bin/env perl

use strict;
use warnings;

use Net::CIDR::Lite;
use MaxMind::DB::Reader;

my $servers = {};

$|=1;

my $i = 0;
open(FILE, "<top-servers-ips-edited.txt") || die $!;
while(<FILE>) {
    if (/^(.*?)\t(.*?)$/) {
        $servers->{$1} = {
            server => $1,
            ip => $2,
        }
    }
    $i++;
    last if ($i > 70);
}
close(FILE);

open(FILE, "<weights.txt") || die $!;
while(<FILE>) {
    if (/^(.*?)\t(.*?)$/) {
        $servers->{$1}->{weight} = $2;
    }
}
close(FILE);

# use Data::Dumper;
# print Dumper($servers);

my $reader = MaxMind::DB::Reader->new( file => 'GeoLite2-City_20201124/GeoLite2-City.mmdb' );

foreach my $server (keys %$servers) {
    next unless $servers->{$server}->{ip};
    my $record = $reader->record_for_address($servers->{$server}->{ip});
    # print Dumper($record);
    $servers->{$server}->{long} = $record->{location}->{longitude};
    $servers->{$server}->{lat}  = $record->{location}->{latitude};
    # print join("\t", map { $servers->{$server}->{$_} } qw (server ip weight long lat));
    # print "\n";
}

print join("\t", qw(weight server_a ip_a weight_a long_a lat_a server_b ip_b weight_b long_b lat_b)), "\n";

foreach my $a (keys %$servers) {
    foreach my $b (keys %$servers) {
        next if ($a eq $b);
        my $sa = $servers->{$a};
        my $sb = $servers->{$b};
        next unless ($sa->{ip});
        next unless ($sb->{ip});
        next unless ($sa->{long} != $sb->{long} && $sa->{lat} != $sb->{lat});
        my $weight = sqrt($sa->{weight} ** 2 + $sb->{weight} ** 2);
        print join("\t",
                   $weight,
                   (map { $sa->{$_} } (qw (server ip weight long lat))),
                   (map { $sb->{$_} } (qw (server ip weight long lat)))
                  );
        print "\n";
    }
}
#!/usr/bin/env perl

# zdns/zdns A --name-servers=8.8.8.8,8.8.4.4 -threads 10 -verbosity 1 < hosts.txt > hosts-ips.txt

while(<>) {
    if (/\{"answer":"([^}]*?)",[^}]+"type":"A"\}.*\},"name":"(.*?)"/) {
        print "$2\t$1\n";
    }
    elsif (/"name":"([0-9\.]+)"/) {
        print "$1\t$1\n";
    }
}

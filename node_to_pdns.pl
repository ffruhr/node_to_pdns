#!/usr/bin/perl
use strict;
use PowerDNS::Backend::MySQL;
use JSON;
use Date::Calc qw/ Delta_Days Today /;
use Data::Printer;

$| = 1;

my $domain = 'node.freifunk.ruhr';
my $node_file = '/pfad/zur/nodes.json';
my $params = {  
	db_user                 =>      'dbuser',
        db_pass                 =>      'dbpasswd',
        db_name                 =>      'pdns',
        db_port                 =>      '3306',
        db_host                 =>      'localhost',
        mysql_print_error       =>      1,
        mysql_warn              =>      1,
        mysql_auto_commit       =>      1,
        mysql_auto_reconnect    =>      1,
        lock_name               =>      'powerdns_backend_mysql',
        lock_timeout            =>      3,
};

my $pdns = PowerDNS::Backend::MySQL->new($params);

&main();

sub main {
        my $nodes = &get_nodes();

        my($year, $month, $day) = Today();

        for my $node(keys %{$nodes->{'nodes'}}) {
                if($nodes->{'nodes'}->{$node}->{'flags'}->{'gateway'} eq 'true') { next; }
                if($nodes->{'nodes'}->{$node}->{'nodeinfo'}->{'hostname'} =~ /map/) { next; }

                my $hostname = $nodes->{'nodes'}->{$node}->{'nodeinfo'}->{'hostname'};

                if($nodes->{'nodes'}->{$node}->{'lastseen'} =~ /^(\d{4})-(\d{2})-(\d{2})/) {
                        my($dyear, $dmonth, $dday) = ($1, $2, $3);
                        my $dd = Delta_Days($year,$month,$day,$dyear,$dmonth,$dday);

                        if($dd > -3) {
                                my $record = $pdns->find_record_by_name(\$hostname,\$domain);
                                if(scalar(@{$record}) > 0) {
                                        
                                        my $v6;
                                        for my $ip(@{$nodes->{'nodes'}->{$node}->{'nodeinfo'}->{'network'}->{'addresses'}}) {
                                                if($ip =~ /^2a03/) {
                                                        $v6 = $ip;
                                                        last;
                                                }
                                        }

                                        if($record->[0] != $v6) {
                                                my @rr1 = ($hostname, 'AAAA', $record->[0]);
                                                my @rr2 = ($hostname, 'AAAA', $v6);
                                                $pdns->update_record(\@rr1, \@rr2, \$domain);
                                        }

                                } else {
                                        my $v6;
                                        for my $ip(@{$nodes->{'nodes'}->{$node}->{'nodeinfo'}->{'network'}->{'addresses'}}) {
                                                if($ip =~ /^2a03/) {
                                                        $v6 = $ip;
                                                        last;
                                                }
                                        }
                                        my @rr = ($hostname, 'AAAA', $v6, '86400');
                                        my $result = $pdns->add_record(\@rr, \$domain);
                                }

                        } else {
                                my $record = $pdns->find_record_by_name(\$hostname,\$domain);
                                my @rr = ($hostname, 'AAAA', $record->[0]);
                                $pdns->delete_record(\@rr, \$domain);
                        }
                }
        }
}

sub get_nodes {
        open(my $fh, '<', $node_file);
        my $content = join('',<$fh>);
        close($fh);
        return from_json($content);
}
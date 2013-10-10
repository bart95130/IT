#!/usr/bin/env perl

#####################################
#####################################
### ______               _     =) ###
### | ___ \             | |       ###
### | |_/ / __ _  _ __  | |       ###
### |    / / _` || '_ \ | |       ###
### | |\ \| (_| || | | || |____   ###
### \_| \_|\__,_||_| |_|\_____/   ###
#####################################
#####################################

# V 1.1
# IMPROVED by Marc LECROSNIER - at -free.fr :
# - Deal with temperature unit : Fahrenheit or Celsius
# - Work with RoomAlert 3E
# - Get value of a switch if no external sensor is detected
# - Better perfdata output get sensor label


# Info
# Checks AVTECH Room alert devices tempeture via SNMP

use strict;
use Net::SNMP;
use Getopt::Long; Getopt::Long::Configure('bundling');

my $stat = 0;
my $msg = "";
my $perf;
my $script_name = "check-roomalert.pl";

### SNMP OIDs
###############

my $s_roomalert4e_internal_label        = '.1.3.6.1.4.1.20916.1.6.1.1.1.3.0';
my $s_roomalert4e_internal_fahrenheit   = '.1.3.6.1.4.1.20916.1.6.1.1.1.2.0';
my $s_roomalert4e_internal_celsius      = '.1.3.6.1.4.1.20916.1.6.1.1.1.1.0';

my $s_roomalert4e_external_label        = '.1.3.6.1.4.1.20916.1.6.1.2.1.3.0';
my $s_roomalert4e_external_fahrenheit   = '.1.3.6.1.4.1.20916.1.6.1.2.1.2.0';
my $s_roomalert4e_external_celsius      = '.1.3.6.1.4.1.20916.1.6.1.2.1.1.0';


my $s_roomalert3e_internal_label        = '.1.3.6.1.4.1.20916.1.9.1.1.1.3.0';
my $s_roomalert3e_internal_fahrenheit   = '.1.3.6.1.4.1.20916.1.9.1.1.1.2.0';
my $s_roomalert3e_internal_celsius      = '.1.3.6.1.4.1.20916.1.9.1.1.1.1.0';

my $s_roomalert3e_external_label        = '.1.3.6.1.4.1.20916.1.9.1.2.1.3.0';
my $s_roomalert3e_external_fahrenheit   = '.1.3.6.1.4.1.20916.1.9.1.2.1.2.0';
my $s_roomalert3e_external_celsius      = '.1.3.6.1.4.1.20916.1.9.1.2.1.1.0';

my $s_roomalert3e_switch_value          = '.1.3.6.1.4.1.20916.1.9.1.2.1.0';
my $s_roomalert3e_switch_label          = '.1.3.6.1.4.1.20916.1.9.1.2.2.0';



### Functions
###############
sub _create_session {
        my ($server, $comm) = @_;
        my $version = 1;
        my ($sess, $err) = Net::SNMP->session( -hostname => $server, -version => $version, -community => $comm);
        if (!defined($sess)) {
                print "Can't create SNMP session to $server\n";
                exit(1);
        }
        return $sess;
}

sub _get_oid_value(@) {
        my $sess = shift;
        my $local_oid = shift;
        my $r_return = $sess->get_request(-varbindlist => [$local_oid]);
        return($r_return->{$local_oid});
}

sub FSyntaxError($) {
        my $err = shift;
        print <<EOU;
     $err

        -H = Ip/Dns Name of the FW
        -C = SNMP Community
        -w = Warning Value -> internal,external
        -c = Critical Value -> internal,external
        -u = Unit : F for Farenheit anything else for Celsius
EOU
        exit(1);
}

my %opt;
my $result = GetOptions(\%opt,
        'host|H=s',
        'com|C=s',
        'warn|w=s',
        'crit|c=s',
        'unit|u=s',
);

FSyntaxError("Missing -H")  unless defined $opt{'host'};
FSyntaxError("Missing -C")  unless defined $opt{'com'};
FSyntaxError("Missing -w")  unless defined $opt{'warn'};
FSyntaxError("Missing -c")  unless defined $opt{'crit'};

$msg="$opt{'host'}";


# Validate Warning
my @warn = split(",",$opt{'warn'});
my @crit = split(",",$opt{'crit'});
if($warn[0] > $crit[0]) {
        FSyntaxError("Warning can't be larger then Critical: $warn[0] > $crit[0]");
}
if($warn[1] > $crit[1]) {
        FSyntaxError("Warning can't be larger then Critical: $warn[1] > $crit[1]");
}

my $unit;
if(!defined $opt{'unit'}) {
        $unit='F';
}else{
        $unit=$opt{'unit'};
}

my $s_internal;
my $s_external;


# Establish SNMP Session
our $snmp_session = _create_session($opt{'host'},$opt{'com'});
# Try Room Alert 4E OID
if  ($unit eq "F"){
        $s_internal = $s_roomalert4e_internal_fahrenheit;
        $s_external = $s_roomalert4e_external_fahrenheit;
} else {
        $s_internal = $s_roomalert4e_internal_celsius;
        $s_external = $s_roomalert4e_external_celsius;
}

my $internal_label      = _get_oid_value($snmp_session,$s_roomalert4e_internal_label);
my $external_label      = _get_oid_value($snmp_session,$s_roomalert4e_external_label);
my $internal            = _get_oid_value($snmp_session,$s_internal);
my $external            = _get_oid_value($snmp_session,$s_external);
$internal = int(substr($internal,0,2) . "." . substr($internal,2,2));
$external = int(substr($external,0,2) . "." . substr($external,2,2));

# IF no value try Room Alert 3E OID
if ($internal==0) {
        $internal_label = _get_oid_value($snmp_session,$s_roomalert3e_internal_label);
        $external_label = _get_oid_value($snmp_session,$s_roomalert3e_external_label);
        if  ($unit eq 'F'){
                $s_internal = $s_roomalert3e_internal_fahrenheit;
                $s_external = $s_roomalert3e_external_fahrenheit;
        } else {
                $s_internal = $s_roomalert3e_internal_celsius;
                $s_external = $s_roomalert3e_external_celsius;
        }
}

my $internal = _get_oid_value($snmp_session,$s_internal);
my $external = _get_oid_value($snmp_session,$s_external);
$internal = int(substr($internal,0,2) . "." . substr($internal,2,2));
$external = int(substr($external,0,2) . "." . substr($external,2,2));

# Try if a switch sensor is connected
if ($external==0) {
        $s_external     = $s_roomalert3e_switch_value;
        $external_label = _get_oid_value($snmp_session,$s_roomalert3e_switch_label);
        $external       = _get_oid_value($snmp_session,$s_external);
        if ($external==0) {$external=1}
        if ($external==1) {$external=0}
}







my $istat = 0;
my $estat = 0;

# Check Internal
if($internal >= $crit[0]) {
        $istat=2;
} elsif($internal >= $warn[0] and $internal < $crit[0]) {
        $istat=1;
} else {
        $istat=0;
}

# Check External
if($external >= $crit[1]) {
        $estat=2;
} elsif($external >= $warn[1] and $external < $crit[1]) {
        $estat=1;
} else {
        $estat=0;
}

if($istat == 2 or $estat == 2) {
        $stat = 2;
        $msg = "CRITICAL: $msg";
} elsif($istat == 1 or $estat == 1) {
        $stat = 1;
        $msg = "WARNING: $msg";
} else {
        $stat = 0;
        $msg = "OK: $msg";
}

# Perf Data
$perf="'$internal_label'=$internal '$external_label'=$external";

print "$msg | $perf\n";
exit($stat);

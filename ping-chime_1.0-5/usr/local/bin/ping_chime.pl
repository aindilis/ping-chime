#!/usr/bin/perl
use strict;
use warnings;
use Net::Ping;
use Time::HiRes qw(sleep time);
use Sys::Syslog qw(:standard :macros);
use Config::Simple;
use POSIX qw(setsid);
use File::Spec;
use File::HomeDir;

# Configuration file locations
my @config_locations = (
    File::Spec->catfile(File::HomeDir->my_home, '.config', 'ping-chime', 'ping-chime.cfg'),
    '/etc/ping-chime/ping-chime.cfg'
);

# Load configuration
my $cfg;
for my $config_file (@config_locations) {
    if (-f $config_file) {
        $cfg = new Config::Simple($config_file);
        last if $cfg;
    }
}

die "Can't load configuration from any of the specified locations" unless $cfg;

# Read configuration variables
my $host = $cfg->param('network.host');

my $timing_base_interval = 0.15;
if (defined $cfg->param('timing.base_interval')) {
  $timing_base_interval = $cfg->param('timing.base_interval');
}
my $base_interval = $timing_base_interval * 60;  # Convert minutes to seconds
my $pulse_sink = $cfg->param('audio.pulse_sink');
my $max_volume = $cfg->param('audio.max_volume');
my $min_volume = $cfg->param('audio.min_volume');
my $volume_decay_rate = $cfg->param('audio.volume_decay_rate');

# New configuration variables
my $ping_interval = $cfg->param('timing.ping_interval') || $base_interval / 6;
my $connected_chime_interval = $cfg->param('timing.connected_chime_interval') || $base_interval;
my $disconnected_chime_interval = $cfg->param('timing.disconnected_chime_interval') || $base_interval * 2;
my $use_volume_adjustment = $cfg->param('audio.use_volume_adjustment') // 1;  # Default to true if not specified

# Sound files
my %sound_files = (
    'connected'    => $cfg->param('sounds.connected'),
    'disconnected' => $cfg->param('sounds.disconnected'),
    'connecting'   => $cfg->param('sounds.connecting'),
    'disconnecting'=> $cfg->param('sounds.disconnecting')
);

# Initialize state variables
my $current_state = 'unknown';
my $current_volume = $max_volume;
my $last_connected_chime_time = 0;
my $last_disconnected_chime_time = 0;
my $last_ping_time = 0;
my $connected_count = 0;
my $disconnected_count = 0;

sub play_sound {
    my ($file, $volume) = @_;
    my $command = "paplay --volume=" . int($volume * 65536) . " --device=$pulse_sink $file";
    system($command);
}

sub log_and_chime {
    my ($message, $sound_key) = @_;
    syslog(LOG_INFO, $message);
    my $volume = $use_volume_adjustment ? $current_volume : $max_volume;
    play_sound($sound_files{$sound_key}, $volume);
}

openlog('ping-chime', 'cons,pid', 'user');
syslog(LOG_INFO, "Script started. Pinging $host every $base_interval seconds");

# # Daemonize
# chdir '/' or die "Can't chdir to /: $!";
# umask 0;
# open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
# open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
# open STDERR, '>/dev/null' or die "Can't write to /dev/null: $!";
# defined(my $pid = fork) or die "Can't fork: $!";
# exit if $pid;
# setsid or die "Can't start a new session: $!";

# Main loop
while (1) {
    my $current_time = time();

    # Check if it's time to ping
    if ($current_time - $last_ping_time >= $ping_interval) {
        my $ping = Net::Ping->new('tcp', 2);
        my $new_state = $ping->ping($host) ? 'connected' : 'disconnected';
        $ping->close();
        $last_ping_time = $current_time;

        # Check if the state has changed
        if ($new_state ne $current_state) {
            my $transition_state = $new_state eq 'connected' ? 'connecting' : 'disconnecting';
            log_and_chime("Transition: $transition_state", $transition_state);
            $current_volume = $max_volume;
            $connected_count = 0;
            $disconnected_count = 0;
            $last_connected_chime_time = $current_time if $new_state eq 'connected';
            $last_disconnected_chime_time = $current_time if $new_state eq 'disconnected';
        }

        $current_state = $new_state;
    }

    # Check if it's time to chime for the current state
    my $last_chime_time = $current_state eq 'connected' ? $last_connected_chime_time : $last_disconnected_chime_time;
    my $chime_interval = $current_state eq 'connected' ? $connected_chime_interval : $disconnected_chime_interval;

    if ($current_time - $last_chime_time >= $chime_interval) {
        log_and_chime("State: $current_state", $current_state);

        if ($current_state eq 'connected') {
            $last_connected_chime_time = $current_time;
            $connected_count++;
            $disconnected_count = 0;
        } else {
            $last_disconnected_chime_time = $current_time;
            $disconnected_count++;
            $connected_count = 0;
        }

        # Adjust volume if the feature is enabled
        if ($use_volume_adjustment) {
            if ($current_state eq 'connected') {
                $current_volume = $max_volume;
            } else {
                $current_volume = $max_volume * (1 - $volume_decay_rate) ** $disconnected_count;
                $current_volume = $min_volume if $current_volume < $min_volume;
            }
        }
    }

    sleep(1);  # Sleep for 1 second before next check
}

closelog();

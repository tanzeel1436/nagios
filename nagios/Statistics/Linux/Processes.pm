=head1 NAME

Sys::Statistics::Linux::Processes - Collect linux process statistics.

=head1 SYNOPSIS

    use Sys::Statistics::Linux::Processes;

    my $lxs = Sys::Statistics::Linux::Processes->new;
    # or Sys::Statistics::Linux::Processes->new(pids => \@pids)

    $lxs->init;
    sleep 1;
    my $stat = $lxs->get;

=head1 DESCRIPTION

Sys::Statistics::Linux::Processes gathers process information from the virtual
F</proc> filesystem (procfs).

For more information read the documentation of the front-end module
L<Sys::Statistics::Linux>.

=head1 PROCESS STATISTICS

Generated by F</proc/E<lt>pidE<gt>/stat>, F</proc/E<lt>pidE<gt>/status>,
F</proc/E<lt>pidE<gt>/cmdline> and F<getpwuid()>.

Note that if F</etc/passwd> isn't readable, the key owner is set to F<N/a>.

    ppid      -  The parent process ID of the process.
    nlwp      -  The number of light weight processes that runs by this process.
    owner     -  The owner name of the process.
    pgrp      -  The group ID of the process.
    state     -  The status of the process.
    session   -  The session ID of the process.
    ttynr     -  The tty the process use.
    minflt    -  The number of minor faults the process made.
    cminflt   -  The number of minor faults the child process made.
    mayflt    -  The number of mayor faults the process made.
    cmayflt   -  The number of mayor faults the child process made.
    stime     -  The number of jiffies the process have beed scheduled in kernel mode.
    utime     -  The number of jiffies the process have beed scheduled in user mode.
    ttime     -  The number of jiffies the process have beed scheduled (user + kernel).
    cstime    -  The number of jiffies the process waited for childrens have been scheduled in kernel mode.
    cutime    -  The number of jiffies the process waited for childrens have been scheduled in user mode.
    prior     -  The priority of the process (+15).
    nice      -  The nice level of the process.
    sttime    -  The time in jiffies the process started after system boot.
    actime    -  The time in D:H:M:S (days, hours, minutes, seconds) the process is active.
    vsize     -  The size of virtual memory of the process.
    nswap     -  The size of swap space of the process.
    cnswap    -  The size of swap space of the childrens of the process.
    cpu       -  The CPU number the process was last executed on.
    wchan     -  The "channel" in which the process is waiting.
    fd        -  This is a subhash containing each file which the process has open, named by its file descriptor.
                 0 is standard input, 1 standard output, 2 standard error, etc. Because only the owner or root
                 can read /proc/<pid>/fd this hash could be empty.
    cmd       -  Command of the process.
    cmdline   -  Command line of the process.

Generated by F</proc/E<lt>pidE<gt>/statm>. All statistics provides information
about memory in pages:

    size      -  The total program size of the process.
    resident  -  Number of resident set size, this includes the text, data and stack space.
    share     -  Total size of shared pages of the process.
    trs       -  Total text size of the process.
    drs       -  Total data/stack size of the process.
    lrs       -  Total library size of the process.
    dtp       -  Total size of dirty pages of the process (unused since kernel 2.6).

It's possible to convert pages to bytes or kilobytes. Example - if the pagesize of your
system is 4kb:

    $Sys::Statistics::Linux::Processes::PAGES_TO_BYTES =    0; # pages (default)
    $Sys::Statistics::Linux::Processes::PAGES_TO_BYTES =    4; # convert to kilobytes
    $Sys::Statistics::Linux::Processes::PAGES_TO_BYTES = 4096; # convert to bytes

    # or with
    Sys::Statistics::Linux::Processes->new(pages_to_bytes => 4096);

=head1 METHODS

=head2 new()

Call C<new()> to create a new object.

    my $lxs = Sys::Statistics::Linux::Processes->new;

It's possible to handoff an array reference with a PID list.

    my $lxs = Sys::Statistics::Linux::Processes->new(pids => [ 1, 2, 3 ]);

It's also possible to set the path to the proc filesystem.

     Sys::Statistics::Linux::Processes->new(
        files => {
            # This is the default
            path    => '/proc',
            uptime  => 'uptime',
            stat    => 'stat',
            statm   => 'statm',
            status  => 'status',
            cmdline => 'cmdline',
            wchan   => 'wchan',
            fd      => 'fd',
        }
    );

=head2 init()

Call C<init()> to initialize the statistics.

    $lxs->init;

=head2 get()

Call C<get()> to get the statistics. C<get()> returns the statistics as a hash reference.

    my $stat = $lxs->get;

Note:

Processes that were created between the call of init() and get() are returned as well,
but the keys minflt, cminflt, mayflt, cmayflt, utime, stime, cutime, and cstime are set
to the value 0.00 because there are no inititial values to calculate the deltas.

=head2 raw()

Get raw values.

=head1 EXPORTS

No exports.

=head1 SEE ALSO

B<proc(5)>

B<perldoc -f getpwuid>

=head1 REPORTING BUGS

Please report all bugs to <jschulz.cpan(at)bloonix.de>.

=head1 AUTHOR

Jonny Schulz <jschulz.cpan(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (c) 2006, 2007 by Jonny Schulz. All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package Sys::Statistics::Linux::Processes;

use strict;
use warnings;
use Carp qw(croak);
use Time::HiRes;
use constant NUMBER => qr/^-{0,1}\d+(?:\.\d+){0,1}\z/;

our $VERSION = '0.32';
our $PAGES_TO_BYTES = 0;

sub new {
    my $class = shift;
    my $opts  = ref($_[0]) ? shift : {@_};

    my %self = (
        files => {
            path    => '/proc',
            uptime  => 'uptime',
            stat    => 'stat',
            statm   => 'statm',
            status  => 'status',
            cmdline => 'cmdline',
            wchan   => 'wchan',
            fd      => 'fd',
        },
    );

    if (defined $opts->{pids}) {
        if (ref($opts->{pids}) ne 'ARRAY') {
            croak "$class: not a array reference";
        }

        foreach my $pid (@{$opts->{pids}}) {
            if ($pid !~ /^\d+\z/) {
                croak "$class: pid '$pid' is not a number";
            }
        }

        $self{pids} = $opts->{pids};
    }

    foreach my $file (keys %{ $opts->{files} }) {
        $self{files}{$file} = $opts->{files}->{$file};
    }

    if ($opts->{pages_to_bytes}) {
        $self{pages_to_bytes} = $opts->{pages_to_bytes};
    }

    return bless \%self, $class;
}

sub init {
    my $self = shift;
    $self->{init} = $self->_init;
}

sub get {
    my $self  = shift;
    my $class = ref $self;

    if (!exists $self->{init}) {
        croak "$class: there are no initial statistics defined";
    }

    $self->{stats} = $self->_load;
    $self->_deltas;
    return $self->{stats};
}

sub raw {
    my $self = shift;
    my $stat = $self->_load;

    return $stat;
}

#
# private stuff
#

sub _init {
    my $self  = shift;
    my $class = ref $self;
    my $file  = $self->{files};
    my ($pids, %stats);

    $stats{time} = Time::HiRes::gettimeofday();

    if ($self->{pids}) {
        $pids = $self->{pids};
    } else {
        opendir my $pdir, $file->{path}
            or croak "$class: unable to open directory $file->{path} ($!)";
        $pids = [(grep /^\d+\z/, readdir $pdir)];
        closedir $pdir;
    }

    foreach my $pid (@$pids) {
        if (open my $fh, '<', "$file->{path}/$pid/$file->{stat}") {
            @{$stats{$pid}}{qw(
                minflt cminflt mayflt cmayflt utime
                stime cutime cstime sttime
            )} = (split /\s+/, <$fh>)[9..16,21];
            close($fh);
        } else {
            delete $stats{$pid};
            next;
        }
    }

    return \%stats;
}

sub _load {
    my $self   = shift;
    my $class  = ref $self;
    my $file   = $self->{files};
    my $uptime = $self->_uptime();
    my ($pids, %stats, %userids);

    $stats{time} = Time::HiRes::gettimeofday();

    # All PIDs are fetched from the /proc filesystem. If a file cannot be opened
    # of a process, then it can be that the process doesn't exist any more and
    # the hash key will be deleted.

    if ($self->{pids}) {
        $pids = $self->{pids};
    } else {
        opendir my $pdir, $file->{path}
            or croak "$class: unable to open directory $file->{path} ($!)";
        $pids = [(grep /^\d+\z/, readdir $pdir)];
        closedir $pdir;
    }

    PID: foreach my $pid (@$pids) {

        # memory usage for each process
        if (open my $fh, '<', "$file->{path}/$pid/$file->{statm}") {
            #   size       total program size
            #   resident   resident set size
            #   share      shared pages
            #   text       text (code)
            #   lib        library
            #   data       data/stack
            #   dt         dirty pages (unused in Linux 2.6)
            if ($self->{pages_to_bytes}) {
                @{$stats{$pid}}{qw(size resident share trs lrs drs dtp)}
                    = map { $_ * $self->{pages_to_bytes} } split /\s+/, <$fh>;
            } elsif ($PAGES_TO_BYTES) {
                @{$stats{$pid}}{qw(size resident share trs lrs drs dtp)}
                    = map { $_ * $PAGES_TO_BYTES } split /\s+/, <$fh>;
            } else {
                @{$stats{$pid}}{qw(size resident share trs lrs drs dtp)} = split /\s+/, <$fh>;
            }

            close($fh);
        } else {
            next PID;
        }

        # different other information for each process
        if (open my $fh, '<', "$file->{path}/$pid/$file->{stat}") {
            @{$stats{$pid}}{qw(
                cmd     state   ppid    pgrp    session ttynr   minflt
                cminflt mayflt  cmayflt utime   stime   cutime  cstime
                prior   nice    nlwp    sttime  vsize   nswap   cnswap
                cpu
            )} = (split /\s+/, <$fh>)[1..6,9..19,21..22,35..36,38];
            close($fh);
        } else {
            delete $stats{$pid};
            next PID;
        }

        # calculate the active time of each process
        my ($d, $h, $m, $s) = $self->_calsec(sprintf('%li', $uptime - $stats{$pid}{sttime} / 100));
        $stats{$pid}{actime} = "$d:".sprintf('%02d:%02d:%02d', $h, $m, $s);

        # determine the owner of the process
        if (open my $fh, '<', "$file->{path}/$pid/$file->{status}") {
            while (my $line = <$fh>) {
                next unless $line =~ /^Uid:(?:\s+|\t+)(\d+)/;
                $stats{$pid}{owner} = getpwuid($1) || 'N/a';
                last;
            }
            close($fh);
        } else {
            delete $stats{$pid};
            next PID;
        }

        # command line for each process
        if (open my $fh, '<', "$file->{path}/$pid/$file->{cmdline}") {
            $stats{$pid}{cmdline} = <$fh>;
            if ($stats{$pid}{cmdline}) {
                $stats{$pid}{cmdline} =~ s/\0/ /g;
                $stats{$pid}{cmdline} =~ s/^\s+//;
                $stats{$pid}{cmdline} =~ s/\s+$//;
                chomp $stats{$pid}{cmdline};
            }
            $stats{$pid}{cmdline} = 'N/a' unless $stats{$pid}{cmdline};
            close($fh);
        } else {
            delete $stats{$pid};
            next PID;
        }

        if (open my $fh, '<', "$file->{path}/$pid/$file->{wchan}") {
            $stats{$pid}{wchan} = <$fh>;

            if (defined $stats{$pid}{wchan}) {
                chomp($stats{$pid}{wchan});
            } else {
                $stats{$pid}{wchan} = defined;
            }
        } else {
            delete $stats{$pid};
            next PID;
        }

        $stats{$pid}{fd} = { };

        if (opendir my $dh, "$file->{path}/$pid/$file->{fd}") {
            foreach my $link (grep !/^\.+\z/, readdir($dh)) {
                if (my $target = readlink("$file->{path}/$pid/$file->{fd}/$link")) {
                    $stats{$pid}{fd}{$link} = $target;
                }
            }
        }
    }

    return \%stats;
}

sub _deltas {
    my $self   = shift;
    my $class  = ref $self;
    my $istat  = $self->{init};
    my $lstat  = $self->{stats};
    my $uptime = $self->_uptime;

    if (!defined $istat->{time} || !defined $lstat->{time}) {
        croak "$class: not defined key found 'time'";
    }

    if ($istat->{time} !~ NUMBER || $lstat->{time} !~ NUMBER) {
        croak "$class: invalid value for key 'time'";
    }

    my $time = $lstat->{time} - $istat->{time};
    $istat->{time} = $lstat->{time};
    delete $lstat->{time};

    for my $pid (keys %{$lstat}) {
        my $ipid = $istat->{$pid};
        my $lpid = $lstat->{$pid};

        # yeah, what happends if the start time is different... it seems that a new
        # process with the same process-id were created... for this reason I have to
        # check if the start time is equal!
        if ($ipid && $ipid->{sttime} == $lpid->{sttime}) {
            for my $k (qw(minflt cminflt mayflt cmayflt utime stime cutime cstime)) {
                if (!defined $ipid->{$k}) {
                    croak "$class: not defined key found '$k'";
                }
                if ($ipid->{$k} !~ NUMBER || $lpid->{$k} !~ NUMBER) {
                    croak "$class: invalid value for key '$k'";
                }

                $lpid->{$k} -= $ipid->{$k};
                $ipid->{$k} += $lpid->{$k};

                if ($lpid->{$k} > 0 && $time > 0) {
                    $lpid->{$k} = sprintf('%.2f', $lpid->{$k} / $time);
                } else {
                    $lpid->{$k} = sprintf('%.2f', $lpid->{$k});
                }
            }
            $lpid->{ttime} = sprintf('%.2f', $lpid->{stime} + $lpid->{utime});
        } else {
            # calculate the statistics since process creation
            for my $k (qw(minflt cminflt mayflt cmayflt utime stime cutime cstime)) {
                my $p_uptime = $uptime - $lpid->{sttime} / 100;
                $istat->{$pid}->{$k} = $lpid->{$k};

                if ($p_uptime > 0) {
                    $lpid->{$k} = sprintf('%.2f', $lpid->{$k} / $p_uptime);
                } else {
                    $lpid->{$k} = sprintf('%.2f', $lpid->{$k});
                }
            }
            $lpid->{ttime} = sprintf('%.2f', $lpid->{stime} + $lpid->{utime});
            $istat->{$pid}->{sttime} = $lpid->{sttime};
        }
    }
}

sub _uptime {
    my $self  = shift;
    my $class = ref $self;
    my $file  = $self->{files};

    my $filename = $file->{path} ? "$file->{path}/$file->{uptime}" : $file->{uptime};
    open my $fh, '<', $filename or croak "$class: unable to open $filename ($!)";
    my ($up, $idle) = split /\s+/, <$fh>;
    close($fh);
    return $up;
}

sub _calsec {
    my $self = shift;
    my ($s, $m, $h, $d) = (shift, 0, 0, 0);
    $s >= 86400 and $d = sprintf('%i', $s / 86400) and $s = $s % 86400;
    $s >= 3600  and $h = sprintf('%i', $s / 3600)  and $s = $s % 3600;
    $s >= 60    and $m = sprintf('%i', $s / 60)    and $s = $s % 60;
    return ($d, $h, $m, $s);
}

1;

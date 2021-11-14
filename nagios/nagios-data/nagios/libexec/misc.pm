package misc;

use strict;

require Exporter;
use vars       qw( $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );

$VERSION     = 0.1;

@ISA         = qw(Exporter);
@EXPORT      = qw( log_timed_msg log_appended_msg incIndent decIndent saveIndent restoreIndent absolutePath relativePath );
%EXPORT_TAGS = ( );

@EXPORT_OK   = qw( );

# Variables

use vars qw( $INDENT @SAVE_INDENT );

#
# Functions
#

# Log a timestamped message to STDOUT if the user has specified a high enough verbose level.
sub log_timed_msg {
    my $type = shift;
    my $msg = shift;

    my $lvl = shift || 0; $lvl = 3 if ( $lvl > 3 );
    
    printf STDOUT "[%s] %s[%-5s] %s%s", scalar( localtime() ), ( $::opts->{verbose} > 2 ? '<' . $lvl . '/' .
        $::opts->{verbose} . '> ' : '' ), $type, '  'x$INDENT, $msg
            if ( $::opts->{verbose} >= $lvl );
}

# Log a message to STDOUT if the user has specified a high enough verbose level.
sub log_appended_msg {
    my $msg = shift;

    my $lvl = shift || 0; $lvl = 3 if ( $lvl > 3 );
    
    printf STDOUT "%s", $msg if ( $::opts->{verbose} >= $lvl );
}

sub incIndent {
    my $lvl = shift || 0;

    if ( $::opts->{verbose} >= $lvl ) {
        $INDENT++;
    }
}

sub decIndent {
    my $lvl = shift || 0;

    if ( $::opts->{verbose} >= $lvl ) {
        $INDENT--;
    }
}

sub saveIndent() {
    push( @SAVE_INDENT, $INDENT );
}

sub restoreIndent() {
    $INDENT = pop( @SAVE_INDENT );
}

sub absolutePath( $ ) {
    my $path = shift;

    $path = $ENV{PWD} . '/' . $path if ( $path !~ /^\// );
    my @parts = split( /\//, $path );
    my @final = ();

    foreach my $part ( @parts ) {
        if ( $part eq '..' ) {
            pop( @final );
        } elsif ( $part eq '.' || $part eq '' ) { # Skip these...
            next;
        } else {
            push( @final, $part );
        }
    }

    return '/' . join( '/', @final );
}

sub relativePath( $$ ) {
    my $base_path = shift;
    my $full_path = shift;

    $full_path =~ s/^${base_path}\/?//;

    return $full_path;
}

END { }

1;

__END__

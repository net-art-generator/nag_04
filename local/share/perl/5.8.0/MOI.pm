# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/lib/MOI.pm,v 1.5 2003/06/19 12:01:30 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <moi-perl@leo.0n3.org>.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

package MOI;

use 5.008;
use strict;
use warnings;

use Data::Dumper;

require Exporter;
our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 
	'all' => [ qw(DEBUG INFO NOTICE WARNING ERR CRIT ALERT EMERG
	              logger dumper) ]
);

our @EXPORT    = ( @{ $EXPORT_TAGS{'all'} } );


# $Version$
our $VERSION = '0.02';

use MOI::Logger;

# global MOI::Logger object
our $LOG = MOI::Logger->new();

sub logger {
	my $message = shift || '';
	my $channel = shift;
	
	my @caller = caller;
	my $call = sprintf("%s %s", @caller[1,2]);
	
	$LOG->logger("$message [$call]", $channel); 
}

sub dumper {
	my $msg  = Dumper(\@_);
	my @caller = caller;
	my $call = sprintf("%s %s", @caller[1,2]);
	$LOG->logger("$call\n$msg", DEBUG);
}

1;
__END__

=head1 NAME

MOI - Perl module namespace / framework

=head1 DESCRIPTION

The MOI - Perl module namespace holds initially the Perl-modules written
by me.

Later it could be a framework for object oriented Perl-programming in a 
MOI style. Basic it would be offer a few functions debugging and logging.

*** TO BE DONE LATER ***, if I know, what it really is ...

=head1 AUTHOR

Richard Leopold, E<lt>moi-perl@leo.0n3.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Richard Leopold

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

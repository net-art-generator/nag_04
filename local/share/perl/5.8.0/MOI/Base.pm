# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/lib/MOI/Base.pm,v 1.5 2003/06/27 14:37:13 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <moi-perl@leo.0n3.org>.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

package MOI::Base;

use 5.008;
use strict;
use warnings;

use Carp;
use Data::Dumper;

require Exporter;
our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 
	'moiLogger'   => [ qw(logger dumper 
	                      DEBUG INFO NOTICE WARNING ERR CRIT ALERT EMERG) ],
);

our @EXPORT    = ( 
);

our @EXPORT_OK = ( qw(
	DEBUG INFO NOTICE WARNING ERR CRIT ALERT EMERG
	logger dumper
));


our $VERSION = '0.01';

our $DEBUG = 0;

use MOI;

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my $parent = ref($proto) && $proto;
	
	my $self = { 
		debug      => $DEBUG,
		@_ 
	};
	
	bless $self, $class;
	
	return $self->_init__MOI_Base();
}

sub _init__MOI_Base {
	my $self = shift;
	
	$self->debug($self->{debug});
	
	return $self;
}

# set-/getter

sub debug {
#
# Sets/gets debug as BOOL
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) { 
		$self->{debug} = ($val ? 1 : 0);
		logger('SET debug TO: ' . $self->{debug} ) if $DEBUG;
	}
	return $self->{debug};
}

1;
#__END__

=head1 NAME

MOI::Base - The base class for MOI objects.

=head1 SYNOPSIS

 package MOI::Demo;

 use MOI::Base;
 our @ISA = qw(MOI::Base);

 sub new {
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my $parent = ref($proto) && $proto;
    
    my $self = {};
    
    $self = $class->SUPER::new( %{ $self } );
    bless ($self, $class);
    return $self;
 }
 
 1;

=head1 DESCRIPTION

The MOI::Base is the Base class for the MOI framework. Further MOI-classes should
be derived from this class.

by this initialy time the this class provides only a I<debug> switch.

*** TO BE DONE LATER ***, if I know, what it really is ... ***

=head1 EXPORTS

=item :moiLogger

Exports the logger symbols from of L<MOI> library:

 logger dumper DEBUG INFO NOTICE WARNING ERR CRIT ALERT EMERG

=head1 AUTHOR

Richard Leopold, E<lt>moi-perl@leo.0n3.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Richard Leopold

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

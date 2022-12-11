# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/Logger/lib/MOI/Logger/Std.pm,v 1.1 2003/06/30 09:53:22 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <moi-perl@leo.0n3.org>.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

# ################################################

package MOI::Logger::Std;

use 5.008;
use strict;
use warnings;

our @ISA = qw(
              MOI::Logger::Base
             );

our $VERSION = '0.01';

## NOW the code starts ...
use MOI::Logger::Base;

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my $parent = ref($proto) && $proto;
	
	my $self = {   
	               stderr => 0,
	               @_
	           };
	
	$self = $class->SUPER::new(%{ $self });
	bless $self, $class;
	
	return $self;
}

# Logger hooks
sub send_message {
	my $self      = shift;
	my $message   = shift || '';
	
	if ($self->{stderr}) { print STDERR $message }
	else { print STDOUT $message }
	
	return 1;
}

1;
__END__

=head1 NAME

MOI::Logger::Std - A backend class for L<MOI::Logger> to log STDOUT or STDERR.

=head1 SYNOPSIS

  use MOI::Logger::Std;
  
  my $moi = MOI::Logger::File_>new( 
                     stderr    => 1;
                     channel   => INFO|NOTICE|WARNING|ERR|CRIT|ALERT|EMERG);

  $moi->send_message('Hello World');


=head1 ABSTRACT

This class creates a logfile object which handles a logfile as a backend for the 
L<MOI::Logger> class.

=head1 DESCRIPTION

*** TO BE DONE **

=head2 EXPORT

nothing ...

=head1 SEE ALSO

L<MOI::Logger>
L<MOI::Logger::Base>

=head1 AUTHOR

Richard Leopold E<lt>moi-perl@leo.0n3.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002,2003 by Richard Leopold E<lt>moi-perl@leo.0n3.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

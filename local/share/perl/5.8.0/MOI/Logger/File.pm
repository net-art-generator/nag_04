# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/Logger/lib/MOI/Logger/File.pm,v 1.3 2003/06/30 09:53:22 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <moi-perl@leo.0n3.org>.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

# ################################################

package MOI::Logger::File;

use 5.008;
use strict;
use warnings;

our @ISA = qw(
              MOI::Logger::Base
             );

our $VERSION = '0.01';

## NOW the code starts ...

use Carp;
use File::Basename;
use IO::Handle;

use MOI::Logger::Base;

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my $parent = ref($proto) && $proto;
	
	my $self = {   
	               filename         => '/tmp/moi.log',
	               fileperm         => 0644,
	               maxsize          => 10000000,
	               binarymode       => ':utf8', 
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
	
	$self->_open_log();
	$self->{_fh}->print($message);
	
	return 1;
}

sub start {
	my $self = shift;
	
	$self->_open_log();
	
	return $self;
}

sub end {
	my $self = shift;
	
	$self->{_fh} = undef;
	
	return $self;
}

# privat
sub _open_log {
	my $self = shift;
	
	return 0 if ! $self->{filename};
	
	if (my @stat = stat($self->{filename})) {
		if ($stat[7] > $self->{maxsize}) {
			$self->{_fh}->close;
			rename $self->{filename}, $self->{filename}.'.0';
		}
	}
	
	return 1 if defined $self->{_fh};
	
	open $self->{_fh}, '>>', $self->{filename};
	
	if (! defined $self->{_fh}) {
		carp("warn: can't open logfile ". $self->{filename});
		return 0;
	}
	
	chmod $self->{fileperm}, $self->{filename};
	
	$self->{_fh}->autoflush(1);
	
	binmode($self->{_fh}, $self->{binarymode});
	
	return 1;
}

DESTROY {
	my $self = shift;
	$self->SUPER::DESTROY() if $self->can('SUPER::DESTROY');
	$self->{_fh}->close if $self->{_fh};
}

1;
__END__

=head1 NAME

MOI::Logger::File - A backend class for L<MOI::Logger> 
handling a simple logfile.

=head1 SYNOPSIS

  use MOI::Logger::File;
  
  my $moi = MOI::Logger::File_>new( 
                     name      => 'moi',
                     filename  => '/tmp/moi.log',
                     fileperm  => '0644',
                     maxsize   => 10000000,
                     channel   => INFO|NOTICE|WARNING|ERR|CRIT|ALERT|EMERG);
  $moi->start();
  
  $moi->check_channel(INFO);
  
  $moi->send_message('Hello World');
  
  $moi->end();


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

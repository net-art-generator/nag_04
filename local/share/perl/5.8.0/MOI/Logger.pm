# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/Logger/lib/MOI/Logger.pm,v 1.3 2003/06/30 09:53:22 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <moi-perl@leo.0n3.org>.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

package MOI::Logger;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 
	'all' => [ qw(DEBUG INFO NOTICE WARNING ERR CRIT ALERT EMERG CHANNELS) ],
	'logchannels' => [qw(DEBUG INFO NOTICE WARNING ERR CRIT ALERT EMERG)],
);

our @EXPORT = (
	@{ $EXPORT_TAGS{'logchannels'} },
);

our @EXPORT_OK = ( 
	@{ $EXPORT_TAGS{'all'} },
);

our $VERSION = '0.02';

## NOW the code starts

use MOI::Logger::Base qw(:logchannels);

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my $parent = ref($proto) && $proto;
	
	my $self = { 
	             _backends => {},
	             @_
	           };
	
	bless $self, $class;
	
	return $self;
}

# internal functions to initialise the logger
#
sub add {
	my $self = shift;
	
	unshift @_, 'Base' if ! @_;
	
	while (my $type = shift) {
		my $ref  = shift || {};
		
		do { 
			warn "expected a HASH reference with backend properties for $type"
			     . ", NOT $type !";
			next;
		} if ref $ref ne 'HASH';
		
		my $h = undef;
		
		eval "require MOI::Logger::$type;"
			. '$h = MOI::Logger::'.$type.'->new( %{ $ref } );';
		
		$h->start();
		
		do {
			warn "a backend with the name ". $h->name() ." already exists - skipping ...";
			next;
		} if exists $self->{_backends}->{$h->name()};
		
		$h->start();
		$self->{_backends}->{$h->name()}  = $h;
		
		$h->call_send_message('Logger backend up', INFO, 1);
	}
	
	return scalar keys %{ $self->{_backends} };
}

sub del {
	my $self = shift;
	
	my $name = '';
	while ($name = shift) {
		do {
			warn "No backend called $name !";
			delete $self->{_backends}->{$name};
			next;
		} if ! defined $self->{_backends}->{$name};
		
		$self->{_backends}->{$name}->call_send_message('Logger backend down', INFO, 1);
		$self->{_backends}->{$name}->end();
		delete $self->{_backends}->{$name};
	}
	return scalar keys %{ $self->{_backends} };
}

sub logger {
		my $self    = shift;
		my $message = shift || '-- empty message --';
		my $channel = shift || 1;
		
		foreach my $h ( values %{ $self->{_backends} } ) {
			$h->call_send_message($message, $channel);
		}
}

sub delete_all_backends {
	my $self = shift;
	
	$self->del(keys %{ $self->{_backends} });
}

1;
__END__


=head1 NAME

MOI::Logger - a moi logger class


=head1 ABSTRACT

B<MOI::Logger> is a logger class to log messages to several backends using
logger channels like syslog.


=head1 SYNOPSIS

 use MOI::Logger;
 
 my $moi = MOI::Logger->new();
 
 $log->add(File => { 
                     name      => 'moi',
                     filename  => '/tmp/moi.log',
                     fileperm  => '0644',
                     maxsize   => 10000000,
                     channel   => INFO|NOTICE|WARNING|ERR|CRIT|ALERT|EMERG
                   },
           File => {
                     name      => 'debug',
                     filename  => '/tmp/debug.log',
                     fileperm  => '0644',
                     maxsize   => 10000000,
                     channel   => DEBUG
                   } );
 
 $log->logger('hello world !', INFO);
 
 $log->dumper($log);
 
 $log->del(qw(moi dumper));


=head1 DESCRIPTION

This class should be used for logging purposes in MOI objects. It provides
a L<MOI::Logger/logger> function which does the logging work in each module
resp. object.

This Module is designed as a dispatcher, so multiple log-backends could be 
feeded.

=head1 CONSTRUCTOR

    my $moi = MOI::Logger->new();

Creates a new instance of this class.


=head1 METHODS

=over 10

=item add(Type1 => {...}, Type2 => {...})

Adding backends to the logger

Example:

 $moi->add(File => { 
                     name      => 'moi',
                     filename  => '/tmp/moitest.log',
                     fileperm  => '0644',
                     maxsize   => 10000000,
                     channel   => INFO|NOTICE|WARNING|ERR|CRIT|ALERT|EMERG
                   });

The argument is a hash. The keys are the backend types, and the values are the 
hash references to the backend options. See also: L<MOI::Logger::Base>

returns: the new number of backends


=item del(@names)

Deleting backends from the logger

Example:

 $moi->del(qw(moi debug));

returns: the new number of backends


=item logger($message, $channel)

sents the given C<$message> to C<$channel>

 $moi->logger();


=head1 CONSTANTS 

for Loglevels / -channels:

       EMERG
              system is unusable

       ALERT
              action must be taken immediately

       CRIT
              critical conditions

       ERR
              error conditions

       WARNING
              warning conditions

       NOTICE
              normal, but significant, condition

       INFO
              informational message

       DEBUG
              debug-level message


=head1 EXPORTS

A few constants for the logger channels:
 EMERG, ALERT, CRIT, ERR, WARNING, NOTICE, INFO, DEBUG


=head1 SEE ALSO

L<MOI>, L<MOI::Logger::Base>


=head1 AUTHOR

Richard Leopold E<lt>moi-perl@leo.0n3.orgE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright 2002,2003 by Richard Leopold E<lt>moi-perl@leo.0n3.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

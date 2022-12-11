# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/Logger/lib/MOI/Logger/Base.pm,v 1.3 2003/06/30 09:53:22 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <moi-perl@leo.0n3.org>.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

package MOI::Logger::Base;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 
	'all' => [ qw(DEBUG INFO NOTICE WARNING ERR CRIT ALERT EMERG CHANNELS) ],
	'logchannels' => [qw(DEBUG INFO NOTICE WARNING ERR CRIT ALERT EMERG)],
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = (
	@{ $EXPORT_TAGS{'logchannels'} },
);

our $VERSION = '0.01';

## NOW the code starts ...

use File::Basename;

## defining channel - bits
use constant { 
      DEBUG    => 1,
      INFO     => 2,
      NOTICE   => 4,
      WARNING  => 8,
      ERR      => 16,
      CRIT     => 32,
      ALERT    => 64,
      EMERG    => 128,
      CHANNELS => {
            1 => 'DEBUG',
            2 => 'INFO',
            4 => 'MOTICE',
            8 => 'WARNING',
           16 => 'ERR',
           32 => 'CRIT',
           64 => 'ALERT',
          128 => 'EMERG'
      }
};

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my $parent = ref($proto) && $proto;
	
	my $self = {
	            name       => 'base-backend',
	            channel    => DEBUG|INFO|NOTICE|WARNING|ERR|CRIT|ALERT|EMERG,
	            format_cb  => \&_format_message,
	            filter_cb  => \&_filter_message,
	            @_
	           };
	
	bless $self, $class;
	
	return $self;
}

sub call_send_message {
	my $self      = shift;
	my $message   = shift || '';
	my $channel   = shift || 0;
	my $force     = shift || 0;
	
	return if ! ($self->check_channel($channel) || $force);
	
	my $msg = $self->{filter_cb}->($message);
	$self->send_message($self->{format_cb}->($msg, $channel));
	
	return 1;
}

# get-/setter
sub name {
	my $self = shift;
	
	$self->{name} = shift if @_;
	
	return $self->{name};
}

sub format_cb {
	my $self = shift;
	
	$self->{format_cb} = shift if @_;
	
	return $self->{format_cb};
}

sub filter_cb {
	my $self = shift;
	
	$self->{filter_cb} = shift if @_;
	
	return $self->{filter_cb};
}

sub channel {
	my $self = shift;
	
	$self->{channel} = shift if @_;
	
	return $self->{channel};
}

# Logger Hooks
sub send_message {
	my $self      = shift;
	my $message   = shift || '';
	
	# doing nothing
warn "doing nothing";
	
	return 1;
}

sub check_channel {
	my $self     = shift;
	my $channel  = shift;
	
	return $self->{channel} & $channel;
}

sub start { shift }

sub end { shift }


# base callback function to format the log output
sub _format_message {
	my $message   = shift || '';
	my $channel   = shift || 1;
	
	my $call      = basename($0);
	
	my $time = localtime;
	my @time = split /\s+/, $time;
	$time    = join(' ', @time[1...3]);
	
	$message =~ s/\n+$//;
	$message =~ s/\n/\n\t\t/g;
	
	sprintf "%s\t%s\t%s[%s]\t%s\t>>> %s\n", 
	            $time,
	            getlogin || $<,
	            $call,
	            $$,
	            exists CHANNELS->{$channel} ? CHANNELS->{$channel} : "#$channel#",
	            $message;
}

# base callback function to filter the log output
sub _filter_message { shift }


DESTROY {
	my $self = shift;
	$self->call_send_message('this Logger backend will be destroyed - bye !', INFO, 1);
}

1;
__END__

=head1 NAME

MOI::Logger::Base  - The MOI Logger class backend baqse class.

=head1 SYNOPSIS

  use MOI::Logger::Base;
  my $moi = MOI::Logger::Base->new();

=head1 ABSTRACT

  This is the base class for the L<MOI::Logger> backend. This class is
  the definition for the Implementation of further backends 
  (if really needed !).

=head1 DESCRIPTION

This class offers the base methods witch are hooked in to the L<MOI::Logger>
module. 
So this module defines the API for new L<MOI::Logger> backends.

=head2 Attributes by this base method

=over 10

=item I<name>

Holds the user-readable name for this backend. This I<name> will be used to map
the backends to the L<MOI::Logger> class.

=item I<channel>

Is the bitmask of the responsible logchannels to be logged by backend to be
created.

=item I<format_cb>

Is a function reference to format the log-message. The parameter passed to this
function are ($message, $channel). 

Feel free to write your own callback per backend, or use the internal function
given by this base class.

=back

=item I<filter_cb>

Is a function reference to filter the log-message. The parameter passed to this
function is ($message). 

Feel free to write your own filter per backend, or use the internal function
given by this base class.

=back

For this described base attributes I've defined get-/setter methods with the
same names as the attributes called.

=head2 To be hooked into the L<MOI::Logger> class

A few functions are hooked in (called by) in the logger class. In this base
class they are predefined, perhaps you have to write your own for your own 
backend ...

=over 10

=item start ()

The method to prepare the backend while adding it to the logger.
returns: C<$self> on success

=item end ()

The method to clean the backend while deleting it from the logger.
returns: C<$self> on success

=item check_channel($channel)

Testing if the backend matches the given logchannel
returns: bool

=item send_message($message)

Sending the message to the logger backend ...

returns: C<$self> on success

=back

For an example implementation please take a look at L<MOI::Logger::File>.


=head2 EXPORT

A few constants defining the logger channels:
 :logchannels = EMERG, ALERT, CRIT, ERR, WARNING, NOTICE, INFO, DEBUG

A hash to translate the logger - channels:
 CANNELS

=head1 SEE ALSO

L<MOI::Logger>

=head1 AUTHOR

Richard Leopold E<lt>moi-perl@leo.0n3.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002,2003 by Richard Leopold E<lt>moi-perl@leo.0n3.orgE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

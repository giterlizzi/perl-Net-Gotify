package Net::Gotify::Message;

use 5.010000;
use strict;
use warnings;
use utf8;

use Moo;

has message  => (is => 'rw', required => 1);
has title    => (is => 'rw');
has priority => (is => 'rw');
has extras   => (is => 'rw', default => sub { {} });
has appid    => (is => 'rw');
has date     => (is => 'rw');

1;

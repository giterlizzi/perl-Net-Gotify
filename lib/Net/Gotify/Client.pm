package Net::Gotify::Client;

use 5.010000;
use strict;
use warnings;
use utf8;

use Moo;

has id        => (is => 'rw');
has token     => (is => 'rw');
has name      => (is => 'rw');
has last_used => (is => 'rw');

1;

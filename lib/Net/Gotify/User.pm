package Net::Gotify::User;

use 5.010000;
use strict;
use warnings;
use utf8;

use Moo;

has admin => (is => 'rw');
has id    => (is => 'rw');
has name  => (is => 'rw');

1;

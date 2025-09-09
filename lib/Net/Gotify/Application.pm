package Net::Gotify::Application;

use 5.010000;
use strict;
use warnings;
use utf8;

use Moo;

has default_priority => (is => 'rw');
has description      => (is => 'rw');
has id               => (is => 'rw');
has image            => (is => 'rw');
has internal         => (is => 'rw');
has last_used        => (is => 'rw');
has name             => (is => 'rw');
has token            => (is => 'rw');

1;

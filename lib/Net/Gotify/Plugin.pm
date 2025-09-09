package Net::Gotify::Plugin;

use 5.010000;
use strict;
use warnings;
use utf8;

use Moo;

has author       => (is => 'rw');
has capabilities => (is => 'rw', default => sub { [] });
has enabled      => (is => 'rw');
has id           => (is => 'rw');
has license      => (is => 'rw');
has module_path  => (is => 'rw');
has name         => (is => 'rw');
has token        => (is => 'rw');
has website      => (is => 'rw');

1;

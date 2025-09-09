package Net::Gotify::Error;

use 5.010000;
use strict;
use warnings;
use utf8;

use Moo;

use overload '""' => 'to_string', fallback => 1;

has error       => (is => 'rw');
has code        => (is => 'rw');
has description => (is => 'rw');

sub to_string { shift->description }

1;

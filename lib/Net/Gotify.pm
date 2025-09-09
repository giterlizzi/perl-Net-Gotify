package Net::Gotify;

use 5.010000;
use strict;
use warnings;
use utf8;

use Moo;
use HTTP::Tiny;
use JSON::PP qw(encode_json decode_json);

use Net::Gotify::Application;
use Net::Gotify::Client;
use Net::Gotify::Error;
use Net::Gotify::Message;
use Net::Gotify::Plugin;
use Net::Gotify::User;

our $VERSION = '1.00';

$Carp::Internal{(__PACKAGE__)}++;

has base_url     => (is => 'ro', required => 1);
has app_token    => (is => 'ro');
has client_token => (is => 'ro');
has verify_ssl   => (is => 'ro');
has logger       => (is => 'ro');

sub _get_token {

    my ($self, $type) = @_;

    my $token = undef;

    if (lc($type) eq 'app') {
        $token = $self->app_token or Carp::croak 'Missing "app" token';
    }

    if (lc($type) eq 'client') {
        $token = $self->client_token or Carp::croak 'Missing "client" token';
    }

    return $token;
}

sub _hash_to_snake_case {

    my $hash   = shift;
    my $output = {};

    foreach my $key (keys %{$hash}) {
        (my $snake_key = $key) =~ s/([a-z0-9])([A-Z])/$1_\L$2/g;
        $output->{lc($snake_key)} = $hash->{$key};
    }

    return $output;

}

sub request {

    my ($self, %params) = @_;

    my $method     = delete $params{method} or Carp::croak 'Specify request "method"';
    my $token_type = delete $params{token_type} || 'client';
    my $path       = delete $params{path} or Carp::croak 'Specify request "path"';
    my $data       = delete $params{data} || {};
    my $options    = {};

    $method = uc $method;
    $path =~ s{^/}{};

    (my $agent = ref $self) =~ s{::}{-}g;

    my $ua = HTTP::Tiny->new(
        verify_SSL      => $self->verify_ssl,
        default_headers => {'Content-Type' => 'application/json', 'X-Gotify-Key' => $self->_get_token($token_type)},
        agent           => sprintf('%s/%s', $agent, $self->VERSION),
    );

    my $url = sprintf '%s/%s', $self->base_url, $path;

    if (ref $data eq 'HASH') {
        delete @$data{grep { not defined $data->{$_} } keys %{$data}};
        $options = {content => encode_json($data)};
    }

    my $response = $ua->request($method, $url, $options);

    if (my $logger = $self->logger) {
        $logger->info(sprintf('%s %s', $method, $url));
        $logger->debug(sprintf('[%s %s] %s', $response->{status}, $response->{reason}, $response->{content}));
    }

    my $output = eval { decode_json($response->{content}) } || {};

    if (!$response->{success}) {

        my $error = Net::Gotify::Error->new(
            error       => $output->{error}            || $response->{reason},
            code        => $output->{errorCode}        || $response->{status},
            description => $output->{errorDescription} || $response->{content},
        );

        if (my $logger = $self->logger) {
            $logger->error($error->description);
        }

        Carp::croak $error;

    }

    return $output;

}


# Messages

sub create_message {

    my ($self, %params) = @_;

    my $title    = delete $params{title};
    my $message  = delete $params{message} or Carp::croak 'Specify "message"';
    my $priority = delete $params{priority};
    my $extras   = delete $params{extras} || {};

    my $data = {title => $title, message => $message, priority => $priority, extras => $extras};

    my $response = $self->request(method => 'POST', path => '/message', data => $data, token_type => 'app');

    return Net::Gotify::Message->new(%{$response});

}

sub delete_message {

    my ($self, %params) = @_;

    my $id = delete $params{id} or Carp::croak 'Specify message "id"';

    $self->request(method => 'DELETE', path => sprintf('/message/%s', $id));

    return 1;

}

sub delete_messages {

    my ($self, %params) = @_;

    my $app_id = delete $params{app_id};
    my $path   = $app_id ? sprintf('/application/%s/message', $app_id) : '/message';

    $self->request(method => 'DELETE', path => $path);

    return 1;

}

sub get_messages {

    my ($self, %params) = @_;

    my $app_id = delete $params{app_id};
    my $limit  = delete $params{limit} || 100;
    my $since  = delete $params{since};

    my $params = HTTP::Tiny->www_form_urlencode({limit => $limit, since => $since});
    my $path   = $app_id ? "/application/$app_id/message" : '/message';

    my $response = $self->request(method => 'GET', path => "$path?$params");

    my @messages = map { Net::Gotify::Message->new(%{$_}) } @{$response->{messages}};

    return wantarray ? @messages : \@messages;

}


# Clients

sub get_clients {

    my ($self) = @_;

    my $response = $self->request(method => 'GET', path => '/client');

    my @clients = map { Net::Gotify::Client->new(%{_hash_to_snake_case($_)}) } @{$response};

    return wantarray ? @clients : \@clients;

}

sub create_client {

    my ($self, %params) = @_;

    my $name = delete $params{name} or Carp::croak 'Specify client "name"';

    my $response = $self->request(method => 'POST', path => '/client', data => {name => $name});

    return Net::Gotify::Client->new(%{_hash_to_snake_case($response)});

}

sub update_client {

    my ($self, $id, %params) = @_;

    Carp::croak 'Specify client "id"' unless $id;

    my $name = delete $params{name} or Carp::croak 'Specify client "name"';

    my $response = $self->request(method => 'PUT', path => "/client/$id", data => {name => $name});

    return Net::Gotify::Client->new(%{_hash_to_snake_case($response)});

}

sub delete_client {

    my ($self, $id) = @_;

    Carp::croak 'Specify client "id"' unless $id;

    $self->request(method => 'DELETE', path => "/client/$id");
    return 1;

}


# Applications

sub get_applications {

    my ($self) = @_;

    my $response     = $self->request(method => 'GET', path => '/application');
    my @applications = map { Net::Gotify::Application->new(%{_hash_to_snake_case($_)}) } @{$response};

    return wantarray ? @applications : \@applications;

}

sub create_application {

    my ($self, %params) = @_;

    my $name             = delete $params{name} or Carp::croak 'Specify application "name"';
    my $description      = delete $params{description};
    my $default_priority = delete $params{default_priority} || 0;

    my $response = $self->request(
        method => 'POST',
        path   => '/application',
        data   => {name => $name, description => $description, default_priority => $default_priority}
    );

    return Net::Gotify::Application->new(%{_hash_to_snake_case($response)});

}

sub update_application {

    my ($self, $id, %params) = @_;

    my $name             = delete $params{name} or Carp::croak 'Specify application "name"';
    my $description      = delete $params{description};
    my $default_priority = delete $params{default_priority} || 0;

    my $response = $self->request(
        method => 'PUT',
        path   => "/application/$id",
        data   => {name => $name, description => $description, default_priority => $default_priority}
    );

    return Net::Gotify::Application->new(%{_hash_to_snake_case($response)});

}

sub delete_application {

    my ($self, $id) = @_;

    Carp::croak 'Specify application "id"' unless $id;

    $self->request(method => 'DELETE', path => "/application/$id");
    return 1;

}

sub update_application_image { }
sub delete_application_image { }


# Plugins

sub get_plugins {

    my ($self) = @_;

    my $response = $self->request(method => 'GET', path => '/plugin');
    my @plugins  = map { Net::Gotify::Plugin->new(%{_hash_to_snake_case($_)}) } @{$response};

    return wantarray ? @plugins : \@plugins;

}

sub get_plugin_config    { }
sub update_plugin_config { }

sub enable_plugin {

    my ($self, $id) = @_;

    Carp::croak 'Specify plugin "id"' unless $id;

    $self->request(method => 'POST', path => "/plugin/$id/enable");
    return 1;

}

sub disable_plugin {

    my ($self, $id) = @_;

    Carp::croak 'Specify plugin "id"' unless $id;

    $self->request(method => 'POST', path => "/plugin/$id/disable");
    return 1;

}

sub get_plugin { }


# Users

sub current_user {

    my ($self) = @_;

    my $response = $self->request(method => 'GET', path => '/current/user');
    return Net::Gotify::User->new(%{_hash_to_snake_case($response)});

}

sub update_current_user_password {

    my ($self, $pass) = @_;

    Carp::croak 'Specify the new "password" for current user' unless $pass;

    my $response = $self->request(method => 'POST', path => '/current/user/password', data => {pass => $pass});

    return 1;

}

sub get_users {

    my ($self) = @_;

    my $response = $self->request(method => 'GET', path => '/user');
    my @users    = map { Net::Gotify::User->new(%{_hash_to_snake_case($_)}) } @{$response};

    return wantarray ? @users : \@users;

}

sub create_user {

    my ($self, %params) = @_;

    my $name  = delete $params{name}  or Carp::croak 'Specify user "name"';
    my $admin = delete $params{admin} or Carp::croak 'Specify user "admin" flag';
    my $pass  = delete $params{pass}  or Carp::croak 'Specify user "pass"';

    my $response
        = $self->request(method => 'POST', path => '/user', data => {name => $name, admin => $admin, pass => $pass});

    return Net::Gotify::User->new(%{_hash_to_snake_case($response)});

}

sub get_user {

    my ($self, $id) = @_;

    Carp::croak 'Specify user "id"' unless $id;

    my $response = $self->request(method => 'GET', path => "/user/$id");

    return Net::Gotify::User->new(%{_hash_to_snake_case($response)});

}

sub update_user {

    my ($self, $id, %params) = @_;

    Carp::croak 'Specify user "id"' unless $id;

    my $name  = delete $params{name}  or Carp::croak 'Specify user "name"';
    my $admin = delete $params{admin} or Carp::croak 'Specify user "admin" flag';
    my $pass  = delete $params{pass};

    my $response = $self->request(method => 'POST', path => "/user/$id",
        data => {name => $name, admin => $admin, pass => $pass});

    return Net::Gotify::User->new(%{_hash_to_snake_case($response)});

}

sub delete_user {

    my ($self, $id) = @_;

    Carp::croak 'Specify user "id"' unless $id;

    $self->request(method => 'DELETE', path => "/user/$id");
    return 1;

}

1;

=encoding utf-8

=head1 NAME

Net::Gotify - Gotify client for Perl 

=head1 SYNOPSIS

  use Net::Gotify;

  my $gotify = Net::Gotify->new(
      base_url     => 'http://localhost:8088',
      app_token    => '<TOKEN>',
      client_token => '<TOKEN>',
      logger       => $logger
  );

  $gotify->create_message(
      title    => 'Backup',
      message  => '**Backup** was successfully finished.',
      priority => 2,
      extras   => {
          'client::display' => {contentType   => 'text/markdown'}
      }
  );

=head1 DESCRIPTION

L<Net::Gotify> allows you to interact with Gotify server via Perl.

L<https://gotify.net/>


=head2 OBJECT-ORIENTED INTERFACE

=over

=item $gotify = Net::Gotify->new(%params)

=item $gotify->request

=back


=head3 Message API

=over

=item $gotify->create_message

=item $gotify->delete_message

=item $gotify->delete_messages

=item $gotify->get_messages

=back


=head3 Client API

=over

=item $gotify->get_clients

=item $gotify->create_client

=item $gotify->update_client

=item $gotify->delete_client

=back


=head3 Application API

=over

=item $gotify->get_applications

=item $gotify->create_application

=item $gotify->update_application

=item $gotify->delete_application

=item $gotify->update_application_image

=item $gotify->delete_application_image

=back


=head3 Plugin API

=over

=item $gotify->get_plugins

=item $gotify->get_plugin_config

=item $gotify->update_plugin_config

=item $gotify->enable_plugin

=item $gotify->disable_plugin

=item $gotify->get_plugin

=back


=head3 User API

=over

=item $gotify->current_user

=item $gotify->update_current_user_password

=item $gotify->get_users

=item $gotify->create_user

=item $gotify->get_user

=item $gotify->update_user

=item $gotify->delete_user

=back


=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/giterlizzi/perl-Net-Gotify/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/giterlizzi/perl-Net-Gotify>

    git clone https://github.com/giterlizzi/perl-Net-Gotify.git


=head1 AUTHOR

=over 4

=item * Giuseppe Di Terlizzi <gdt@cpan.org>

=back


=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2025 by Giuseppe Di Terlizzi.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

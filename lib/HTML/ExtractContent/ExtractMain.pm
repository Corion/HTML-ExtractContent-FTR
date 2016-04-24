package HTML::ExtractContent::ExtractMain;
use strict;
use Carp qw(croak);

use HTML::ExtractMain 'extract_main_html';
use File::Basename;

use vars qw($VERSION);
$VERSION = '0.01';

=head1 NAME

HTML::ExtractContent::ExtractMain - extract content using the Readability algorithm

=head1 SYNOPSIS

  use HTML::ExtractContent::ExtractMain;
  use LWP::UserAgent;

  my $agent = LWP::UserAgent->new;
  my $res = $agent->get('http://www.example.com/');

  my $extractor = HTML::ExtractContent::ExtractMain->new;
  my $info = $extractor->extract($res->decoded_content, url => $url);
  print $info->title, "\n";
  print $info->as_text, "\n";

This module is just an API fassade to adapt the API of
L<HTML::ExtractMain> to L<HTML::ExtractContent::Pluggable>.
It will only extract the main body.

=head1 METHODS

=head2 C<< ->extract >>

  my $info = $e->extract( $html );
  print $info->body;

=cut

sub extract {
    my( $self, $html, %options) = @_;
    my $main_html = extract_main_html($html, output_type => 'tree');

    if( defined $main_html ) {
        my %res    
        return HTML::ExtractContent::Info->new({
            body => $main_html,
        })
    }
}

1;
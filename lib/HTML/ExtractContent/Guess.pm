package HTML::ExtractContent::Guess;
use strict;
use HTML::ExtractContent;
use HTML::HeadParser;
use HTML::ExtractContent::Info;

=head1 NAME

HTML::ExtractContent::Guess - extract content using HTML::ExtractContent

=head1 SYNOPSIS

  use HTML::ExtractContent::Guess;
  use LWP::UserAgent;

  my $agent = LWP::UserAgent->new;
  my $url = 'http://www.example.com/';
  my $res = $agent->get($url);

  my $extractor = HTML::ExtractContent::Guess->new;
  $extractor->extract($res->decoded_content, url => $url);
  print $extractor->title, "\n";
  print $extractor->as_text, "\n";

=cut

sub new {
    my( $class, %options ) = @_;
    $options{ extractor } ||= HTML::ExtractContent->new();
    $options{ parser } ||= HTML::HeadParser->new();
}

sub extractor { $_[0]->{extractor} }
sub parser { $_[0]->{parser} }

sub extract {
    my( $self, $html, %options ) = @_;
    
    # Also save the title tag:
    $self->parser->parse($html);
    my $title = $self->parser->header('Title') || $options{ url };
    my $html = $self->extractor->extract($html)->as_text;
    
    if( $html ) {
        return HTML::ExtractContent::Info->new(
            title => $title,
            html => $html,
        );
    }
}

1;
package HTML::ExtractContent::Guess;
use strict;
use Moo;

use if $] < 5.020, 'Filter::signatures';
use feature 'signatures';
no warnings 'experimental::signatures';

use HTML::ExtractContent;
use HTML::HeadParser;
use HTML::ExtractContent::Info;
use HTML::ExtractContent::Guess::Date;

use vars '$VERSION';
$VERSION = '0.01';

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

has 'extractor' => (
    is => 'ro',
    default => sub { HTML::ExtractContent->new() },
);

has 'parser' => (
    is => 'ro',
    default => sub { HTML::HeadParser->new() },
);

has 'date_extractor' => (
    is => 'lazy',
    default => sub {
        require HTML::ExtractContent::Guess::Date;
        HTML::ExtractContent::Guess::Date->new();
    },
);

sub extract( $self, $html, %options ) {
    # Also save the title tag:
    $self->parser->parse($html);
    my $title = $self->parser->header('Title') || $options{ url };
    my $html = $self->extractor->extract($html)->as_text;
    my $date = $self->date_extractor->extract($html);
    
    if( $html ) {
        return HTML::ExtractContent::Info->new(
            title => $title,
            html => $html,
            date => $date,
        );
    }
}

1;

=head1 FUTURE IMPROVEMENTS

This should be able to guess the publication date from the URL
or from META parts of the content or any date appearing in the content.

=head2 Date extraction

L<https://wiki.whatwg.org/wiki/MetaExtensions>

C<< <meta name="dcterms.created" content="..."> >>

C<< <meta name="dc.created" content="..."> >>

C<< <meta name="created" content="..."> >>

If all these fail, guess by looking at the URL

Then, guess by looking at the page content.

=head1 SEE ALSO

L<HTML::ExtractMeta>

=cut
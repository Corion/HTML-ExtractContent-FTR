package HTML::ExtractContent::Guess::Date;
use strict;

use if $] < 5.020, 'Filter::signatures';
use feature 'signatures';
no warnings 'experimental::signatures';

use Moo;
use Mojo::DOM;
use HTML::ExtractContent::Info;
use Tree::XPathEngine::Mojo;

use vars '$VERSION';
$VERSION = '0.01';

=head1 NAME

HTML::ExtractContent::Guess::Date - heuristic for extracting the creation/publication date

=head1 SYNOPSIS

  use HTML::ExtractContent::Guess::Date;
  use LWP::UserAgent;

  my $agent = LWP::UserAgent->new;
  my $url = 'http://www.example.com/';
  my $res = $agent->get($url);

  my $tree = Mojo::DOM->new( $res );
  my $extractor = HTML::ExtractContent::Guess::Date->new;
  my $info = $extractor->extract($res->decoded_content, url => $url);
  print $info->date, "\n";

=cut

use vars '@date_expressions';
@date_expressions = (
    { query => '//meta[@name="dcterms.created"]', attribute => 'content' },
    { query => '//meta[@name="dc.created"]', attribute => 'content' },
    { query => '//meta[@name="created"]', attribute => 'content' },
    { query => '//date' },
    { query => '//*[contains(concat(" ",normalize-space(@class)," "),"created")]' },
    { query => '//*[contains(concat(" ",normalize-space(@class)," "),"published")]' },
    { query => '//*[contains(concat(" ",normalize-space(@class)," "),"date")]' },
    # Now, fish for stuff that looks like a date?!
);

has 'parser' => (
    is => 'ro',
    default => sub { Mojo::DOM->new() },
);

has 'expressions' => (
    is => 'ro',
    default => sub {[ @date_expressions ]},
);

has 'engine' => (
    is => 'ro',
    default => sub { Tree::XPathEngine::Mojo->new() },
);

sub extract( $self, $tree, %options ) {
    if( ! ref $tree) {
        $tree = Mojo::DOM->new($tree);
    };
    
    for my $rule (@{ $self->expressions }) {
        my $expression = $rule->{query};
        my @nodes = map { $_->{node} }
            $e->findnodes($expression,$tree);
        if( @nodes ) {
            my $node = $nodes[0];
            my $val = $rule->{attribute} ? $node->{ $rule->{attribute} }
                    : $node->content;
            # Here we should upgrade the date to yyyy-mm-dd or ISO
            return HTML::ExtractContent::Info->new(
                date => $val,
            );
        };
    };
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

=cut
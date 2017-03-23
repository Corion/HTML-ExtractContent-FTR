package HTML::ExtractContent::Guess::Date;
use strict;
use Moo 2;

use Filter::signatures;
no warnings 'experimental::signatures';
use feature 'signatures';

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
    is => 'lazy',
    default => sub { Mojo::DOM->new() },
);

has 'expressions' => (
    is => 'lazy',
    default => sub {[ @date_expressions ]},
);

has 'engine' => (
    is => 'lazy',
    default => sub { Tree::XPathEngine::Mojo->new() },
);

sub extract( $self, $tree, %options ) {
    $tree ||= '';
    if( ! ref $tree) {
        $tree = Mojo::DOM->new($tree);
    };
    
    my $res;
    
    # First we look at the URL and whether it gives us a hint
    if( my $url = $options{ url } ) {
        $url =~ m!\b((?:19|20)\d\d)(\D?)((?:0\d|1[012]))(\2)([012]\d|3[01])\b!
            # http://www.example.com/2017/01/01/foo-is-bad.html
            and $res = HTML::ExtractContent::Info->new({
                date => Mojo::DOM->new->parse("<date>$1-$3-$5</date>"),
            });
    };
    
    # Then we look at the content, first matching rule is good
    if(! $res) {
        my $ctx = Tree::XPathEngine::Mojo->new($tree);
        my $e = Tree::XPathEngine->new();
        for my $rule (@{ $self->expressions }) {
            my $expression = $rule->{query};
            my @nodes = map { $_->{node} }
                $e->findnodes($expression,$ctx);
            if( @nodes ) {
                my $node = $nodes[0];
                my $val = $rule->{attribute} ? $node->{ $rule->{attribute} }
                        : $node->content;
                # Here we should upgrade the date to yyyy-mm-dd or ISO
                $res =  HTML::ExtractContent::Info->new({
                    date =>$val,
                });
                last
            };
        };
    };
    $res
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
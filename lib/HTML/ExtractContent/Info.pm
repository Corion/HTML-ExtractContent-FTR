package HTML::ExtractContent::Info;
use strict;
use Mojo::DOM;

use vars '$VERSION';

sub new {
    my( $class, $info ) = @_;
    bless $info => $class
}

sub tree_as_text {
    my($self, $attr) = @_;
    if( my $tree = $self->{$attr}) {
        my $res = Mojo::DOM->new();
        $res->append_content( $_ ) for @$tree;
        $res->content
    } else {
        undef
    }
}

sub title { $_[0]->tree_as_text('title') }
sub body { $_[0]->tree_as_text('body') }
sub author { $_[0]->tree_as_text('author') }
sub date { $_[0]->tree_as_text('date') }
sub as_text { $_[0]->body }

sub title_tree { $_[0]->{title} }
sub body_tree { $_[0]->{body} }
sub author_tree { $_[0]->{author} }
sub date_tree { $_[0]->{date} }

1;
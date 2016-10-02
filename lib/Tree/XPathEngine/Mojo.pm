package Tree::XPathEngine::Mojo;
use strict;
use if $] < 5.020, 'Filter::signatures';
use feature 'signatures';
no warnings 'experimental::signatures';
use Tree::XPathEngine;
use Mojo::DOM;

=head1 NAME

Tree::XPathEngine::Mojo - XPath queries for Mojo::DOM

=head1 SYNOPSIS

    my $html = do { local (@ARGV, $/) = 't/postillon.html'; <> };
    my $mojo= Mojo::DOM->new()->parse($html);
    my $ctx = Tree::XPathEngine::Mojo->new($mojo);
    my $e = Tree::XPathEngine->new();

    print "$_" for map { $_->{node} }
          $e->findnodes('//div[contains(@class,"post-body")]', $ctx);

=cut

sub new($class,$tree) {
    $tree = $tree->root;
    bless { node => $tree } => $class;
}

sub wrap($self,$e) {
    bless { node => $e } => ref $self;
}

sub xpath_get_name($node) {
    $node->{node}->tag
};
sub xpath_get_next_sibling($node) {
    $node->wrap( $node->{node}->following )
}
sub xpath_get_previous_sibling($node) {
    $node->wrap( $node->{node}->preceding )
}
sub xpath_get_root_node($node) {
    $node->wrap( $node->{node}->root )
}
sub xpath_get_parent_node($node) {
    $node->wrap( $node->{node}->parent )
}
sub xpath_get_child_nodes($node) {
    map { $node->wrap( $_ ) } @{ $node->{node}->child_nodes }
}
sub xpath_string_value($self) {
    $self->{ node }->content
}

sub xpath_is_element_node($node) {
    $node->{node}->type eq 'tag'
}
sub xpath_is_document_node($node) {
    $node->{node}->type eq 'root'
}
sub xpath_is_text_node($node) {
       $node->{node}->type eq 'text'
    || $node->{node}->type eq 'raw'
}
sub xpath_is_attribute_node($node) {
    return 0;
}

sub xpath_cmp($l,$r) {
    return -1
}; # meh

sub xpath_get_attributes($node) {
    map { Mojo::DOM::Attribute->new($node->{node}, $_ ) } keys %{$node->{node}}
}
sub xpath_to_literal($node) {
    warn "To literal";
    "$node->{node}"
} # only if you want to use findnodes_as_string or findvalue

#sub root($self) { $self->wrap( $self->{node}->root ) }

package Mojo::DOM::Attribute;
use strict;
use if $] < 5.020, 'Filter::signatures';
use feature 'signatures';
no warnings 'experimental::signatures';

use vars qw(@ISA);

@ISA = 'Tree::XPathEngine::Mojo';

sub new($class,$node,$name) {
    bless { node => $node, name => $name } => $class;
}

sub xpath_to_literal($self) {
    warn "Attribute To literal";
    $self->{ node }->{ $self->{ name } }
};

sub xpath_is_element_node($node) {
    0
}
sub xpath_is_document_node($node) {
    0
}
sub xpath_is_text_node($node) {
    0
}

sub xpath_is_attribute_node($node) {
    1;
}

sub xpath_get_name($self) {
    $self->{name}
}
sub to_string($self) {
    return sprintf( '%s="%s"', $self->{name}, $self->xpath_string_value );
}
sub xpath_string_value($self) {
    $self->{ node }->{ $self->{ name } }
}
sub xpath_get_child_nodes   {}

package Mojo::DOM::Text;
use strict;
use if $] < 5.020, 'Filter::signatures';
use feature 'signatures';
no warnings 'experimental::signatures';

use vars qw(@ISA);

@ISA = 'Tree::XPathEngine::Mojo';

sub new($class,$node,$name) {
    bless { node => $node, name => $name } => $class;
}

sub xpath_to_literal($self) {
    warn "Attribute To literal";
    $self->{ node }->{ $self->{ name } }
};

sub xpath_is_element_node($node) {
    0
}
sub xpath_is_document_node($node) {
    0
}
sub xpath_is_text_node($node) {
    0
}

sub xpath_is_attribute_node($node) {
    1;
}

sub xpath_get_name($self) {
    $self->{name}
}
sub to_string($self) {
    return sprintf( '%s="%s"', $self->{name}, $self->xpath_string_value );
}
sub xpath_string_value($self) {
    $self->{ node }->{ $self->{ name } }
}
sub xpath_get_child_nodes   {}

1;

package HTML::ExtractContent::Pluggable;
use strict;
use Carp qw(croak);

=head1 NAME

HTML::ExtractContent::Pluggable - cascade of content extractors

=head1 SYNOPSIS

  use HTML::ExtractContent::Pluggable;
  use LWP::UserAgent;

  my $agent = LWP::UserAgent->new;
  my $url = 'http://www.example.com/';
  my $res = $agent->get($url);

  my $extractor = HTML::ExtractContent::Pluggable->new(
      plugins => [
          'HTML::ExtractContent::FTR',
          'HTML::ExtractContent::Guess',
          # or sub { HTML::ExtractContent::FTR->new(...) }
      ],
  );
  my $info = $extractor->extract($res->decoded_content, url => $url);
  print $info->title, "\n";
  print $info->author, "\n";
  print $info->date, "\n";
  print $info->as_text, "\n";

=cut

sub new {
    my( $class, %options ) = @_;

    my @plugins = @{ $options{ plugins }
                     || []
                   };
    
    # Load all plugins where we only have a name
    # For safety reasons, we only allow certain names of plugins
    # just in case somebody allows these to be specified by an outside
    # user
    for( grep {! ref $_} @plugins ) {
        /^\w+(::\w+)*$/
            or croak "Invalid plugin name: [$_]";
        eval qq(require $_)
            or croak $@;
    };
    
    # Upgrade all plugins to constructor syntax
    @plugins = map { ref $_ ? $_ : sub { $_->new() } } @plugins;
    
    bless {
        plugins => \@plugins
    } => $class
}

sub plugins { $_[0]->{plugins} }
sub match { $_[0]->{match} }

sub extract {
    my( $self, $html, %options ) = @_;
    my $res;
    for my $plugin_creator ($self->plugins) {
        my $plugin = $plugin_creator->();
        if( my $res = $plugin->extract($html, %options)) {
            $self->{match} = $res;
            return $res
        };
    }
    return()
}

package HTML::ExtractContent::Info;
use strict;

sub new {
    my( $class, $info ) = @_;
    bless $info => $class
}

sub tree_as_text {
    my($self, $attr) = @_;
    if( my $tree = $self->{$attr}) {
        my $res = HTML::Element->new('div');
        $res->push_content( @$tree );
        $res->as_text
        #$tree->as_text
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

=head1 FUTURE IMPROVEMENTS

This should be able to guess the publication date from the URL
or from META parts of the content or any date appearing in the content.

=cut
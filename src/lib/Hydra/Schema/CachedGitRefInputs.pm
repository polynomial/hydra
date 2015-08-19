use utf8;
package Hydra::Schema::CachedGitRefInputs;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Hydra::Schema::CachedGitRefInputs

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<Hydra::Component::ToJSON>

=back

=cut

__PACKAGE__->load_components("+Hydra::Component::ToJSON");

=head1 TABLE: C<CachedGitRefInputs>

=cut

__PACKAGE__->table("CachedGitRefInputs");

=head1 ACCESSORS

=head2 uri

  data_type: 'text'
  is_nullable: 0

=head2 ref

  data_type: 'text'
  is_nullable: 0

=head2 revision

  data_type: 'text'
  is_nullable: 0

=head2 sha256hash

  data_type: 'text'
  is_nullable: 0

=head2 storepath

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "uri",
  { data_type => "text", is_nullable => 0 },
  "ref",
  { data_type => "text", is_nullable => 0 },
  "revision",
  { data_type => "text", is_nullable => 0 },
  "sha256hash",
  { data_type => "text", is_nullable => 0 },
  "storepath",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</uri>

=item * L</ref>

=item * L</revision>

=back

=cut

__PACKAGE__->set_primary_key("uri", "ref", "revision");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2013-06-13 01:54:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:I4hI02FKRMkw76WV/KBocA

1;

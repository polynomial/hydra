package Hydra::Schema::Releasesets;

use strict;
use warnings;

use base 'DBIx::Class';

__PACKAGE__->load_components("Core");
__PACKAGE__->table("ReleaseSets");
__PACKAGE__->add_columns(
  "project",
  { data_type => "text", is_nullable => 0, size => undef },
  "name",
  { data_type => "text", is_nullable => 0, size => undef },
  "description",
  { data_type => "text", is_nullable => 0, size => undef },
  "keep",
  { data_type => "integer", is_nullable => 0, size => undef },
);
__PACKAGE__->set_primary_key("project", "name");
__PACKAGE__->belongs_to("project", "Hydra::Schema::Projects", { name => "project" });
__PACKAGE__->has_many(
  "releasesetjobs",
  "Hydra::Schema::Releasesetjobs",
  {
    "foreign.project" => "self.project",
    "foreign.release" => "self.name",
  },
);


# Created by DBIx::Class::Schema::Loader v0.04005 @ 2008-11-28 18:56:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2SXTc8MC9KG9VM0uRHUwig


# You can replace this text with custom content, and it will be preserved on regeneration
1;
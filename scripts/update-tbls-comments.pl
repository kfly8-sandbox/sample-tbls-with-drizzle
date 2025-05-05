#!/usr/bin/env perl
use strict;
use warnings;
use Carp qw(cluck confess);

use JSON qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);
use YAML qw(LoadFile DumpFile Dump);
use Encode qw(encode decode);
use Getopt::Long qw(GetOptions);

# Command line options
my $diff_file = '';
my $tbls_file = 'tbls.yml';
my $schema_file = 'src/db/schema.ts';
my $verbose = 0;

GetOptions(
    "diff=s"      => \$diff_file,
    "tbls=s"      => \$tbls_file,
    "schema=s"    => \$schema_file,
    "verbose"     => \$verbose,
) or die "Error in command line arguments\n";

# Check if diff file is provided
if (!$diff_file && !-f $schema_file) {
    die "Error: Either diff file must be provided or schema file must exist\n";
}

# Function to extract comments using regex
sub extract_comments_with_regex {
    my ($schema_content) = @_;
    my %comments;

    use DDP;

    while ($schema_content =~ m!(//.+)export\s*const\s*\w+\s*=\s*pgTable\(\s*["'](\w+)["'],\s*{\s*(.+)\}*!gsx) {
        my $table_comment = $1;
        my $table_name = $2;
        my $column_block = $3;

        $table_comment =~ s!\+*//\s*!!g;

        my $b = {
            table_comment => $table_comment,
            table_name => $table_name,
            column_block => $column_block,
        };
        p $b;

    }


    if(0) {

        my $comment_block = $1;
        my $table_name = $2;

        print "Found table: $table_name\n" if $verbose;
        print "Comment block: $comment_block\n" if $verbose;

#        # テーブルコメントを処理
#        my $table_description = "";
#        while ($comment_block =~ m{//\s*(.+?)(?:\n|$)}g) {
#            $table_description .= $1 . "\n";
#        }
#        $table_description =~ s/\n$//; # 最後の改行を削除
#
#        # コメントマップを初期化
#        $comments{$table_name} = {
#            description => $table_description,
#            columns => {}
#        };

        #        $comments{$table_name}{columns}{$column_name} = $column_description;
    }

    p %comments;

    return \%comments;
}

# Read tbls.yml
print "Reading tbls configuration from $tbls_file\n" if $verbose;
my $tbls_config = YAML::LoadFile($tbls_file);

# Initialize comments if not exists
$tbls_config->{comments} = [] unless exists $tbls_config->{comments};

# Get the diff or full schema
my $schema_content;
if ($diff_file) {
    print "Reading diff from $diff_file\n" if $verbose;
    $schema_content = read_file($diff_file);
} else {
    print "Reading full schema from $schema_file\n" if $verbose;
    $schema_content = read_file($schema_file);
}

# Extract comments using regex
print "Extracting comments from schema...\n" if $verbose;
my $extracted_comments = extract_comments_with_regex($schema_content);

# Update tbls.yml comments
if ($extracted_comments) {
    print "Updating tbls.yml comments...\n" if $verbose;

    # Create a map of existing tables for quick lookup
    my %existing_tables;
    foreach my $table_entry (@{$tbls_config->{comments}}) {
        if (exists $table_entry->{table}) {
            $existing_tables{$table_entry->{table}} = $table_entry;
        }
    }

    # Process extracted comments and update tbls.yml
    foreach my $table_name (keys %{$extracted_comments}) {
        my $table_data = $extracted_comments->{$table_name};

        # Check if the table exists in the config
        if (exists $existing_tables{$table_name}) {
            # Update existing table entry
            my $table_entry = $existing_tables{$table_name};

            # Update table comment
            if (exists $table_data->{description} && $table_data->{description}) {
                $table_entry->{tableComment} = $table_data->{description};
            }

            # Update column comments
            if (exists $table_data->{columns} && $table_data->{columns}) {
                $table_entry->{columnComments} = {}
                    unless exists $table_entry->{columnComments};

                foreach my $column_name (keys %{$table_data->{columns}}) {
                    my $comment = $table_data->{columns}{$column_name};
                    $table_entry->{columnComments}{$column_name} = $comment;
                }
            }
        } else {
            # Create a new table entry
            my $new_entry = {
                table => $table_name,
            };

            # Add table comment if exists
            if (exists $table_data->{description} && $table_data->{description}) {
                $new_entry->{tableComment} = $table_data->{description};
            }

            # Add column comments if exist
            if (exists $table_data->{columns} && $table_data->{columns} && %{$table_data->{columns}}) {
                $new_entry->{columnComments} = {};

                foreach my $column_name (keys %{$table_data->{columns}}) {
                    my $comment = $table_data->{columns}{$column_name};
                    $new_entry->{columnComments}{$column_name} = $comment;
                }
            }

            # Add the new entry to the comments array
            push @{$tbls_config->{comments}}, $new_entry;
        }
    }

    # Save updated tbls.yml
    print "Saving updated tbls configuration to $tbls_file\n" if $verbose;
    eval {
        # Ensure UTF-8 encoding for YAML output
        binmode(STDOUT, ":utf8");
        my $yaml_content = YAML::Dump($tbls_config);
        open my $out, ">:utf8", $tbls_file or die "Could not open $tbls_file for writing: $!";
        print $out $yaml_content;
        close $out;
    };
    if ($@) {
        confess "Failed to save YAML file $tbls_file: $@\n";
    }
    print "Comments successfully updated in $tbls_file\n";
} else {
    print "No comments found in schema\n";
}

# Print debug information if verbose
if ($verbose) {
    print "\nExtracted comments:\n";
    foreach my $table_name (sort keys %{$extracted_comments}) {
        print "Table: $table_name\n";
        if (exists $extracted_comments->{$table_name}{description}) {
            print "  TableComment: " . $extracted_comments->{$table_name}{description} . "\n";
        }

        if (exists $extracted_comments->{$table_name}{columns}) {
            print "  ColumnComments:\n";
            foreach my $column_name (sort keys %{$extracted_comments->{$table_name}{columns}}) {
                print "    $column_name: " . $extracted_comments->{$table_name}{columns}{$column_name} . "\n";
            }
        }
    }

    print "\nFinal tbls.yml comments structure:\n";
    foreach my $table_entry (@{$tbls_config->{comments}}) {
        print "- Table: " . $table_entry->{table} . "\n";
        if (exists $table_entry->{tableComment}) {
            print "  TableComment: " . $table_entry->{tableComment} . "\n";
        }

        if (exists $table_entry->{columnComments}) {
            print "  ColumnComments:\n";
            foreach my $column_name (sort keys %{$table_entry->{columnComments}}) {
                print "    $column_name: " . $table_entry->{columnComments}{$column_name} . "\n";
            }
        }
    }
}

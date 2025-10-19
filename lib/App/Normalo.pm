package App::Normalo;

use 5.040000;
use strict;
use warnings;

use Encode qw(decode);
use English qw(-no_match_vars);
use File::Basename qw(basename dirname fileparse);
use File::Spec::Functions qw(catfile);
use Text::Unidecode qw(unidecode);

our $VERSION = '0.01';

# Preloaded methods go here.

sub convert {
    my ($filename) = @_;

    # Split filename into stem and extension
    my ($stem, undef, $extension) = fileparse($filename, qr/ [.] [^.]* /smx);

    # Convert UTF-8 to ASCII with transliteration
    my $converted = unidecode decode 'UTF-8', $stem;

    # Convert to lowercase
    $converted = lc $converted;

    # Replace spaces, underscores, and dots with hyphens
    $converted =~ tr/ _./-/;

    # Remove non-alphanumeric characters (keep hyphens only)
    $converted =~ s{ [^[:alnum:]-] }{}smxg;

    # Replace multiple consecutive hyphens with single hyphen
    $converted =~ s{ -+ }{-}smxg;

    # Rejoin with extension if present (lowercase the extension too)
    return $extension ? $converted . lc $extension : $converted;
}

sub run {
    my ($class, @args) = @_;

    foreach my $path (@args) {
        if (!-f $path) {
            print {*STDERR} $path . " is not a regular file\n";
            return 1;
        }

        my $filename = basename $path;
        my $dir = dirname $path;
        my $kebab_filename = convert $filename;

        if ($kebab_filename ne $filename) {
            my $new_path = catfile($dir, $kebab_filename);
            rename $path, $new_path
                or die 'Failed to rename ' . $path . ' to ' . $new_path . ': ' . $OS_ERROR . "\n";
        }
    }

    return 0;
}

1;
__END__

=head1 NAME

App::Normalo - Normalize filenames to kebab-case

=head1 SYNOPSIS

  use App::Normalo;

  # Convert a filename to kebab-case
  my $normalized = App::Normalo::convert('My File Name.txt');
  # Returns: my-file-name.txt

  # Run as an application
  App::Normalo->run(@ARGV);

=head1 VERSION

Version 0.01

=head1 DESCRIPTION

App::Normalo normalizes filenames by converting them to kebab-case format.
It performs the following transformations:

=over 4

=item * Converts UTF-8 characters to ASCII equivalents (transliteration)

=item * Converts to lowercase

=item * Replaces spaces, underscores, and dots with hyphens

=item * Removes non-alphanumeric characters (except hyphens)

=item * Collapses multiple consecutive hyphens into a single hyphen

=item * Preserves file extensions

=back

=head1 SUBROUTINES/METHODS

=head2 convert($filename)

Converts a filename to kebab-case format and returns the normalized filename.
Does not modify files on disk.

=head2 run($class, @args)

Command-line interface. Renames files specified in @args to their kebab-case
equivalents. Returns 0 on success, 1 on error.

=head1 COMMAND LINE USAGE

  normalo file1.txt file2.txt ...

=head1 DIAGNOSTICS

=over 4

=item C<< %s is not a regular file >>

The specified path is not a regular file. Only regular files can be renamed.

=item C<< Failed to rename %s to %s: %s >>

The rename operation failed. The error message from the system is included.

=back

=head1 CONFIGURATION AND ENVIRONMENT

App::Normalo requires no configuration files or environment variables.

=head1 DEPENDENCIES

=over 4

=item * Text::Unidecode

=item * Encode (core module)

=item * English (core module)

=item * File::Basename (core module)

=item * File::Spec::Functions (core module)

=back

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to the author.

=head1 AUTHOR

Henry Till, E<lt>henrytill@gmail.comE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 by Henry Till

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.40.0 or,
at your option, any later version of Perl 5 you may have available.


=cut

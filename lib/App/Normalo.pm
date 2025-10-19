package App::Normalo;

use 5.040000;
use strict;
use warnings;

use Encode qw(decode);
use English qw(-no_match_vars);
use File::Basename qw(basename dirname fileparse);
use File::Spec::Functions qw(catfile);
use Getopt::Long qw(GetOptionsFromArray);
use Text::Unidecode qw(unidecode);

our $VERSION = '0.03';

# Preloaded methods go here.

sub convert {
    my ($filename) = @_;

    # Split filename into stem and extension
    my ($stem, undef, $extension) = fileparse($filename, qr/ [.] [^.]* /smx);

    # Convert UTF-8 to ASCII with transliteration
    my $converted = unidecode decode 'UTF-8', $stem;

    # Convert to lowercase
    $converted = lc $converted;

    # Replace spaces, underscores, dots, and control characters with hyphens
    $converted =~ tr/ _./-/;
    $converted =~ s{ [[:cntrl:]] }{-}smxg;

    # Remove non-alphanumeric characters (keep hyphens only)
    $converted =~ s{ [^[:alnum:]-] }{}smxg;

    # Replace multiple consecutive hyphens with single hyphen
    $converted =~ s{ -+ }{-}smxg;

    # Rejoin with extension if present (lowercase the extension too)
    return $extension ? $converted . lc $extension : $converted;
}

sub run {
    my ($class, @args) = @_;

    my $progname = basename $PROGRAM_NAME;
    my %opts;

    GetOptionsFromArray(\@args, \%opts, 'help|h', 'version|v',)
        or do {
            print {*STDERR} "Try '$progname --help' for more information.\n";
            return 1;
        };

    if ($opts{version}) {
        print "$progname version $VERSION\n";
        return 0;
    }

    if ($opts{help}) {
        print <<"END_HELP";
Usage: $progname [OPTIONS] FILE...

Normalize filenames to kebab-case format.

Options:
  -h, --help       Display this help message and exit
  -v, --version    Display version information and exit

Examples:
  $progname "My File.txt"
  $progname file1.txt file2.txt file3.txt
END_HELP
        return 0;
    }

    if (!@args) {
        print {*STDERR} "$progname: missing file operand\n";
        print {*STDERR} "Try '$progname --help' for more information.\n";
        return 1;
    }

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

            if (-e $new_path) {
                print {*STDERR} "Cannot rename $path to $new_path: target already exists\n";
                return 1;
            }

            rename $path, $new_path
                or die 'Failed to rename ' . $path . ' to ' . $new_path . ': ' . $OS_ERROR . "\n";
        }
    }

    return 0;
}

1;
__END__

=encoding UTF-8

=head1 NAME

App::Normalo - Normalize filenames to kebab-case

=head1 SYNOPSIS

  use App::Normalo;

  # Convert a filename to kebab-case
  my $normalized = App::Normalo::convert('My File Name.txt');
  # Returns: my-file-name.txt

=head1 VERSION

Version 0.03

=head1 DESCRIPTION

App::Normalo is a Perl module for normalizing filenames to kebab-case format.
It can be used as a library or via the L<normalo> command-line tool.

=head1 SUBROUTINES/METHODS

=head2 convert()

  my $normalized = App::Normalo::convert($filename);

Converts a filename to kebab-case format and returns the normalized filename.
Does not modify files on disk.

Takes a single argument, the filename to normalize, and returns the normalized
filename as a string.

Example:

  my $result = App::Normalo::convert('My File.txt');
  # $result is 'my-file.txt'

=head2 run()

  my $exit_code = App::Normalo->run(@ARGV);

Command-line entry point. Processes command-line arguments and renames files
to their kebab-case equivalents.

Takes the class name and a list of command-line arguments (typically C<@ARGV>).
Returns an exit code: 0 on success, 1 on error.

This method is typically not called directly. Use the L<normalo> command-line
tool instead.

=head1 DEPENDENCIES

=over 4

=item * Text::Unidecode

=item * Encode (core module)

=item * English (core module)

=item * File::Basename (core module)

=item * File::Spec::Functions (core module)

=item * Getopt::Long (core module)

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

=head1 SEE ALSO

L<normalo> - Command-line interface to this module

=cut

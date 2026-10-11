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

our $VERSION = '0.05';

# Preloaded methods go here.

# Transliterate $text to ASCII and reduce it to lowercase alphanumerics
# separated by single hyphens.
sub kebab {
    my ($text) = @_;

    # Convert to ASCII with transliteration
    my $converted = unidecode $text;

    # Convert to lowercase
    $converted = lc $converted;

    # Replace spaces, underscores, dots, and control characters with hyphens
    $converted =~ tr/ _./-/;
    $converted =~ s{ [[:cntrl:]] }{-}smxg;

    # Remove non-alphanumeric characters (keep hyphens only)
    $converted =~ s{ [^[:alnum:]-] }{}smxg;

    # Replace multiple consecutive hyphens with single hyphen
    $converted =~ s{ -+ }{-}smxg;

    return $converted;
}

sub convert {
    my ($filename) = @_;

    # Split filename into stem and extension, decoding first so that the
    # extension is split on characters rather than bytes
    my ($stem, undef, $extension) = fileparse(decode('UTF-8', $filename), qr/ [.] [^.]* /smx);

    my $converted = kebab $stem;

    # Normalize the extension the same way, but without the hyphens, and
    # drop it if nothing is left
    if ($extension) {
        (my $ext = kebab substr $extension, 1) =~ tr/-//d;
        $converted .= ".$ext" if $ext ne q{};
    }

    # Leave the name alone rather than reduce it to nothing
    return $converted ne q{} ? $converted : $filename;
}

sub run {
    my ($class, @args) = @_;

    return main(\@args, progname => basename($PROGRAM_NAME), out => \*STDOUT, err => \*STDERR);
}

sub main {
    my ($args, %env) = @_;

    my @args = @{$args};
    my ($progname, $out, $err) = @env{qw(progname out err)};
    my %opts;

    # Getopt::Long reports bad options with warn, so send those to $err too
    my $parsed = do {
        local $SIG{__WARN__} = sub { print {$err} @_ };
        GetOptionsFromArray(\@args, \%opts, 'help|h', 'version|v',);
    };

    if (!$parsed) {
        print {$err} "Try '$progname --help' for more information.\n";
        return 1;
    }

    if ($opts{version}) {
        print {$out} "$progname version $VERSION\n";
        return 0;
    }

    if ($opts{help}) {
        print {$out} <<"END_HELP";
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
        print {$err} "$progname: missing file operand\n";
        print {$err} "Try '$progname --help' for more information.\n";
        return 1;
    }

    # Report each failure and keep going, like mv(1), so that one bad path
    # doesn't leave the rest of the batch unprocessed
    my $status = 0;

    foreach my $path (@args) {
        if (!-f $path) {
            print {$err} "$progname: $path is not a regular file\n";
            $status = 1;
            next;
        }

        my $filename = basename $path;
        my $dir = dirname $path;
        my $kebab_filename = convert $filename;

        next if $kebab_filename eq $filename;

        my $new_path = catfile($dir, $kebab_filename);

        if (-e $new_path) {
            print {$err} "$progname: cannot rename $path to $new_path: target already exists\n";
            $status = 1;
            next;
        }

        if (!rename $path, $new_path) {
            print {$err} "$progname: failed to rename $path to $new_path: $OS_ERROR\n";
            $status = 1;
        }
    }

    return $status;
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

Version 0.05

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
to their kebab-case equivalents. A path that can't be renamed is reported and
skipped, and the remaining paths are still processed.

Takes the class name and a list of command-line arguments (typically C<@ARGV>).
Returns an exit code: 0 on success, 1 if any path could not be renamed or the
arguments are invalid.

This method is typically not called directly. Use the L<normalo> command-line
tool instead.

=head2 main()

  my $exit_code = App::Normalo::main(\@args,
      progname => 'normalo',
      out      => \*STDOUT,
      err      => \*STDERR,
  );

Does the work of C<run()>, taking its environment as parameters instead of
from globals. C<run()> calls it with the basename of C<$0> and the standard
filehandles.

Takes a reference to the list of command-line arguments, then three required
named parameters: C<progname> names the program in messages, help and version
output go to the C<out> filehandle, and error messages go to C<err>.

Returns an exit code, as C<run()> does. Does not modify the array that
C<\@args> refers to.

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

Please report bugs and feature requests at
L<https://github.com/henrytill/App-Normalo/issues>.

=head1 AUTHOR

Henry Till, E<lt>henrytill@gmail.comE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025-2026 by Henry Till

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.40.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

L<normalo> - Command-line interface to this module

=cut

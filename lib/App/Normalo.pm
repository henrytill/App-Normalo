package App::Normalo;

use 5.040000;
use strict;
use warnings;

use Encode qw(decode FB_CROAK LEAVE_SRC);
use English qw(-no_match_vars);
use File::Basename qw(basename dirname fileparse);
use File::Spec::Functions qw(catfile);
use Getopt::Long qw(GetOptionsFromArray);
use Text::Unidecode qw(unidecode);

our $VERSION = '0.11';

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

    # Trim hyphens from the ends, so that the result can't be mistaken for an
    # option
    $converted =~ s{ \A - | - \z }{}smxg;

    return $converted;
}

# Decode $filename strictly as UTF-8, or die saying why it can't be. Refuse
# to guess at a name in some other encoding: decoding it leniently would turn
# its non-ASCII bytes into U+FFFD, which kebab then strips without a trace.
sub decode_name {
    my ($filename) = @_;

    my $decoded = eval { decode('UTF-8', $filename, FB_CROAK | LEAVE_SRC) };
    return $decoded if defined $decoded;

    # Strict decoding also refuses noncharacters such as U+FFFE, which are
    # valid UTF-8 but have no transliteration. Decode leniently to tell them
    # apart from bytes that aren't UTF-8 at all.
    my $lax = eval { decode('utf8', $filename, FB_CROAK | LEAVE_SRC) } // q{};
    die "name contains a Unicode noncharacter\n"
        if $lax !~ / [^\x{0}-\x{D7FF}\x{E000}-\x{10FFFF}] /smx
        && $lax =~ / \p{Noncharacter_Code_Point} /smx;
    die "name is not valid UTF-8\n";
}

sub convert {
    my ($filename) = @_;

    my $decoded = decode_name($filename);

    # Split the decoded name, so that the extension is split on characters
    # rather than bytes
    my ($stem, undef, $extension) = fileparse($decoded, qr/ [.] [^.]* /smx);

    my $converted = kebab $stem;

    # Leave the name alone if its stem normalizes to nothing, rather than
    # hide the file behind its extension. A dotfile's stem is already empty.
    return $filename if $stem ne q{} && $converted eq q{};

    # Normalize the extension the same way, but without the hyphens, and
    # drop it if nothing is left
    if ($extension) {
        (my $ext = kebab substr $extension, 1) =~ tr/-//d;
        $converted .= ".$ext" if $ext ne q{};
    }

    # Only a dotfile whose extension normalizes to nothing can get here empty.
    # Once #9 parses dotfiles with a stem, the check above covers this too.
    return $converted ne q{} ? $converted : $filename;
}

# Rename $from to $to without replacing anything already at $to. Return undef
# on success, or a message saying why it couldn't be renamed.
sub rename_noreplace {
    my ($from, $to) = @_;

    # rename(2) silently replaces an existing target, but link(2) and
    # symlink(2) fail if it exists, so create the new name with one of those
    # and then remove the old one. Recreate a symlink rather than link it,
    # since some systems' link(2) follows symlinks.
    my $created =
        -l $from
        ? do { my $target = readlink $from; defined $target && symlink $target, $to }
        : link $from, $to;

    if ($created) {
        unlink $from or return "failed to remove $from after linking it to $to: $OS_ERROR";
        return;
    }

    # Either the target exists, or this is a filesystem without hard links,
    # where checking and then renaming leaves a small race. -e follows
    # symlinks, so check -l too, or a dangling symlink would be replaced.
    return "cannot rename $from to $to: target already exists"
        if $OS_ERROR{EEXIST} || -e $to || -l $to;

    rename $from, $to or return "failed to rename $from to $to: $OS_ERROR";

    return;
}

# Return true if $path and $other are the same directory entry or hard links
# to the same file. Uses lstat, so a symlink is compared, not its target.
sub same_file {
    my ($path, $other) = @_;

    my ($dev, $ino) = lstat $path or return 0;
    my ($other_dev, $other_ino) = lstat $other or return 0;

    return $dev == $other_dev && $ino == $other_ino;
}

# Rename $path to $new_path, which is the same file under a name differing
# only in case. Some case-insensitive filesystems ignore a rename between two
# names for the same file, so go through a temporary name. Return undef on
# success, or a message saying why it couldn't be renamed.
sub rename_case {
    my ($path, $new_path) = @_;

    # Keep the temporary name short, so that it fits wherever $new_path does
    my $tmp = catfile(dirname($new_path), ".normalo-$PID");

    return rename_noreplace($path, $tmp) // rename_noreplace($tmp, $new_path);
}

# Return true if renaming $path to $new_path only changes the case of the name,
# and $new_path finds $path itself, as it does on a case-insensitive filesystem
sub is_case_change {
    my ($path, $new_path) = @_;

    my $name = basename $new_path;
    return 0 if lc basename($path) ne $name || !same_file($path, $new_path);

    # Two hard links whose names differ only in case are the same file too, on
    # a case-sensitive filesystem. Tell them apart by whether the directory
    # has an entry with exactly the new name.
    opendir my $dh, dirname($new_path) or return 0;
    my $exact = grep { $_ eq $name } readdir $dh;
    closedir $dh;

    return !$exact;
}

# Rename $path to its normalized name. With $preview, a filehandle, print
# "$path -> $new_path" to it instead, after the same checks. Return undef on
# success, or a message saying why it couldn't be renamed.
sub rename_path {
    my ($path, $preview) = @_;

    return "$path is not a regular file" if !-f $path;

    my $filename = basename $path;
    my $kebab_filename = eval { convert $filename } // return "cannot rename $path: $EVAL_ERROR";

    return if $kebab_filename eq $filename;

    # Replace just the last component, so that the new path keeps whatever
    # directory prefix $path was given with (none, for a bare name)
    my $new_path = substr($path, 0, -length $filename) . $kebab_filename;
    my $case_change = is_case_change($path, $new_path);

    if ($preview) {

        # -e follows symlinks, so check -l too for a dangling one
        return "cannot rename $path to $new_path: target already exists"
            if !$case_change && (-e $new_path || -l $new_path);

        print {$preview} "$path -> $new_path\n";
        return;
    }

    return $case_change ? rename_case($path, $new_path) : rename_noreplace($path, $new_path);
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

    # Print an error message, prefixed with the program name, to $err
    my $error = sub {
        my ($msg) = @_;
        chomp $msg;
        print {$err} "$progname: $msg\n";
    };

    # Getopt::Long reports bad options with warn, so send those to $err too
    my $parsed = do {
        local $SIG{__WARN__} = $error;
        GetOptionsFromArray(\@args, \%opts, 'dry-run|n', 'help|h', 'version|v',);
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
  -n, --dry-run    Show what would be renamed, without renaming anything
  -h, --help       Display this help message and exit
  -v, --version    Display version information and exit

Examples:
  $progname "My File.txt"
  $progname file1.txt file2.txt file3.txt
  $progname --dry-run *
END_HELP
        return 0;
    }

    if (!@args) {
        $error->('missing file operand');
        print {$err} "Try '$progname --help' for more information.\n";
        return 1;
    }

    # Report each failure and keep going, like mv(1), so that one bad path
    # doesn't leave the rest of the batch unprocessed
    my $status = 0;

    foreach my $path (@args) {
        my $msg = rename_path($path, $opts{'dry-run'} && $out) // next;
        $error->($msg);
        $status = 1;
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

=head1 DESCRIPTION

App::Normalo is a Perl module for normalizing filenames to kebab-case format.
It can be used as a library or via the L<normalo> command-line tool.

=head1 SUBROUTINES/METHODS

=head2 convert()

  my $normalized = App::Normalo::convert($filename);

Converts a filename to kebab-case format and returns the normalized filename.
Does not modify files on disk.

Takes a single argument, the filename to normalize, and returns the normalized
filename as a string. The filename is a byte string, as returned by C<readdir>
or found in C<@ARGV>, and must be valid UTF-8: C<convert()> dies with
C<"name is not valid UTF-8\n"> rather than guess at another encoding. It also
dies, with C<"name contains a Unicode noncharacter\n">, on a name containing a
noncharacter such as U+FFFE, which would otherwise be dropped from the name
without a trace.

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
named parameters: C<progname> names the program in messages, help, version and
C<--dry-run> output go to the C<out> filehandle, and error messages go to
C<err>.

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

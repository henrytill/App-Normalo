use 5.040000;
use strict;
use warnings;

use App::Normalo;
use Test::More;

is(App::Normalo::convert('My File Name.txt'), 'my-file-name.txt',
    'Basic spaces to hyphens with extension');

is(App::Normalo::convert('UPPERCASE.TXT'), 'uppercase.txt',
    'Uppercase to lowercase');

is(App::Normalo::convert('file_name.with.dots.txt'), 'file-name-with-dots.txt',
    'Underscores and dots to hyphens');

is(App::Normalo::convert('file   with   spaces.txt'), 'file-with-spaces.txt',
    'Multiple spaces collapse to single hyphen');

is(App::Normalo::convert('file@#$%name.txt'), 'filename.txt',
    'Special characters removed');

is(App::Normalo::convert('café.txt'), 'cafe.txt',
    'UTF-8 characters transliterated');

is(App::Normalo::convert('Tëst Fîlé.txt'), 'test-file.txt',
    'Multiple UTF-8 characters transliterated');

is(App::Normalo::convert('already-kebab-case.txt'), 'already-kebab-case.txt',
    'Already kebab-case unchanged');

is(App::Normalo::convert('No Extension'), 'no-extension',
    'File without extension');

is(App::Normalo::convert('file.tar.gz'), 'file.tar.gz',
    'Compound extension preserved');

is(App::Normalo::convert('Café_2024 (Final).PDF'), 'cafe-2024-final.pdf',
    'Complex mixed case');

is(App::Normalo::convert("file\nwith\nnewlines.txt"), 'file-with-newlines.txt',
    'Newlines converted to hyphens');

is(App::Normalo::convert("file\twith\ttabs.txt"), 'file-with-tabs.txt',
    'Tabs converted to hyphens');

is(App::Normalo::convert("file\n\n\twith\t\tmultiple.txt"), 'file-with-multiple.txt',
    'Multiple control characters collapse to single hyphen');

is(App::Normalo::convert('foo.TXTÉ'), 'foo.txte',
    'Non-ASCII extension transliterated');

is(App::Normalo::convert('Résumé.Café'), 'resume.cafe',
    'Non-ASCII stem and extension transliterated');

is(App::Normalo::convert('foo.T x_t-!'), 'foo.txt',
    'Spaces, separators, and special characters removed from extension');

is(App::Normalo::convert('Foo.!!'), 'foo',
    'Extension with nothing left after normalization dropped');

is(App::Normalo::convert('.!!'), '.!!',
    'Name with nothing left after normalization unchanged');

is(App::Normalo::convert(' foo .txt'), 'foo.txt',
    'Leading and trailing spaces trimmed');

is(App::Normalo::convert('中文.txt'), 'zhong-wen.txt',
    'Trailing space from transliteration trimmed');

is(App::Normalo::convert('-Dash.txt'), 'dash.txt',
    'Leading hyphen trimmed');

is(App::Normalo::convert('foo-.txt'), 'foo.txt',
    'Trailing hyphen trimmed');

is(App::Normalo::convert('!!!.txt'), '!!!.txt',
    'Name with nothing left of the stem unchanged');

is(App::Normalo::convert('..txt'), '..txt',
    'Name whose stem is only a separator unchanged');

is(App::Normalo::convert('😀.txt'), '😀.txt',
    'Name whose stem has no transliteration unchanged');

is(App::Normalo::convert('- .txt'), '- .txt',
    'Name whose stem is only hyphens and spaces unchanged');

eval { App::Normalo::convert("\xe9t\xe9.txt") };
is($@, "name is not valid UTF-8\n", 'Latin-1 name is rejected');

eval { App::Normalo::convert("a\xef\xbf\xbe.txt") };
is($@, "name contains a Unicode noncharacter\n", 'Name with a noncharacter is rejected');

eval { App::Normalo::convert("a\xed\xa0\x80.txt") };
is($@, "name is not valid UTF-8\n", 'Name with an encoded surrogate is rejected');

eval { App::Normalo::convert("a\xef\xbf\xbe\xe9.txt") };
is($@, "name is not valid UTF-8\n", 'Name with a noncharacter and a Latin-1 byte is rejected');

is(App::Normalo::convert('.hidden file'), '.hidden-file',
    'Dotfile keeps its dot and normalizes the rest');

is(App::Normalo::convert('.Bashrc'), '.bashrc',
    'Dotfile lowercased');

is(App::Normalo::convert('.Config File.JSON'), '.config-file.json',
    'Dotfile with an extension');

is(App::Normalo::convert('Report v1.2'), 'report-v1.2',
    'Anything after the last dot is the extension');

is(App::Normalo::convert('Report v1.2.pdf'), 'report-v1-2.pdf',
    'Digits before the extension stay in the name');

is(App::Normalo::convert('foo.'), 'foo',
    'Trailing dot dropped');

is(App::Normalo::convert('Backup.TAR.GZ'), 'backup.tar.gz',
    'Compound extension lowercased');

is(App::Normalo::convert('pkg-1.0.pkg.tar.zst'), 'pkg-1-0.pkg.tar.zst',
    'Run of short extensions kept together');

is(App::Normalo::convert('My.Notes.txt'), 'my-notes.txt',
    'Longer component before the extension stays in the name');

is(App::Normalo::convert('file.tar.!!'), 'file.tar',
    'Empty last extension dropped, compound part kept');

done_testing();

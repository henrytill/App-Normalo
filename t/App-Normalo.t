use 5.040000;
use strict;
use warnings;

use Test::More;
use App::Normalo;

is(App::Normalo::convert('My File Name.txt'),
    'my-file-name.txt', 'Basic spaces to hyphens with extension');

is(App::Normalo::convert('UPPERCASE.TXT'), 'uppercase.txt', 'Uppercase to lowercase');

is(App::Normalo::convert('file_name.with.dots.txt'),
    'file-name-with-dots.txt', 'Underscores and dots to hyphens');

is(App::Normalo::convert('file   with   spaces.txt'),
    'file-with-spaces.txt', 'Multiple spaces collapse to single hyphen');

is(App::Normalo::convert('file@#$%name.txt'), 'filename.txt', 'Special characters removed');

is(App::Normalo::convert('café.txt'), 'cafe.txt', 'UTF-8 characters transliterated');

is(App::Normalo::convert('Tëst Fîlé.txt'),
    'test-file.txt', 'Multiple UTF-8 characters transliterated');

is(App::Normalo::convert('already-kebab-case.txt'),
    'already-kebab-case.txt', 'Already kebab-case unchanged');

is(App::Normalo::convert('No Extension'), 'no-extension', 'File without extension');

is(App::Normalo::convert('file.tar.gz'), 'file-tar.gz', 'Extension preserved');

is(App::Normalo::convert('Café_2024 (Final).PDF'), 'cafe-2024-final.pdf', 'Complex mixed case');

is(App::Normalo::convert("file\nwith\nnewlines.txt"),
    'file-with-newlines.txt', 'Newlines converted to hyphens');

is(App::Normalo::convert("file\twith\ttabs.txt"),
    'file-with-tabs.txt', 'Tabs converted to hyphens');

is(App::Normalo::convert("file\n\n\twith\t\tmultiple.txt"),
    'file-with-multiple.txt', 'Multiple control characters collapse to single hyphen');

done_testing();


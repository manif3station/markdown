package Markdown::CLI;

use strict;
use warnings;

use Getopt::Long qw(GetOptionsFromArray);
use JSON::PP qw(encode_json);

use Markdown::Runner;

sub main {
    my (%args) = @_;
    my $argv = $args{argv} || [];
    my %opt = (
        runner => $args{runner} || Markdown::Runner->new,
    );

    my $ok = GetOptionsFromArray(
        $argv,
        'from=s'   => \$opt{from},
        'to:s'     => \$opt{to},
        'to-pdf'   => \$opt{to_pdf},
        'pdf'      => \$opt{pdf},
        'to-html'  => \$opt{to_html},
        'html'     => \$opt{html},
    );

    if ( !$ok ) {
        print STDERR _usage();
        return 1;
    }

    if ( @{$argv} ) {
        print STDERR "Unexpected arguments: @{$argv}\n";
        print STDERR _usage();
        return 1;
    }

    if ( !$opt{from} ) {
        print STDERR _usage();
        return 1;
    }

    my $result = eval {
        $opt{runner}->convert(
            from    => $opt{from},
            to      => $opt{to},
            to_pdf  => $opt{to_pdf} || $opt{pdf},
            to_html => $opt{to_html} || $opt{html},
        );
    };
    if ($@) {
        my $error = $@;
        $error =~ s/\s+\z//;
        print STDERR "$error\n";
        return 1;
    }

    print encode_json($result) . "\n";
    return 0;
}

sub _usage {
    return <<'USAGE';
Usage: dashboard markdown.convert --from <file> [--to <file>] [--to-pdf|--pdf|--to-html|--html]

Examples:
  dashboard markdown.convert --from notes.md --pdf
  dashboard markdown.convert --from notes.md --to notes.html
  dashboard markdown.convert --from notes.html
  dashboard markdown.convert --from scan.pdf
USAGE
}

1;
